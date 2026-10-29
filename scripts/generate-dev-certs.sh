#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/../config/certs"
CNF_FILE="${CERTS_DIR}/openssl_dev.cnf"

mkdir -p "${CERTS_DIR}"

cat << 'EOF' > "${CNF_FILE}"
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = localhost
O = FerrousCX
OU = IAM

[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = ferrous-iam
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

echo "==> Generating self-signed development TLS certificates for FerrousCX Kanidm..."

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "${CERTS_DIR}/key.pem" \
  -out "${CERTS_DIR}/chain.pem" \
  -config "${CNF_FILE}"

rm -f "${CNF_FILE}"

chmod 600 "${CERTS_DIR}/key.pem"
chmod 644 "${CERTS_DIR}/chain.pem"

echo "==> Development certificates successfully generated:"
echo "    - Chain: ${CERTS_DIR}/chain.pem"
echo "    - Key:   ${CERTS_DIR}/key.pem"
