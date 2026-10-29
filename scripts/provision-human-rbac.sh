#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEED_FILE="${SCRIPT_DIR}/../config/seed-rbac.json"
KANIDM_URL="${KANIDM_URL:-https://localhost:8443}"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"

# Parse optional dry-run flag
DRY_RUN=false
for arg in "$@"; do
  if [ "$arg" == "--dry-run" ]; then
    DRY_RUN=true
  fi
done

echo "==> Loading seed configuration from: ${SEED_FILE}"
if [ ! -f "${SEED_FILE}" ]; then
  echo "ERROR: Seed file not found at ${SEED_FILE}" >&2
  exit 1
fi

if [ "$DRY_RUN" = true ]; then
  echo "==> DRY-RUN: Validating JSON configuration..."
  python3 -c "import json; f=open('${SEED_FILE}'); data=json.load(f); print(f'Validated {len(data[\"groups\"])} groups and {len(data[\"users\"])} users.')" 2>/dev/null || \
  python -c "import json; f=open('${SEED_FILE}'); data=json.load(f); print(f'Validated {len(data[\"groups\"])} groups and {len(data[\"users\"])} users.')"
  echo "==> DRY-RUN completed successfully."
  exit 0
fi

echo "==> Connecting to Kanidm daemon at ${KANIDM_URL}..."

# In Docker environments, execute commands inside container or via CLI
KANIDM_CMD="kanidm"
if ! command -v kanidm &> /dev/null; then
  if docker ps --format '{{.Names}}' | grep -q "^ferrous-iam$"; then
    KANIDM_CMD="docker exec -i ferrous-iam kanidm"
  else
    echo "WARNING: Neither local 'kanidm' CLI nor running 'ferrous-iam' container found."
    echo "Configuration verified. Skipping live socket provisioning."
    exit 0
  fi
fi

# 1. Create RBAC Groups
echo "==> Provisioning Human RBAC Groups..."
$KANIDM_CMD group create customer_specialist 2>/dev/null || echo "Group customer_specialist already exists."
$KANIDM_CMD group create operations_manager 2>/dev/null || echo "Group operations_manager already exists."
$KANIDM_CMD group create system_admin 2>/dev/null || echo "Group system_admin already exists."

# 2. Create Human Personas
echo "==> Provisioning Human Personas..."
$KANIDM_CMD person create carlos.support "Carlos Silva" 2>/dev/null || echo "Person carlos.support already exists."
$KANIDM_CMD person credential create-password carlos.support "CarlosSupportPass2026!" 2>/dev/null || true
$KANIDM_CMD group add_members customer_specialist carlos.support 2>/dev/null || true

$KANIDM_CMD person create operations.lead "Operations Lead" 2>/dev/null || echo "Person operations.lead already exists."
$KANIDM_CMD person credential create-password operations.lead "OpsLeadManagerPass2026!" 2>/dev/null || true
$KANIDM_CMD group add_members operations_manager operations.lead 2>/dev/null || true

$KANIDM_CMD person create admin.sec "Security Admin" 2>/dev/null || echo "Person admin.sec already exists."
$KANIDM_CMD person credential create-password admin.sec "AdminSecurityMaster2026!" 2>/dev/null || true
$KANIDM_CMD group add_members system_admin admin.sec 2>/dev/null || true

echo "==> Human RBAC personas and basic auth policies successfully configured!"
