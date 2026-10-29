# PowerShell Script to Recover and Display Kanidm Admin Credentials
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$submoduleDir = Split-Path -Parent $scriptDir

$containerRunning = $false
try {
    $running = (& docker ps --format "{{.Names}}" 2>&1)
    if ($LASTEXITCODE -eq 0 -and $running -contains "ferrous-iam") {
        $containerRunning = $true
    }
} catch {
    $containerRunning = $false
}

if (-not $containerRunning) {
    Write-Error "Container 'ferrous-iam' is not currently running. Please run: docker compose up -d"
    exit 1
}

Write-Host "==> Requesting one-time admin recovery credential from Kanidm daemon..."
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$rawOutput = & docker exec -i ferrous-iam /sbin/kanidmd recover-account -c /etc/kanidm/server.toml admin 2>&1
$ErrorActionPreference = $prevEAP

$password = $null
foreach ($line in $rawOutput) {
    if ($line -match 'new_password:\s*"([^"]+)"') {
        $password = $matches[1]
        break
    }
}

if (-not $password) {
    Write-Error "Could not parse recovery password from Kanidm output:`n$rawOutput"
    exit 1
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "         KANIDM ADMINISTRATOR LOGIN CREDENTIALS           " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  Web UI URL:   https://localhost:8443" -ForegroundColor Cyan
Write-Host "  Username:     admin" -ForegroundColor Yellow
Write-Host "  Password:     $password" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Instructions:"
Write-Host " 1. Open https://localhost:8443 in your browser (accept TLS warning)."
Write-Host " 2. Type 'admin' and click Begin."
Write-Host " 3. Paste the password above when prompted."
Write-Host ""

# Save to local git-ignored .secrets directory for developer convenience
$secretsDir = Join-Path $submoduleDir ".secrets"
if (-not (Test-Path $secretsDir)) {
    New-Item -ItemType Directory -Path $secretsDir -Force | Out-Null
}
$secretFile = Join-Path $secretsDir "admin_password.txt"
Set-Content -Path $secretFile -Value $password -Force
Write-Host "==> Password also saved to local git-ignored file: .secrets\admin_password.txt"
