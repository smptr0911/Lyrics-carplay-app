"""Record installed Apple tools and resolved public build settings; never print credentials."""
import argparse
import json
import platform
import plistlib
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def command(args, timeout=90):
    result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f"{args[0]} exited {result.returncode}: {result.stderr.strip()[:400]}")
    return result.stdout


def inspect(probe_menu=False):
    print(f"Authoring OS: {platform.system()} {platform.release()}")
    if not shutil.which("xcodebuild") or not shutil.which("xcrun"):
        print("Xcode/Apple SDKs/Simulator: unavailable locally; use a Mac or macOS CI.")
        return
    for application in sorted(Path("/Applications").glob("Xcode*.app")):
        info = application / "Contents/Info.plist"
        if info.is_file():
            version = plistlib.loads(info.read_bytes()).get("CFBundleShortVersionString", "unknown")
            print(f"Installed Xcode bundle: {application.name}, version {version}")
    for args in (["xcodebuild", "-version"], ["xcodebuild", "-showsdks"],
                 ["xcrun", "swift", "--version"], ["xcrun", "simctl", "list", "runtimes"]):
        print(command(args).strip())
    project = ["xcodebuild", "-project", "LyricsCarPlay.xcodeproj"]
    print("Shared targets and schemes:")
    print(command(project + ["-list", "-json"]).strip())
    # Allowlist only: -showBuildSettings can contain developer-provided secrets.
    keys = ["TARGET_NAME", "IPHONEOS_DEPLOYMENT_TARGET", "SWIFT_VERSION", "SWIFT_STRICT_CONCURRENCY",
            "SDKROOT", "CODE_SIGN_STYLE", "DEVELOPMENT_TEAM", "CODE_SIGN_ENTITLEMENTS",
            "PRODUCT_BUNDLE_IDENTIFIER", "INFOPLIST_FILE", "LYRICS_APP_GROUP", "APPLICATION_EXTENSION_API_ONLY"]
    for sdk in ("iphoneos", "iphonesimulator"):
        settings = json.loads(command(project + ["-scheme", "LyricsCarPlay", "-configuration", "Debug",
            "-sdk", sdk, "-showBuildSettings", "-json", "CODE_SIGNING_ALLOWED=NO"]))
        print(f"Resolved {sdk} settings (unsigned inspection, not provisioning verification):")
        for target in settings:
            values = target["buildSettings"]
            print(json.dumps({key: values[key] for key in keys if key in values}, sort_keys=True))
    developer = Path(command(["xcode-select", "-p"]).strip())
    simulator = developer / "Applications/Simulator.app"
    print(f"Selected Simulator bundle exists: {simulator.is_dir()}")
    print("Standalone Additional Tools package: not installed or verified by this script.")
    if probe_menu and simulator.is_dir():
        subprocess.run(["open", "-a", str(simulator)], check=True, timeout=15)
        # Public macOS accessibility automation only; no defaults/private simulator flags.
        script = '''tell application "System Events"
if not (UI elements enabled) then return "UNVERIFIED: accessibility automation unavailable"
tell process "Simulator"
if not (exists menu bar 1) then return "UNVERIFIED: menu bar unavailable"
if not (exists menu bar item "I/O" of menu bar 1) then return "UNVERIFIED: I/O menu unavailable"
tell menu 1 of menu bar item "I/O" of menu bar 1
if not (exists menu item "External Displays") then return "UNVERIFIED: External Displays unavailable"
tell menu 1 of menu item "External Displays"
if exists menu item "CarPlay" then return "VERIFIED: I/O > External Displays > CarPlay menu exists"
end tell
end tell
end tell
return "UNVERIFIED: CarPlay menu unavailable"
end tell'''
        try:
            print(command(["osascript", "-e", script], timeout=15).strip())
        except (RuntimeError, subprocess.TimeoutExpired):
            print("UNVERIFIED: Simulator menu could not be inspected with available UI automation.")
    else:
        print("Simulator CarPlay menu: not inspected; run with --probe-simulator-menu on a GUI Mac.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe-simulator-menu", action="store_true")
    inspect(parser.parse_args().probe_simulator_menu)
