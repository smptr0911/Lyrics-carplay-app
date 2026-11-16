"""Record public installed SDK declarations used by the small Live Activity layout."""
from pathlib import Path
import subprocess

sdk = Path(subprocess.check_output(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"], text=True).strip())
print(f"Installed iPhone SDK: {sdk.name}")
declarations = set()
for framework in ("WidgetKit", "SwiftUI"):
    modules = sdk / "System/Library/Frameworks" / f"{framework}.framework/Modules"
    for interface in modules.rglob("*.swiftinterface"):
        if ".private." in interface.name:
            continue
        for line in interface.read_text(encoding="utf-8").splitlines():
            if "supplementalActivityFamilies(" in line or "var activityFamily:" in line:
                declarations.add(line.strip())
for declaration in sorted(declarations):
    print(declaration)
if not declarations:
    raise SystemExit("Required public Live Activity declarations not found; inspect this SDK before building.")
