#!/usr/bin/env python3
"""Build the local macOS viewer with the installed Apple toolchain."""

import json
import os
from pathlib import Path
import platform
import plistlib
import shutil
import subprocess
import tempfile
import time
import zipfile


SOURCE = Path(__file__).resolve().parent
ROOT = SOURCE.parents[1]
OUTPUT = ROOT / "build" / "skill-monitor-macos"
OWNER = "agents-local-skill-monitor"
APP_NAME = "Agents Skill Monitor.app"
EXECUTABLE = "AgentsSkillMonitor"


def run(arguments, timeout=30):
    subprocess.run(arguments, cwd=ROOT, check=True, timeout=timeout)


def main():
    if platform.system() != "Darwin":
        raise SystemExit("The native viewer requires macOS and the Apple Swift toolchain.")
    architecture = platform.machine()
    if architecture not in {"arm64", "x86_64"}:
        raise SystemExit("Unsupported build architecture.")
    sources = [SOURCE / "Sources" / name for name in
               ("SkillInventory.swift", "MetadataAnalysis.swift", "FolderSuggestions.swift", "Localization.swift", "InventoryModel.swift", "App.swift")]
    resource = SOURCE / "Resources" / "locales.json"
    if any(not path.is_file() or path.is_symlink() for path in [*sources, resource]):
        raise SystemExit("Expected regular native source and localization files.")
    for directory in (ROOT / "build", OUTPUT, OUTPUT / "module-cache"):
        if directory.is_symlink():
            raise SystemExit("Build output directories must not be symlinks.")
        directory.mkdir(parents=True, exist_ok=True)
    target = OUTPUT / APP_NAME
    if target.exists() or target.is_symlink():
        receipt = target / "Contents" / "Resources" / "build-origin.json"
        if target.is_symlink() or not receipt.is_file() or receipt.is_symlink():
            raise SystemExit("Refusing to replace an unowned application bundle.")
        if json.loads(receipt.read_text()).get("owner") != OWNER:
            raise SystemExit("Refusing to replace an unowned application bundle.")

    with tempfile.TemporaryDirectory(prefix=".native-build-", dir=OUTPUT) as directory:
        app = Path(directory) / APP_NAME
        contents = app / "Contents"
        binary = contents / "MacOS" / EXECUTABLE
        resources = contents / "Resources"
        binary.parent.mkdir(parents=True)
        resources.mkdir()
        run(["/usr/bin/swiftc", "-swift-version", "5", "-Onone",
             "-module-cache-path", str(OUTPUT / "module-cache"),
             "-target", architecture + "-apple-macosx13.0",
             "-framework", "SwiftUI", "-framework", "AppKit",
             *map(str, sources), "-o", str(binary)])
        shutil.copyfile(resource, resources / "locales.json")
        shutil.copyfile(ROOT / "LICENSE", resources / "LICENSE")
        (resources / "build-origin.json").write_text(json.dumps({
            "owner": OWNER, "version": "0.2.3", "architecture": architecture,
            "scope": "Read-only local component metadata; user-confirmed folders",
        }, indent=2) + "\n")
        info = {
            "CFBundleName": "Agents Skill Monitor",
            "CFBundleDisplayName": "Agents Skill Monitor",
            "CFBundleIdentifier": "io.github.bearatol.agents.skillmonitor",
            "CFBundleExecutable": EXECUTABLE,
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "0.2.3",
            "CFBundleVersion": "5",
            "LSMinimumSystemVersion": "13.0",
            "NSHighResolutionCapable": True,
            "NSPrincipalClass": "NSApplication",
        }
        with (contents / "Info.plist").open("wb") as stream:
            plistlib.dump(info, stream)
        run(["/usr/bin/codesign", "--force", "--sign", "-", "--timestamp=none", str(app)], 15)
        run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)], 15)
        if target.exists():
            backup = OUTPUT / ("previous-" + str(time.time_ns()) + ".app")
            target.rename(backup)
        app.rename(target)

    archive = OUTPUT / ("AgentsSkillMonitor-macOS-" + architecture + ".zip")
    if archive.is_symlink():
        raise SystemExit("The archive destination must not be a symlink.")
    handle, temporary = tempfile.mkstemp(prefix=".native-archive-", suffix=".zip", dir=OUTPUT)
    os.close(handle)
    try:
        with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED) as bundle:
            for path in sorted(target.rglob("*")):
                if path.is_symlink():
                    raise SystemExit("Unexpected symlink in the generated application.")
                bundle.write(path, path.relative_to(OUTPUT))
        Path(temporary).replace(archive)
    finally:
        Path(temporary).unlink(missing_ok=True)
    print(json.dumps({"app": str(target), "archive": str(archive),
                      "architecture": architecture, "signing": "ad-hoc; not notarized"}))


if __name__ == "__main__":
    try:
        main()
    except subprocess.TimeoutExpired:
        raise SystemExit("Build step exceeded its deadline; previous successful builds were preserved.")
