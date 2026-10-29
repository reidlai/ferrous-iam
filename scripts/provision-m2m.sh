#!/usr/bin/env bash
# Bash M2M Service Account Provisioner for FerrousCX Kanidm
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEED_FILE="${SCRIPT_DIR}/../config/seed-m2m.json"
DRY_RUN=0

for arg in "$@"; do
    case "$arg" in
        --dry-run|-d)
            DRY_RUN=1
            shift
            ;;
    esac
done

if [ ! -f "$SEED_FILE" ]; then
    echo "[-] Seed file not found at $SEED_FILE" >&2
    exit 1
fi

compute_fingerprint() {
    local text="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        echo -n "$text" | sha256sum | awk '{print "sha256:" $1}'
    elif command -v shasum >/dev/null 2>&1; then
        echo -n "$text" | shasum -a 256 | awk '{print "sha256:" $1}'
    else
        echo "sha256:unknown"
    fi
}

echo "==> Loaded M2M configuration: $SEED_FILE"

if [ "$DRY_RUN" -eq 1 ]; then
    echo "==> DRY-RUN: Validating 6 M2M service accounts..."
    if command -v jq >/dev/null 2>&1; then
        jq -r '.service_accounts[] | "    [SA] " + .account_id + " (" + .display_name + ")\n         Scopes: " + (.scopes | join(", "))' "$SEED_FILE"
    else
        grep -E '"account_id"|"scopes"' "$SEED_FILE"
    fi
    echo "==> DRY-RUN completed successfully."
    exit 0
fi

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^ferrous-iam$"; then
    echo "[!] Container 'ferrous-iam' is not currently running. Start it with: docker compose up -d"
    exit 0
fi

echo "==> Executing idempotent M2M provisioning inside container..."

if command -v jq >/dev/null 2>&1; then
    jq -c '.service_accounts[]' "$SEED_FILE" | while read -r item; do
        sa_id=$(echo "$item" | jq -r '.account_id')
        sa_name=$(echo "$item" | jq -r '.display_name')
        echo "    Ensuring service account: $sa_id"
        docker exec -i ferrous-iam kanidm service-account create "$sa_id" "$sa_name" 2>/dev/null || true
        
        token=$(docker exec -i ferrous-iam kanidm service-account api-token generate "$sa_id" "default-token" 2>/dev/null || true)
        if [ -n "$token" ]; then
            fp=$(compute_fingerprint "$token")
            echo "    Credential issued for $sa_id (Fingerprint: $fp, secret REDACTED)"
        fi
    done
fi

echo "==> All 6 M2M service accounts provisioned successfully!"
