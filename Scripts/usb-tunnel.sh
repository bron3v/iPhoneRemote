#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${IPHONE_UDID:?Imposta IPHONE_UDID con l’identificativo dell’iPhone}"
proxy="$(command -v iproxy || true)"
if [ -z "$proxy" ] && [ -x /opt/homebrew/bin/iproxy ]; then proxy=/opt/homebrew/bin/iproxy; fi
if [ -z "$proxy" ]; then
    echo 'iproxy mancante. Installa la dipendenza gratuita con: brew install libusbmuxd' >&2
    exit 1
fi
# -l selects USB only; -s binds loopback; -u selects the exact UDID.
exec "$proxy" -l -s 127.0.0.1 -u "$IPHONE_UDID" 8100:8100
