<#
.SYNOPSIS
    Fetch environment variables from a remote Vercel project via the CLI.

.DESCRIPTION
    Fetches all environment variables for a given Vercel environment and writes
    them to a local file with a clean header. Values are masked in terminal output.

.PARAMETER Project
    Project name or ID (required).

.PARAMETER Environment
    Target environment: production, preview, development, or a custom name.
    Default: production

.PARAMETER Output
    Output file path. Default: .env.pulled

.PARAMETER Token
    Vercel authentication token. Falls back to $env:VERCEL_TOKEN if not provided.

.EXAMPLE
    .\scripts\windows\vercel-pull-env.ps1 -Project my-project -Environment production -Output .env.production

.EXAMPLE
    .\scripts\windows\vercel-pull-env.ps1 -Project my-project -Environment staging -Token "your_token"

.EXAMPLE
    $env:VERCEL_TOKEN = "your_token"
    .\scripts\windows\vercel-pull-env.ps1 -Project my-project -Environment preview
#>

[CmdletBinding()]
param(
    [Alias('p')][string]$Project     = "",
    [Alias('e')][string]$Environment = "production",
    [Alias('o')][string]$Output      = ".env.pulled",
    [Alias('t')][string]$Token       = $env:VERCEL_TOKEN
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Helpers ───────────────────────────────────────────────────────────────────
function Write-Log  { Write-Host "[INFO] $args"  -ForegroundColor Cyan }
function Write-Ok   { Write-Host "[OK] $args"    -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN] $args"  -ForegroundColor Yellow }
function Write-Err  { Write-Host "[ERROR] $args" -ForegroundColor Red }
function Exit-Err   { Write-Err $args; exit 1 }

# ── Validation ────────────────────────────────────────────────────────────────
if (-not $Project) { Exit-Err "Missing project. Use -Project <name>." }

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

# ── Fetch variables ───────────────────────────────────────────────────────────
Write-Log "Fetching variables for project '$Project' (env: $Environment)..."

$tmpFile = [System.IO.Path]::GetTempFileName()
try {
    $pullArgs = @("env", "pull", $tmpFile, "--project", $Project, "--environment", $Environment, "--yes")
    $output   = & { Invoke-Vercel $pullArgs } 2>&1
    $pullExit = $LASTEXITCODE

    $output | Where-Object { $_ -notmatch '^Vercel CLI' } | ForEach-Object { Write-Host $_ }

    if ($pullExit -ne 0) {
        Exit-Err "Failed 'vercel env pull'. Check project name and environment."
    }

    if (-not (Test-Path $tmpFile) -or (Get-Item $tmpFile).Length -eq 0) {
        Write-Warn "No variables returned for environment '$Environment'."
        exit 0
    }

    # Build output file with clean header
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $header = @(
        "# ============================================================",
        "# Vercel env vars — project: $Project",
        "# Environment: $Environment",
        "# Generated: $timestamp",
        "# ============================================================",
        ""
    )
    $body = Get-Content $tmpFile | Where-Object { $_ -notmatch '^# Created by Vercel CLI' }
    ($header + $body) | Set-Content $Output -Encoding UTF8

    $count = (Get-Content $Output | Where-Object { $_ -match '^[^#\s]' }).Count
    Write-Ok "$count variable(s) written to $Output"

    # Preview — keys only, values masked
    Write-Host ""
    Write-Host "Preview (values masked):" -ForegroundColor White
    Get-Content $Output | Where-Object { $_ -match '^[^#\s]' } | ForEach-Object {
        $key = ($_ -split '=', 2)[0]
        Write-Host ("  {0,-40} = ***" -f $key)
    }
} finally {
    Remove-Item $tmpFile -ErrorAction SilentlyContinue
}
