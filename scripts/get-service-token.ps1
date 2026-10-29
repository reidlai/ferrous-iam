# PowerShell Script to Issue / Retrieve M2M Service Account Tokens for Submodules
param(
    [string]$Account = "svc_ferrous_lakehouse"
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$submoduleDir = Split-Path -Parent $scriptDir

$validAccounts = @(
    "svc_stream_replay",
    "svc_ferrous_cqrses",
    "svc_ferrous_streaming",
    "svc_ferrous_lakehouse",
    "svc_ferrous_api",
    "svc_ferrous_agent"
)

if ($validAccounts -notcontains $Account) {
    Write-Error "Invalid service account '$Account'. Valid accounts: $($validAccounts -join ', ')"
    exit 1
}

$secretsDir = Join-Path $submoduleDir ".secrets\tokens"
if (-not (Test-Path $secretsDir)) {
    New-Item -ItemType Directory -Path $secretsDir -Force | Out-Null
}

$tokenFile = Join-Path $secretsDir "$Account.token"

# Generate or retrieve token
if (-not (Test-Path $tokenFile)) {
    # Generate secure 32-byte hex token for local development / testing
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $token = [System.BitConverter]::ToString($bytes).Replace("-", "").ToLower()
    Set-Content -Path $tokenFile -Value "ferrous_jwt_m2m_${Account}_$token" -Force
}

$tokenValue = (Get-Content -Path $tokenFile -Raw).Trim()

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "      FERROUS M2M SERVICE ACCOUNT TOKEN GENERATED         " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  Service Account: $Account" -ForegroundColor Cyan
Write-Host "  Bearer Token:    $tokenValue" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "To configure downstream submodules (e.g. ferrous-lakehouse), add to your .env:" -ForegroundColor White
if ($Account -eq "svc_ferrous_lakehouse") {
    Write-Host "  LAKEHOUSE_SERVICE_ACCOUNT=$Account" -ForegroundColor Yellow
    Write-Host "  LAKEHOUSE_SERVICE_TOKEN=$tokenValue" -ForegroundColor Yellow
} else {
    Write-Host "  SERVICE_ACCOUNT=$Account" -ForegroundColor Yellow
    Write-Host "  SERVICE_TOKEN=$tokenValue" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "==> Saved to local git-ignored file: .secrets\tokens\$Account.token"
