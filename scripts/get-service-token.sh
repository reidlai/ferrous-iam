#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBMODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ACCOUNT="${1:-svc_ferrous_api}"

case "$ACCOUNT" in
    svc_ferrous_api|svc_ferrous_agent)
        ;;
    *)
        echo "ERROR: Invalid service account '$ACCOUNT'. Valid accounts: svc_ferrous_api, svc_ferrous_agent" >&2
        exit 1
        ;;
esac

SECRETS_DIR="${SUBMODULE_DIR}/.secrets/tokens"
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR" 2>/dev/null || true

TOKEN_FILE="${SECRETS_DIR}/${ACCOUNT}.token"

if [ ! -f "$TOKEN_FILE" ]; then
    RANDOM_HEX=$(head -c 32 /dev/urandom | xxd -p 2>/dev/null || openssl rand -hex 32)
    echo "ferrous_jwt_m2m_${ACCOUNT}_${RANDOM_HEX}" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE" 2>/dev/null || true
fi

TOKEN_VALUE=$(cat "$TOKEN_FILE" | tr -d '\r\n')

echo ""
echo "=========================================================="
echo "      FERROUS M2M SERVICE ACCOUNT TOKEN GENERATED         "
echo "=========================================================="
echo "  Service Account: ${ACCOUNT}"
echo "  Bearer Token:    ${TOKEN_VALUE}"
echo "=========================================================="
echo ""
echo "To configure downstream services (e.g. ferrous-api), add to your .env:"
echo "  SERVICE_ACCOUNT=${ACCOUNT}"
echo "  SERVICE_TOKEN=${TOKEN_VALUE}"
echo ""
echo "==> Saved to local git-ignored file: .secrets/tokens/${ACCOUNT}.token"
