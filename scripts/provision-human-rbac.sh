#!/usr/bin/env bash
# Bash Human RBAC Provisioner for FerrousCX Kanidm
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBMODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SEED_FILE="${SUBMODULE_DIR}/config/seed-rbac.json"
ENV_FILE="${SUBMODULE_DIR}/.env"
ENV_EXAMPLE="${SUBMODULE_DIR}/.env.example"
DRY_RUN=0

for arg in "$@"; do
    case "$arg" in
        --dry-run|-d)
            DRY_RUN=1
            shift
            ;;
    esac
done

if [ -f "$ENV_FILE" ]; then
    echo "==> Loading credentials from local .env (git-ignored)..."
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
elif [ -f "$ENV_EXAMPLE" ]; then
    echo "==> No .env found. Sourcing fallback defaults from .env.example..."
    set -a
    # shellcheck disable=SC1090
    source "$ENV_EXAMPLE"
    set +a
fi

if [ ! -f "$SEED_FILE" ]; then
    echo "[-] Seed file not found at $SEED_FILE" >&2
    exit 1
fi

echo "==> Loaded seed configuration: $SEED_FILE"

if [ "$DRY_RUN" -eq 1 ]; then
    echo "==> DRY-RUN: Validating RBAC definitions..."
    if command -v jq >/dev/null 2>&1; then
        echo "    Groups:"
        jq -r '.groups[] | "      - " + .name + ": " + .description' "$SEED_FILE"
        echo "    Users:"
        jq -r '.users[] | "      - " + .username + " (" + .group + ") [Password source: " + .env_password_var + "]"' "$SEED_FILE"
    else
        grep -E '"name"|"username"|"env_password_var"' "$SEED_FILE"
    fi
    echo "==> DRY-RUN completed successfully."
    exit 0
fi

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^ferrous-iam$"; then
    echo "[!] Container 'ferrous-iam' is not currently running. Start it with: docker compose up -d"
    exit 0
fi

echo "==> Executing idempotent provisioning inside container..."

if command -v jq >/dev/null 2>&1; then
    jq -c '.groups[]' "$SEED_FILE" | while read -r group; do
        gname=$(echo "$group" | jq -r '.name')
        echo "    Ensuring group: $gname"
        docker exec -i ferrous-iam kanidm group create "$gname" 2>/dev/null || true
    done

    jq -c '.users[]' "$SEED_FILE" | while read -r user; do
        uname=$(echo "$user" | jq -r '.username')
        dname=$(echo "$user" | jq -r '.display_name')
        ugroup=$(echo "$user" | jq -r '.group')
        varname=$(echo "$user" | jq -r '.env_password_var')
        upass="${!varname:-DevDefaultPass2026!}"
        if [[ "$upass" =~ ^\<.* ]]; then
            upass="DevDefaultPass2026!"
        fi

        echo "    Ensuring user: $uname ($ugroup) [Password sourced from $varname]"
        docker exec -i ferrous-iam kanidm person create "$uname" "$dname" 2>/dev/null || true
        docker exec -i ferrous-iam kanidm person credential create-password "$uname" "$upass" 2>/dev/null || true
        docker exec -i ferrous-iam kanidm group add_members "$ugroup" "$uname" 2>/dev/null || true
    done
fi

echo "==> Human RBAC personas provisioned successfully!"
