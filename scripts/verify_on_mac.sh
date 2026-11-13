#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/logs
python3 scripts/validate_project.py --xcode 2>&1 | tee .build/logs/simulator.log
xcodebuild build -project LyricsCarPlay.xcodeproj -scheme LyricsCarPlay -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tee .build/logs/device-release.log
printf '%s\n' 'Simulator tests and unsigned device Release build completed. Physical iPhone/vehicle checks remain separate.'
