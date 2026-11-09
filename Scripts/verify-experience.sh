#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/logs
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc -swift-version 5 -target "$(uname -m)-apple-macos14.0" -parse-as-library Sources/RemoteCore/ScreenGeometry.swift Sources/RemoteCore/NavigationOverlayGeometry.swift Sources/RemoteCore/WDAClient.swift \
  Sources/iPhoneRemote/CaptureService.swift Sources/iPhoneRemote/CaptureArchive.swift \
  Sources/iPhoneRemote/VideoView.swift Sources/iPhoneRemote/NavigationPill.swift Sources/iPhoneRemote/Shortcuts.swift Sources/iPhoneRemote/WindowPresentation.swift \
  Tools/experience-check.swift -o build/experience-check
build/experience-check
