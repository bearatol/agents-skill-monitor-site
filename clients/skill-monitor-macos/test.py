#!/usr/bin/env python3
"""Run bounded native filesystem, model-state and integration checks."""

import argparse
import json
from pathlib import Path
import platform
import subprocess
import tempfile


SOURCE = Path(__file__).resolve().parent
ROOT = SOURCE.parents[1]
OUTPUT = ROOT / "build" / "skill-monitor-macos-tests"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--arch", choices=("arm64", "x86_64"),
                        help="Test architecture (default: host architecture).")
    arguments = parser.parse_args()
    if platform.system() != "Darwin":
        raise SystemExit("The native regression tests require macOS and the Apple Swift toolchain.")
    host = platform.machine()
    architecture = arguments.arch or host
    if architecture not in {"arm64", "x86_64"}:
        raise SystemExit("Unsupported test architecture.")
    if architecture == "arm64" and host == "x86_64":
        raise SystemExit("ARM64 tests require an Apple Silicon host running native ARM64 Python.")
    if architecture == "x86_64" and host == "arm64":
        rosetta = subprocess.run(["/usr/sbin/pkgutil", "--pkg-info", "com.apple.pkg.RosettaUpdateAuto"],
                                cwd=ROOT, timeout=15, capture_output=True)
        if rosetta.returncode != 0:
            raise SystemExit("Intel tests require Rosetta, which is not installed. No tests were compiled or run.")
    output = OUTPUT / architecture
    for directory in (ROOT / "build", OUTPUT, output, output / "module-cache"):
        if directory.is_symlink():
            raise SystemExit("Test output directories must not be symlinks.")
        directory.mkdir(parents=True, exist_ok=True)
    subprocess.run(["/usr/bin/env", "python3", "-B", str(SOURCE / "Tests" / "BuildScriptTests.py")],
                   cwd=ROOT, check=True, timeout=30)
    with tempfile.TemporaryDirectory(prefix=".sdk-preparation-", dir=output) as directory:
        for module in ("Foundation", "AppKit", "CryptoKit"):
            preparation = Path(directory) / ("prepare-" + module + ".swift")
            preparation.write_text("import " + module + "\n")
            subprocess.run([
                "/usr/bin/swiftc", "-swift-version", "5",
                "-module-cache-path", str(output / "module-cache"),
                "-target", architecture + "-apple-macosx13.0", "-typecheck", str(preparation),
            ], cwd=ROOT, check=True, timeout=30)
    suites = [
        ("inventory", ["SkillInventory.swift", "MetadataAnalysis.swift"], "InventoryTests.swift"),
        ("metadata", ["SkillInventory.swift", "MetadataAnalysis.swift"], "MetadataTests.swift"),
        ("suggestions", ["FolderSuggestions.swift"], "FolderSuggestionTests.swift"),
        ("model", ["SkillInventory.swift", "MetadataAnalysis.swift", "FolderSuggestions.swift", "Localization.swift", "InventoryModel.swift"], "InventoryModelTests.swift"),
        ("integration", ["SkillInventory.swift", "MetadataAnalysis.swift", "FolderSuggestions.swift", "Localization.swift", "InventoryModel.swift"], "IntegrationTests.swift"),
        ("local-ai", ["LocalAI.swift"], "LocalAITests.swift"),
        ("audit", ["SkillInventory.swift", "MetadataAnalysis.swift", "ComponentAudit.swift"], "ComponentAuditTests.swift"),
        ("audit-session", ["SkillInventory.swift", "MetadataAnalysis.swift", "Localization.swift", "LocalAI.swift", "ComponentAudit.swift", "AuditSession.swift"], "AuditSessionTests.swift"),
    ]
    for name, source_names, test_name in suites:
        executable = output / name
        if executable.is_symlink():
            raise SystemExit("Test executables must not be symlinks.")
        inputs = [SOURCE / "Sources" / name for name in source_names] + [SOURCE / "Tests" / test_name]
        if any(not path.is_file() or path.is_symlink() for path in inputs):
            raise SystemExit("Expected regular native test inputs.")
        subprocess.run([
            "/usr/bin/swiftc", "-target", architecture + "-apple-macosx13.0",
            "-swift-version", "5", "-warnings-as-errors",
            "-module-cache-path", str(output / "module-cache"),
            *map(str, inputs), "-o", str(executable),
        ], cwd=ROOT, check=True, timeout=30)
        subprocess.run(["/usr/bin/arch", "-" + architecture, str(executable)],
                       cwd=ROOT, check=True, timeout=30)
    strings = json.loads((SOURCE / "Resources" / "locales.json").read_text())
    if set(strings) != {"ru", "en", "zh-CN"} or any(set(v) != set(strings["en"]) for v in strings.values()):
        raise SystemExit("Localization keys differ between languages.")
    if any(not isinstance(value, str) or not value.strip() for language in strings.values() for value in language.values()):
        raise SystemExit("Localization values must be nonempty strings.")
    print("PASS: localization key parity for RU/EN/zh-CN (" + architecture + ")")


if __name__ == "__main__":
    try:
        main()
    except subprocess.TimeoutExpired:
        raise SystemExit("A native regression step exceeded its 30-second deadline.")
