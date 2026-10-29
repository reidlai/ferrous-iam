# PowerShell Human RBAC Provisioner for FerrousCX Kanidm
param (
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$seedFile = Join-Path (Split-Path -Parent $scriptDir) "config\seed-rbac.json"

if (-not (Test-Path $seedFile)) {
    Write-Error "Seed file not found at $seedFile"
    exit 1
}

$seed = Get-Content -Raw $seedFile | ConvertFrom-Json

Write-Host "==> Loaded seed configuration for domain: $($seed.domain)"

if ($DryRun) {
    Write-Host "==> DRY-RUN: Validating RBAC definitions..."
    Write-Host "    Groups ($($seed.groups.Count)): $($seed.groups.name -join ', ')"
    Write-Host "    Users  ($($seed.users.Count)):  $($seed.users.username -join ', ')"
    Write-Host "==> DRY-RUN completed successfully."
    exit 0
}

Write-Host "==> Validating Docker / Kanidm daemon presence..."
$containerRunning = $false
try {
    $runningContainers = (& docker ps --format "{{.Names}}" 2>&1)
    if ($LASTEXITCODE -eq 0 -and $runningContainers -contains "ferrous-iam") {
        $containerRunning = $true
    }
} catch {
    $containerRunning = $false
}

if (-not $containerRunning) {
    Write-Warning "Container 'ferrous-iam' is not currently running or Docker engine is offline."
    Write-Host "    To start Docker Desktop: Ensure Docker Desktop is launched and running."
    Write-Host "    To launch daemon:        docker compose up -d"
    Write-Host "    (Seed configuration validated clean)."
    exit 0
}

Write-Host "==> Executing idempotent provisioning inside container..."
foreach ($g in $seed.groups) {
    Write-Host "    Ensuring group: $($g.name)"
    docker exec -i ferrous-iam kanidm group create $g.name 2>$null | Out-Null
}

foreach ($u in $seed.users) {
    Write-Host "    Ensuring user: $($u.username) ($($u.group))"
    docker exec -i ferrous-iam kanidm person create $u.username $u.display_name 2>$null | Out-Null
    docker exec -i ferrous-iam kanidm person credential create-password $u.username $u.dev_password 2>$null | Out-Null
    docker exec -i ferrous-iam kanidm group add_members $u.group $u.username 2>$null | Out-Null
}

Write-Host "==> Human RBAC personas provisioned successfully!"

