#!/usr/bin/env bash
# Bash Script to Recover and Display Kanidm Admin Credentials
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBMODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^ferrous-iam$"; then
    echo "[-] Container 'ferrous-iam' is not currently running. Please run: docker compose up -d" >&2
    exit 1
fi

echo "==> Requesting one-time admin recovery credential from Kanidm daemon..."
RAW_OUTPUT=$(docker exec -i ferrous-iam /sbin/kanidmd recover-account -c /etc/kanidm/server.toml admin 2>&1)

PASSWORD=$(echo "$RAW_OUTPUT" | grep -oE 'new_password: "[^"]+"' | cut -d'"' -f2 || true)

if [ -z "$PASSWORD" ]; then
    echo "[-] Could not parse recovery password from Kanidm output:" >&2
    echo "$RAW_OUTPUT" >&2
    exit 1
fi

echo ""
echo "=========================================================="
echo "         KANIDM ADMINISTRATOR LOGIN CREDENTIALS           "
echo "=========================================================="
echo "  Web UI URL:   https://localhost:8443"
echo "  Username:     admin"
echo "  Password:     $PASSWORD"
echo "=========================================================="
echo ""
echo "Instructions:"
echo " 1. Open https://localhost:8443 in your browser (accept TLS warning)."
echo " 2. Type 'admin' and click Begin."
echo " 3. Paste the password above when prompted."
echo ""

SECRETS_DIR="${SUBMODULE_DIR}/.secrets"
mkdir -p "$SECRETS_DIR"
echo "$PASSWORD" > "${SECRETS_DIR}/admin_password.txt"
echo "==> Password also saved to local git-ignored file: .secrets/admin_password.txt"
