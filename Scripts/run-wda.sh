#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
: "${IPHONE_UDID:?Imposta IPHONE_UDID con l’identificativo USB dell’iPhone}"
: "${WDA_TEAM_ID:?Imposta WDA_TEAM_ID con il Team di firma di Xcode}"
: "${WDA_BUNDLE_ID:?Imposta WDA_BUNDLE_ID con un identificativo univoco, ad esempio it.nome.iphoneremote.wda}"
if [ ! -d Research/WebDriverAgent/WebDriverAgent.xcodeproj ]; then
    echo 'Esegui prima Scripts/bootstrap-wda.sh' >&2
    exit 1
fi
mkdir -p build/logs
python3 Scripts/configure-wda.py
# Runs a test runner, not a normal application. Xcode handles install and XCTest launch.
# The process intentionally stays running while WDA serves requests.
xcodebuild test -project build/wda-source/WebDriverAgent.xcodeproj \
    -scheme WebDriverAgentRunner -destination "platform=iOS,id=$IPHONE_UDID" \
    -destination-timeout 30 -derivedDataPath build/wda \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    DEVELOPMENT_TEAM="$WDA_TEAM_ID" CODE_SIGN_STYLE=Automatic \
    2>&1 | tee build/logs/wda-run.log
