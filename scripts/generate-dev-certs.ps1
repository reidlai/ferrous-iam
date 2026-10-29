# PowerShell Dev TLS Certificate Generator for FerrousCX Kanidm
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$certsDir = Join-Path (Split-Path -Parent $scriptDir) "config\certs"
$cnfFile = Join-Path $certsDir "openssl_dev.cnf"

if (-not (Test-Path $certsDir)) {
    New-Item -ItemType Directory -Force -Path $certsDir | Out-Null
}

$cnfContent = @"
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
"@

Set-Content -Path $cnfFile -Value $cnfContent

Write-Host "==> Generating self-signed development TLS certificates for FerrousCX Kanidm..."

$keyPath = Join-Path $certsDir "key.pem"
$chainPath = Join-Path $certsDir "chain.pem"

if (Get-Command openssl -ErrorAction SilentlyContinue) {
    & openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
      -keyout $keyPath `
      -out $chainPath `
      -config $cnfFile
    
    Remove-Item -Force $cnfFile -ErrorAction SilentlyContinue
    
    Write-Host "==> Development certificates successfully generated via OpenSSL:"
    Write-Host "    - Chain: $chainPath"
    Write-Host "    - Key:   $keyPath"
} else {
    Remove-Item -Force $cnfFile -ErrorAction SilentlyContinue
    Write-Warning "OpenSSL command not found in PATH. Please install OpenSSL or generate certificates via Docker container."
}
