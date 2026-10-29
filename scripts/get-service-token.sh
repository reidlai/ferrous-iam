#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBMODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ACCOUNT="${1:-svc_ferrous_lakehouse}"

SECRETS_DIR="${SUBMODULE_DIR}/.secrets/tokens"
mkdir -p "$SECRETS_DIR"

TOKEN_FILE="${SECRETS_DIR}/${ACCOUNT}.token"

if [ ! -f "$TOKEN_FILE" ]; then
    RANDOM_HEX=$(head -c 32 /dev/urandom | xxd -p 2>/dev/null || openssl rand -hex 32)
    echo "ferrous_jwt_m2m_${ACCOUNT}_${RANDOM_HEX}" > "$TOKEN_FILE"
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
echo "To configure downstream submodules (e.g. ferrous-lakehouse), add to your .env:"
if [ "$ACCOUNT" = "svc_ferrous_lakehouse" ]; then
    echo "  LAKEHOUSE_SERVICE_ACCOUNT=${ACCOUNT}"
    echo "  LAKEHOUSE_SERVICE_TOKEN=${TOKEN_VALUE}"
else
    echo "  SERVICE_ACCOUNT=${ACCOUNT}"
    echo "  SERVICE_TOKEN=${TOKEN_VALUE}"
fi
echo ""
echo "==> Saved to local git-ignored file: .secrets/tokens/${ACCOUNT}.token"
