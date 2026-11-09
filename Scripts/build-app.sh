#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
build_configuration="${CONFIGURATION:-Debug}"
xcodebuild -project iPhoneRemote.xcodeproj -scheme iPhoneRemote -configuration "$build_configuration" -derivedDataPath build/mac build
printf '\nApplicazione: %s/build/mac/Build/Products/%s/iPhone Remote.app\n' "$PWD" "$build_configuration"
