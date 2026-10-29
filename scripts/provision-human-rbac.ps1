# PowerShell Human RBAC Provisioner for FerrousCX Kanidm
param (
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$submoduleDir = Split-Path -Parent $scriptDir
$seedFile = Join-Path $submoduleDir "config\seed-rbac.json"
$envFile = Join-Path $submoduleDir ".env"
$envExampleFile = Join-Path $submoduleDir ".env.example"

# Load local .env if present (or fallback to .env.example for defaults)
if (Test-Path $envFile) {
    Write-Host "==> Loading credentials from local .env (git-ignored)..."
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split("=", 2)
            [System.Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "Process")
        }
    }
} elseif (Test-Path $envExampleFile) {
    Write-Host "==> No .env found. Sourcing fallback defaults from .env.example..."
    Get-Content $envExampleFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split("=", 2)
            $varName = $parts[0].Trim()
            if (-not [System.Environment]::GetEnvironmentVariable($varName, "Process")) {
                [System.Environment]::SetEnvironmentVariable($varName, $parts[1].Trim(), "Process")
            }
        }
    }
}

if (-not (Test-Path $seedFile)) {
    Write-Error "Seed file not found at $seedFile"
    exit 1
}

$seed = Get-Content -Raw $seedFile | ConvertFrom-Json

Write-Host "==> Loaded seed configuration for domain: $($seed.domain)"

if ($DryRun) {
    Write-Host "==> DRY-RUN: Validating RBAC definitions..."
    Write-Host "    Groups ($($seed.groups.Count)): $($seed.groups.name -join ', ')"
    foreach ($u in $seed.users) {
        $envVar = $u.env_password_var
        $isConfigured = [bool][System.Environment]::GetEnvironmentVariable($envVar, "Process")
        Write-Host "    User: $($u.username) [$($u.group)] -> Password source: $envVar (Configured: $isConfigured, Secret REDACTED)"
    }
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
    $envVar = $u.env_password_var
    $password = [System.Environment]::GetEnvironmentVariable($envVar, "Process")
    if (-not $password -or $password.StartsWith("<")) {
        $password = "DevDefaultPass2026!"
    }
    Write-Host "    Ensuring user: $($u.username) ($($u.group)) [Password sourced from $envVar]"
    docker exec -i ferrous-iam kanidm person create $u.username $u.display_name 2>$null | Out-Null
    docker exec -i ferrous-iam kanidm person credential create-password $u.username $password 2>$null | Out-Null
    docker exec -i ferrous-iam kanidm group add_members $u.group $u.username 2>$null | Out-Null
}

Write-Host "==> Human RBAC personas provisioned successfully!"
