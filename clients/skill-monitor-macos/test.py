#!/usr/bin/env python3
"""Run bounded native filesystem, model-state and integration checks."""

import json
from pathlib import Path
import platform
import subprocess


SOURCE = Path(__file__).resolve().parent
ROOT = SOURCE.parents[1]
OUTPUT = ROOT / "build" / "skill-monitor-macos-tests"


def main():
    if platform.system() != "Darwin":
        raise SystemExit("The native regression tests require macOS and the Apple Swift toolchain.")
    architecture = platform.machine()
    if architecture not in {"arm64", "x86_64"}:
        raise SystemExit("Unsupported test architecture.")
    for directory in (ROOT / "build", OUTPUT, OUTPUT / "module-cache"):
        if directory.is_symlink():
            raise SystemExit("Test output directories must not be symlinks.")
        directory.mkdir(parents=True, exist_ok=True)
    suites = [
        ("inventory", ["SkillInventory.swift", "MetadataAnalysis.swift"], "InventoryTests.swift"),
        ("metadata", ["SkillInventory.swift", "MetadataAnalysis.swift"], "MetadataTests.swift"),
        ("suggestions", ["FolderSuggestions.swift"], "FolderSuggestionTests.swift"),
        ("model", ["SkillInventory.swift", "MetadataAnalysis.swift", "FolderSuggestions.swift", "Localization.swift", "InventoryModel.swift"], "InventoryModelTests.swift"),
        ("integration", ["SkillInventory.swift", "MetadataAnalysis.swift", "FolderSuggestions.swift", "Localization.swift", "InventoryModel.swift"], "IntegrationTests.swift"),
    ]
    for name, source_names, test_name in suites:
        executable = OUTPUT / name
        if executable.is_symlink():
            raise SystemExit("Test executables must not be symlinks.")
        inputs = [SOURCE / "Sources" / name for name in source_names] + [SOURCE / "Tests" / test_name]
        if any(not path.is_file() or path.is_symlink() for path in inputs):
            raise SystemExit("Expected regular native test inputs.")
        subprocess.run([
            "/usr/bin/swiftc", "-target", architecture + "-apple-macosx13.0",
            "-swift-version", "5", "-warnings-as-errors",
            "-module-cache-path", str(OUTPUT / "module-cache"),
            *map(str, inputs), "-o", str(executable),
        ], cwd=ROOT, check=True, timeout=30)
        subprocess.run([str(executable)], cwd=ROOT, check=True, timeout=30)
    strings = json.loads((SOURCE / "Resources" / "locales.json").read_text())
    if set(strings) != {"ru", "en", "zh-CN"} or any(set(v) != set(strings["en"]) for v in strings.values()):
        raise SystemExit("Localization keys differ between languages.")
    if any(not isinstance(value, str) or not value.strip() for language in strings.values() for value in language.values()):
        raise SystemExit("Localization values must be nonempty strings.")
    print("PASS: localization key parity for RU/EN/zh-CN")


if __name__ == "__main__":
    try:
        main()
    except subprocess.TimeoutExpired:
        raise SystemExit("A native regression step exceeded its 30-second deadline.")
