<#
.SYNOPSIS
    Push environment variables from a local file to a Vercel project via the CLI.

.DESCRIPTION
    Reads a local .env file and pushes each variable to the specified Vercel
    environment. Supports dry-run mode and optional overwrite of existing vars.

.PARAMETER Project
    Project name or ID (required).

.PARAMETER Environment
    Target environment: production, preview, development, or a custom name.
    Default: production

.PARAMETER File
    Source .env file path. Default: .env

.PARAMETER Token
    Vercel authentication token. Falls back to $env:VERCEL_TOKEN if not provided.

.PARAMETER DryRun
    Simulate without pushing anything.

.PARAMETER Overwrite
    Overwrite existing variables (default: skip them).

.EXAMPLE
    .\scripts\windows\vercel-push-env.ps1 -Project my-project -Environment production -File .env.production

.EXAMPLE
    .\scripts\windows\vercel-push-env.ps1 -Project my-project -Environment staging -Overwrite -Token "your_token"

.EXAMPLE
    $env:VERCEL_TOKEN = "your_token"
    .\scripts\windows\vercel-push-env.ps1 -Project my-project -Environment preview -File .env -DryRun
#>

[CmdletBinding()]
param(
    [Alias('p')][string]$Project     = "",
    [Alias('e')][string]$Environment = "production",
    [Alias('f')][string]$File        = ".env",
    [Alias('t')][string]$Token       = $env:VERCEL_TOKEN,
    [switch]$DryRun,
    [switch]$Overwrite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Helpers ───────────────────────────────────────────────────────────────────
function Write-Log  { Write-Host "[INFO] $args"    -ForegroundColor Cyan }
function Write-Ok   { Write-Host "[OK] $args"      -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN] $args"    -ForegroundColor Yellow }
function Write-Skip { Write-Host "[SKIP] $args"    -ForegroundColor Yellow }
function Write-Dry  { Write-Host "  [DRY] $args"   -ForegroundColor Yellow }
function Write-Err  { Write-Host "[ERROR] $args"   -ForegroundColor Red }
function Exit-Err   { Write-Err $args; exit 1 }

# ── Validation ────────────────────────────────────────────────────────────────
if (-not $Project)           { Exit-Err "Missing project. Use -Project <name>." }
if (-not (Test-Path $File))  { Exit-Err "Source file not found: '$File'" }

if (-not (Get-Command vercel -ErrorAction SilentlyContinue)) {
    Exit-Err "'vercel' CLI not found. Install it: npm i -g vercel"
}

# ── Auth check ────────────────────────────────────────────────────────────────
if ($Token) {
    vercel whoami --token $Token 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Exit-Err "Invalid or expired token." }
} else {
    vercel whoami 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Exit-Err "Not logged in. Use -Token or: vercel login" }
}

# ── Helper: run vercel with optional token ────────────────────────────────────
function Invoke-Vercel {
    param([string[]]$Arguments)
    if ($Token) {
        & vercel @Arguments --token $Token
    } else {
        & vercel @Arguments
    }
    return $LASTEXITCODE
}

# ── Helper: pipe a value to 'vercel env add' with optional token ───────────────
function Add-VercelEnvVar {
    param([string]$Value, [string[]]$Arguments)
    if ($Token) {
        $Value | & vercel @Arguments --token $Token 2>&1 | Out-Null
    } else {
        $Value | & vercel @Arguments 2>&1 | Out-Null
    }
}

# ── Header ────────────────────────────────────────────────────────────────────
$time = Get-Date -Format 'HH:mm:ss'
Write-Host ""
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor White
Write-Host ("║  Vercel Push Env — {0,-23}║" -f "$time") -ForegroundColor White
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor White
Write-Host ""

if ($DryRun)    { Write-Warn "DRY-RUN mode — no changes will be made" }
if ($Overwrite) { Write-Warn "OVERWRITE mode — existing variables will be replaced" }
Write-Host ""

# ── Fetch existing variables ──────────────────────────────────────────────────
Write-Log "Fetching existing vars on '$Environment'..."

$lsOutput     = Invoke-Vercel @("env", "ls", "--project", $Project) 2>&1
$existingNames = @($lsOutput | Where-Object { $_ -match $Environment } | ForEach-Object {
    ($_ -split '\s+' | Where-Object { $_ -ne '' })[0]
})

Write-Log "$($existingNames.Count) variable(s) already present for '$Environment'."
Write-Host ""

# ── Process source file ───────────────────────────────────────────────────────
Write-Log "Reading '$File'..."
Write-Host ""

$countPushed  = 0
$countSkipped = 0
$countUpdated = 0
$countErrors  = 0
$lineNum      = 0

foreach ($line in (Get-Content $File)) {
    $lineNum++
    $trimmed = $line.TrimStart()

    # Skip empty lines and comments
    if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }

    # Validate KEY=VALUE format
    if ($trimmed -notmatch '^[A-Za-z_][A-Za-z0-9_]*=') {
        Write-Warn "Line $lineNum ignored (invalid format): $line"
        continue
    }

    # Extract key and value
    $eqIndex = $trimmed.IndexOf('=')
    $key     = $trimmed.Substring(0, $eqIndex)
    $value   = $trimmed.Substring($eqIndex + 1)

    # Strip surrounding double or single quotes
    if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
        $value = $Matches[1]
    }

    $exists = $existingNames -contains $key

    # DRY-RUN mode
    if ($DryRun) {
        if ($exists) {
            if ($Overwrite) { Write-Dry "WOULD UPDATE $key" }
            else            { Write-Dry "WOULD SKIP $key (already exists, -Overwrite not set)" }
        } else {
            Write-Dry "WOULD CREATE $key"
        }
        continue
    }

    # Existing variable
    if ($exists) {
        if ($Overwrite) {
            Invoke-Vercel @("env", "rm", $key, $Environment, "--project", $Project, "--yes") 2>&1 | Out-Null
            Add-VercelEnvVar -Value $value -Arguments @("env", "add", $key, $Environment, "--project", $Project, "--sensitive")
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "UPDATED $key"
                $countUpdated++
            } else {
                Write-Err "FAILED to update $key"
                $countErrors++
            }
        } else {
            Write-Skip "$key (already exists — use -Overwrite to replace)"
            $countSkipped++
        }
        continue
    }

    # New variable — value is piped via stdin to avoid leaking it in process lists
    Add-VercelEnvVar -Value $value -Arguments @("env", "add", $key, $Environment, "--project", $Project)
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "CREATED $key"
        $countPushed++
    } else {
        Write-Err "FAILED to create $key"
        $countErrors++
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "──────────────── Summary ────────────────" -ForegroundColor White
if ($DryRun) {
    Write-Warn "Simulation complete. No variables were modified."
} else {
    Write-Ok "Created  : $countPushed"
    if ($countUpdated -gt 0) { Write-Ok  "Updated  : $countUpdated" }
    if ($countSkipped -gt 0) { Write-Warn "Skipped  : $countSkipped" }
    if ($countErrors  -gt 0) { Write-Err  "Errors   : $countErrors" }
}
Write-Host "─────────────────────────────────────────" -ForegroundColor White
Write-Host ""

if ($countErrors -gt 0) { exit 1 }
exit 0
