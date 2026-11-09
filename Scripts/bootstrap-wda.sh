#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
revision=3d6a4e03cdd673e540289c610f7e189f8ffea434
mkdir -p Research
if [ ! -d Research/WebDriverAgent/.git ]; then
    git clone https://github.com/appium/WebDriverAgent.git Research/WebDriverAgent
fi
git -C Research/WebDriverAgent cat-file -e "$revision^{commit}" 2>/dev/null || git -C Research/WebDriverAgent fetch origin "$revision"
if [ -n "$(git -C Research/WebDriverAgent status --porcelain)" ]; then
    echo 'La copia WDA contiene modifiche locali: interrompo per preservarle.' >&2
    exit 1
fi
git -C Research/WebDriverAgent checkout --detach "$revision"
echo 'WDA pronto. Configura il Team nel progetto Xcode o usa WDA_TEAM_ID con run-wda.sh.'
