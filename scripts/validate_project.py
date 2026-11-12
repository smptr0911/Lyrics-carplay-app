"""Validate scaffold integrity everywhere; --xcode additionally requires an iOS test run."""
from pathlib import Path
import argparse
import hashlib
import json
import plistlib
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def validate():
    project = ROOT / "LyricsCarPlay.xcodeproj/project.pbxproj"
    content = project.read_text(encoding="utf-8")
    definitions = re.findall(r"^\s*([A-F0-9]{24}) = ", content, re.M)
    references = set(re.findall(r"\b[A-F0-9]{24}\b", content))
    assert len(definitions) == len(set(definitions)), "Duplicate Xcode IDs"
    assert references == set(definitions), "Unresolved Xcode IDs"
    for path in re.findall(r'path = "([^"]+)"; sourceTree = SOURCE_ROOT;', content):
        assert (ROOT / path).exists(), f"Missing Xcode file: {path}"
    for folder, phase in [
        ("LyricsCarPlay", "4A63890C48D107299F140490"),
        ("LyricsCarPlayTests", "59ACFA4C2F5525670A908C98"),
        ("LyricsCarPlayUITests", "128178DD6E58AD69D98310C4"),
    ]:
        body = re.search(phase + r" = .*", content).group(0)
        for path in (ROOT / folder).rglob("*.swift"):
            relative = path.relative_to(ROOT).as_posix()
            key = hashlib.sha1(("build:" + relative).encode()).hexdigest()[:24].upper()
            assert key in body, f"Missing source membership: {relative}"
    device_info = plistlib.loads((ROOT / "LyricsCarPlay/Resources/Info.plist").read_bytes())
    assert "UIApplicationSceneManifest" not in device_info, "Device build unexpectedly enables CarPlay scenes"
    simulator_info = plistlib.loads((ROOT / "LyricsCarPlay/Resources/Info-Simulator.plist").read_bytes())
    scene = simulator_info["UIApplicationSceneManifest"]["UISceneConfigurations"]["CPTemplateApplicationSceneSessionRoleApplication"][0]
    assert scene["UISceneDelegateClassName"] == "$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate"
    entitlement_path = "LyricsCarPlay/CarPlay/CarPlay-Simulator.entitlements"
    assert plistlib.loads((ROOT / entitlement_path).read_bytes()) == {"com.apple.developer.carplay-audio": True}
    assert content.count('"CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]" = "' + entitlement_path + '"') == 2
    assert not re.search(r"(?<![A-Z_])CODE_SIGN_ENTITLEMENTS =", content), "CarPlay entitlement must remain simulator-only"
    assert content.count('"INFOPLIST_FILE[sdk=iphonesimulator*]" = "LyricsCarPlay/Resources/Info-Simulator.plist"') == 2
    ET.parse(ROOT / "LyricsCarPlay.xcodeproj/xcshareddata/xcschemes/CarPlay Simulator.xcscheme")
    privacy = plistlib.loads((ROOT / "LyricsCarPlay/Resources/PrivacyInfo.xcprivacy").read_bytes())
    assert privacy["NSPrivacyTracking"] is False
    assert privacy["NSPrivacyAccessedAPITypes"][0]["NSPrivacyAccessedAPITypeReasons"] == ["CA92.1"]
    assert device_info.get("NSAppTransportSecurity", {}) == {}, "Device ATS must stay restrictive"
    assert simulator_info["NSAppTransportSecurity"] == {"NSAllowsLocalNetworking": True}
    for info in (device_info, simulator_info):
        assert info["LyricsAPIURL"] == "$(LYRICS_API_URL)"
        assert info["SpotifyClientID"] == "$(SPOTIFY_CLIENT_ID)"
        assert "spotify" in info["LSApplicationQueriesSchemes"]
        assert info["CFBundleURLTypes"][0]["CFBundleURLSchemes"] == ["lyrics-carplay-spotify"]
    pins = json.loads((ROOT / "LyricsCarPlay.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved").read_text())
    pin = next(item for item in pins["pins"] if item["identity"] == "ios-sdk")
    assert pin["state"] == {"version": "5.0.1", "revision": "0b3e54771738ad5e64f22c8e5e19ca76d6becc6c"}
    assert 'kind = exactVersion; version = 5.0.1;' in content
    assert 'productName = SpotifyiOS;' in content
    assert (ROOT / "Config/App.xcconfig").exists()
    tree = ET.parse(ROOT / "LyricsCarPlay.xcodeproj/xcshareddata/xcschemes/LyricsCarPlay.xcscheme")
    testables = tree.findall(".//TestableReference/BuildableReference")
    assert {item.attrib["BlueprintName"] for item in testables} == {"LyricsCarPlayTests", "LyricsCarPlayUITests"}
    for path in (ROOT / "LyricsCarPlay/Resources").rglob("*.json"):
        json.loads(path.read_text(encoding="utf-8"))
    for path in (ROOT / "docs").glob("*.md"):
        for target in re.findall(r"\]\(([^)]+)\)", path.read_text(encoding="utf-8")):
            if "://" not in target and not target.startswith("#"):
                assert (path.parent / target.split("#")[0]).exists(), f"Broken link in {path.name}: {target}"
    print(f"PASS: project references, source membership, plist, scheme, assets and documentation links ({len(definitions)} Xcode objects).")


def xcode_tests():
    if not shutil.which("xcodebuild") or not shutil.which("xcrun"):
        raise RuntimeError("Xcode testing requires macOS and Xcode. Structural validation is not a Swift build.")
    subprocess.run(["plutil", "-lint", str(ROOT / "LyricsCarPlay.xcodeproj/project.pbxproj")], check=True)
    devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))
    candidates = []
    for runtime, group in devices["devices"].items():
        match = re.search(r"\.iOS-(\d+)(?:-(\d+))?", runtime)
        if match and int(match.group(1)) >= 17:
            version = (int(match.group(1)), int(match.group(2) or 0))
            candidates.extend((version, device) for device in group if device["name"].startswith("iPhone"))
    candidates.sort(key=lambda item: item[0], reverse=True)
    if not candidates:
        raise RuntimeError("Install a compatible iPhone simulator runtime in Xcode first.")
    subprocess.run(["xcodebuild", "test", "-project", "LyricsCarPlay.xcodeproj", "-scheme", "LyricsCarPlay",
                    "-destination", f"platform=iOS Simulator,id={candidates[0][1]['udid']}",
                    "CODE_SIGNING_ALLOWED=NO"], cwd=ROOT, check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--xcode", action="store_true", help="Require macOS simulator build and tests")
    args = parser.parse_args()
    try:
        validate()
        if args.xcode:
            xcode_tests()
        else:
            print("NOT RUN: Swift build, XCTest/UI tests, and physical device checks. Use --xcode on a Mac.")
    except (AssertionError, RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
