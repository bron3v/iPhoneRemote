#!/bin/bash
# Builds a runner for the user's own device/account, then installs a personal Mac app.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "${1:-}" = --help ]; then
    echo 'Usage: configure .local/development.env, source it, then run Scripts/setup-personal-app.sh'
    echo 'Required: IPHONE_UDID, WDA_TEAM_ID, WDA_BUNDLE_ID. Full Xcode, Python 3 and iproxy are required.'
    exit 0
fi
if [ "$#" -ne 0 ]; then echo 'Unexpected arguments. Use --help.' >&2; exit 1; fi
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
: "${IPHONE_UDID:?Set IPHONE_UDID to your USB iPhone identifier}"
: "${WDA_TEAM_ID:?Set WDA_TEAM_ID to your Xcode Team identifier}"
: "${WDA_BUNDLE_ID:?Set WDA_BUNDLE_ID to your own reverse-DNS runner identifier}"
if [[ ! "$IPHONE_UDID" =~ ^([[:xdigit:]]{8}-?[[:xdigit:]]{16}|[[:xdigit:]]{40})$ ]]; then
    echo 'IPHONE_UDID is not a supported device identifier.' >&2; exit 1
fi
if [[ ! "$WDA_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
    echo 'WDA_TEAM_ID must contain the ten letters/digits shown by Xcode.' >&2; exit 1
fi
if [[ ! "$WDA_BUNDLE_ID" =~ ^[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z0-9-]+)+$ ]]; then
    echo 'WDA_BUNDLE_ID must be a reverse-DNS identifier.' >&2; exit 1
fi
if [ ! -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ]; then
    echo 'Full Xcode is required. Set DEVELOPER_DIR to its Contents/Developer directory.' >&2; exit 1
fi
if [ ! -x /opt/homebrew/bin/iproxy ] && [ ! -x /usr/local/bin/iproxy ]; then
    echo 'Install iproxy first with: brew install libusbmuxd' >&2; exit 1
fi
command -v python3 >/dev/null
mkdir -p build/logs
Scripts/bootstrap-wda.sh
python3 Scripts/configure-wda.py
xcodebuild build-for-testing -project build/wda-source/WebDriverAgent.xcodeproj \
    -scheme WebDriverAgentRunner -destination "platform=iOS,id=$IPHONE_UDID" \
    -destination-timeout 30 -derivedDataPath build/wda \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    "DEVELOPMENT_TEAM=$WDA_TEAM_ID" CODE_SIGN_STYLE=Automatic \
    2>&1 | tee build/logs/personal-setup.log
Scripts/install-personal-app.sh
printf '\nPersonal app installed. Open /Applications/iPhone Remote.app when your iPhone is ready.\n'
