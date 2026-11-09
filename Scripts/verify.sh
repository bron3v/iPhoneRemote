#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
mkdir -p build/logs
swift test 2>&1 | tee build/logs/swift-tests.log
Scripts/build-app.sh > build/logs/macos-build.log 2>&1
echo 'Compilazione macOS riuscita; log in build/logs/macos-build.log'
xcrun swiftc -parse-as-library Sources/RemoteCore/ScreenGeometry.swift Sources/RemoteCore/WDAClient.swift Sources/iPhoneRemote/RemoteModel.swift Tools/model-queue-check.swift -o build/model-queue-check
build/model-queue-check | tee build/logs/model-queue-check.log
bash -n Scripts/*.sh
plutil -lint Config/Info.plist iPhoneRemote.xcodeproj/project.pbxproj
codesign --verify --strict 'build/mac/Build/Products/Debug/iPhone Remote.app'
