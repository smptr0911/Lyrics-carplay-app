#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/logs
xcodebuild -version | tee .build/logs/xcode-version.log
xcodebuild -showsdks | tee .build/logs/xcode-sdks.log
xcodebuild build -project LyricsCarPlay.xcodeproj -target LyricsWidgets -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO 2>&1 | tee .build/logs/widget-simulator.log
python3 scripts/validate_project.py --xcode 2>&1 | tee .build/logs/simulator.log
xcodebuild build -project LyricsCarPlay.xcodeproj -scheme LyricsCarPlay -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tee .build/logs/device-release.log
printf '%s\n' 'Widget simulator build, simulator tests and unsigned device Release build completed. Signed App Group and physical vehicle checks remain separate.'
