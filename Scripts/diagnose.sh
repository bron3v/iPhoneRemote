#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
sw_vers
xcodebuild -version
xcrun devicectl list devices --timeout 15
security find-identity -v -p codesigning
if command -v iproxy >/dev/null; then iproxy --help; fi
