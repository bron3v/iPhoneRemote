#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
: "${IPHONE_UDID:?Imposta IPHONE_UDID con l’iPhone incluso nel profilo firmato}"
mkdir -p build/logs
CONFIGURATION=Release Scripts/build-app.sh > build/logs/personal-release-build.log 2>&1
python3 Scripts/install-personal-app.py --udid "$IPHONE_UDID" "$@"
