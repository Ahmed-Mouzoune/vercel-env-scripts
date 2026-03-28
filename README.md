# vercel-env-scripts

Two scripts to manage Vercel environment variables from the command line — pull them from a remote environment into a local file, or push a local `.env` file to a remote environment.

Both scripts are built on top of the Vercel CLI (not the REST API). See [Why the CLI and not the API?](#why-the-cli-and-not-the-api) at the bottom for the reasoning.

**Requirements:** Vercel CLI must be installed. Authentication can be done either via `vercel login` or by providing a Vercel token.

## Platform support

| Platform | Location | Shell |
|----------|----------|-------|
| Linux / macOS | `scripts/linux/` | POSIX-compatible `sh` (works with `sh`, `dash`, `ash`, `a-Shell`) |
| Windows | `scripts/windows/` | PowerShell (`.ps1`) |

## Scripts

| Script | Description |
|--------|-------------|
| `vercel-pull-env` | Fetch env vars from a remote Vercel environment → local file |
| `vercel-push-env` | Push env vars from a local file → remote Vercel environment |

## Setup

### Linux / macOS

```bash
git clone https://github.com/<your-username>/vercel-env-scripts.git
cd vercel-env-scripts
chmod +x scripts/linux/vercel-pull-env.sh scripts/linux/vercel-push-env.sh
```

### Windows (PowerShell)

```powershell
git clone https://github.com/<your-username>/vercel-env-scripts.git
cd vercel-env-scripts
# Allow local scripts to run (once per machine)
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### Install the Vercel CLI

```bash
npm i -g vercel
```

### Authentication

You have two options for authentication:

**Option 1: Interactive login (recommended for local use)**
```bash
vercel login
```

No token to manage, no environment variable to export. The CLI handles authentication.

**Option 2: Token-based (recommended for CI/CD and automation)**

Generate a token at https://vercel.com/account/tokens, then use it in one of three ways:

```bash
# Linux/macOS — Method 1: environment variable
export VERCEL_TOKEN="your_vercel_token_here"
sh scripts/linux/vercel-pull-env.sh -p my-project -e production

# Linux/macOS — Method 2: CLI parameter
sh scripts/linux/vercel-pull-env.sh -p my-project -e production -t "your_token"
```

```powershell
# Windows — Method 1: environment variable
$env:VERCEL_TOKEN = "your_vercel_token_here"
.\scripts\windows\vercel-pull-env.ps1 -Project my-project -Environment production

# Windows — Method 2: CLI parameter
.\scripts\windows\vercel-pull-env.ps1 -Project my-project -Environment production -Token "your_token"
```

## vercel-pull-env

Fetches all environment variables for a given Vercel environment and writes them to a local file.

### Usage

**Linux / macOS**
```bash
sh scripts/linux/vercel-pull-env.sh [options]
```

**Windows**
```powershell
.\scripts\windows\vercel-pull-env.ps1 [options]
```

### Options

| Linux flag | Windows flag | Description | Default |
|------------|--------------|-------------|---------|
| `-p, --project <PROJECT>` | `-Project <PROJECT>` | Project name or ID | *required* |
| `-e, --env <ENV>` | `-Environment <ENV>` | Target environment: `production` \| `preview` \| `development` \| `<custom>` | `production` |
| `-o, --output <FILE>` | `-Output <FILE>` | Output file | `.env.pulled` |
| `-t, --token <TOKEN>` | `-Token <TOKEN>` | Vercel authentication token (or use `$VERCEL_TOKEN`) | - |
| `-h, --help` | `Get-Help` | Show help | - |

### Examples

**Linux / macOS**
```bash
# Pull production vars (using vercel login session)
sh scripts/linux/vercel-pull-env.sh -p my-project -e production -o .env.production

# Pull using a token
sh scripts/linux/vercel-pull-env.sh -p my-project -e production -o .env.production -t "your_token"

# Pull a custom environment (e.g. staging)
sh scripts/linux/vercel-pull-env.sh -p my-project -e staging -o .env.staging

# Pull preview vars with token from environment variable
export VERCEL_TOKEN="your_token"
sh scripts/linux/vercel-pull-env.sh -p my-project -e preview -o .env.preview
```

**Windows**
```powershell
# Pull production vars (using vercel login session)
.\scripts\windows\vercel-pull-env.ps1 -Project my-project -Environment production -Output .env.production

# Pull using a token
.\scripts\windows\vercel-pull-env.ps1 -Project my-project -Environment production -Output .env.production -Token "your_token"

# Pull a custom environment (e.g. staging)
.\scripts\windows\vercel-pull-env.ps1 -Project my-project -Environment staging -Output .env.staging

# Pull preview vars with token from environment variable
$env:VERCEL_TOKEN = "your_token"
.\scripts\windows\vercel-pull-env.ps1 -Project my-project -Environment preview -Output .env.preview
```

### Output

The script writes a `.env`-formatted file and prints a summary with keys only (values are masked in the terminal):

```
[INFO] Fetching variables for project 'my-project' (env: staging)...
[OK] 12 variable(s) written to .env.staging

Preview (values masked):
  DATABASE_URL                              = ***
  NEXT_PUBLIC_API_URL                       = ***
  SECRET_KEY                                = ***
  ...
```

## vercel-push-env

Reads a local `.env` file and pushes each variable to the specified Vercel environment.

### Usage

**Linux / macOS**
```bash
sh scripts/linux/vercel-push-env.sh [options]
```

**Windows**
```powershell
.\scripts\windows\vercel-push-env.ps1 [options]
```

### Options

| Linux flag | Windows flag | Description | Default |
|------------|--------------|-------------|---------|
| `-p, --project <PROJECT>` | `-Project <PROJECT>` | Project name or ID | *required* |
| `-e, --env <ENV>` | `-Environment <ENV>` | Target environment: `production` \| `preview` \| `development` \| `<custom>` | `production` |
| `-f, --file <FILE>` | `-File <FILE>` | Source file | `.env` |
| `-t, --token <TOKEN>` | `-Token <TOKEN>` | Vercel authentication token (or use `$VERCEL_TOKEN`) | - |
| `--dry-run` | `-DryRun` | Simulate without pushing anything | `false` |
| `--overwrite` | `-Overwrite` | Overwrite existing variables | `false` |
| `-h, --help` | `Get-Help` | Show help | - |

### Examples

**Linux / macOS**
```bash
# Push .env.production to production (using vercel login session)
sh scripts/linux/vercel-push-env.sh -p my-project -e production -f .env.production

# Push using a token
sh scripts/linux/vercel-push-env.sh -p my-project -e production -f .env.production -t "your_token"

# Push to a custom environment (e.g. staging)
sh scripts/linux/vercel-push-env.sh -p my-project -e staging -f .env.staging

# Push and overwrite existing vars
sh scripts/linux/vercel-push-env.sh -p my-project -e production -f .env.production --overwrite

# Dry-run: see what would be pushed without touching anything
sh scripts/linux/vercel-push-env.sh -p my-project -e staging -f .env --dry-run

# CI/CD usage with token
export VERCEL_TOKEN="${CI_VERCEL_TOKEN}"
sh scripts/linux/vercel-push-env.sh -p my-project -e production -f .env.production --overwrite
```

**Windows**
```powershell
# Push .env.production to production
.\scripts\windows\vercel-push-env.ps1 -Project my-project -Environment production -File .env.production

# Push using a token
.\scripts\windows\vercel-push-env.ps1 -Project my-project -Environment production -File .env.production -Token "your_token"

# Push to a custom environment (e.g. staging)
.\scripts\windows\vercel-push-env.ps1 -Project my-project -Environment staging -File .env.staging

# Push and overwrite existing vars
.\scripts\windows\vercel-push-env.ps1 -Project my-project -Environment production -File .env.production -Overwrite

# Dry-run: see what would be pushed without touching anything
.\scripts\windows\vercel-push-env.ps1 -Project my-project -Environment staging -File .env -DryRun

# CI/CD usage with token
$env:VERCEL_TOKEN = $env:CI_VERCEL_TOKEN
.\scripts\windows\vercel-push-env.ps1 -Project my-project -Environment production -File .env.production -Overwrite
```

### Source file format

Standard `.env` format is supported:

```bash
# This is a comment — ignored
DATABASE_URL=postgresql://user:pass@host/db
NEXT_PUBLIC_API_URL=https://api.example.com
SECRET_KEY="my secret value"  # quotes are stripped automatically
```

Lines starting with `#` and empty lines are skipped. Surrounding quotes (`"value"` or `'value'`) are stripped from values.

### Output

```
╔══════════════════════════════════════════╗
║  Vercel Push Env — 14:32:15              ║
╚══════════════════════════════════════════╝

[INFO] Fetching existing vars on 'staging'...
[INFO] 3 variable(s) already present for 'staging'.

[INFO] Reading '.env.staging'...

[OK] CREATED DATABASE_URL
[OK] CREATED NEXT_PUBLIC_API_URL
[SKIP] SECRET_KEY (already exists — use --overwrite to replace)
[OK] UPDATED ANOTHER_VAR

──────────────── Summary ────────────────
[OK] Created  : 8
[OK] Updated  : 1
[WARN] Skipped  : 3
─────────────────────────────────────────
```

## Common workflows

### Copy vars from one environment to another

**Linux / macOS**
```bash
# 1. Pull from production
sh scripts/linux/vercel-pull-env.sh -p my-project -e production -o .env.production

# 2. Review, then push to staging
sh scripts/linux/vercel-push-env.sh -p my-project -e staging -f .env.production --dry-run
sh scripts/linux/vercel-push-env.sh -p my-project -e staging -f .env.production --overwrite
```

**Windows**
```powershell
.\scripts\windows\vercel-pull-env.ps1 -Project my-project -Environment production -Output .env.production
.\scripts\windows\vercel-push-env.ps1 -Project my-project -Environment staging -File .env.production -DryRun
.\scripts\windows\vercel-push-env.ps1 -Project my-project -Environment staging -File .env.production -Overwrite
```

### Sync vars across multiple projects

**Linux / macOS**
```bash
for project in project-a project-b project-c; do
  sh scripts/linux/vercel-push-env.sh -p "$project" -e production -f .env.shared --overwrite
done
```

**Windows**
```powershell
foreach ($project in @("project-a", "project-b", "project-c")) {
    .\scripts\windows\vercel-push-env.ps1 -Project $project -Environment production -File .env.shared -Overwrite
}
```

### Bootstrap a new project from an existing one

**Linux / macOS**
```bash
sh scripts/linux/vercel-pull-env.sh -p existing-project -e production -o .env.base
# Edit .env.base as needed
sh scripts/linux/vercel-push-env.sh -p new-project -e production -f .env.base
```

**Windows**
```powershell
.\scripts\windows\vercel-pull-env.ps1 -Project existing-project -Environment production -Output .env.base
# Edit .env.base as needed
.\scripts\windows\vercel-push-env.ps1 -Project new-project -Environment production -File .env.base
```

### CI/CD automation

**Linux / macOS**
```bash
#!/bin/sh
# deploy-env.sh

export VERCEL_TOKEN="${CI_VERCEL_TOKEN}"

# Pull production vars
sh scripts/linux/vercel-pull-env.sh -p my-app -e production -o .env.production

# Add build-specific vars
printf 'BUILD_ID=%s\n' "$(git rev-parse HEAD)"              >> .env.production
printf 'DEPLOY_TIME=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> .env.production

# Push to preview environment
sh scripts/linux/vercel-push-env.sh -p my-app -e preview -f .env.production --overwrite
```

**Windows**
```powershell
$env:VERCEL_TOKEN = $env:CI_VERCEL_TOKEN

.\scripts\windows\vercel-pull-env.ps1 -Project my-app -Environment production -Output .env.production

Add-Content .env.production "BUILD_ID=$(git rev-parse HEAD)"
Add-Content .env.production "DEPLOY_TIME=$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"

.\scripts\windows\vercel-push-env.ps1 -Project my-app -Environment preview -File .env.production -Overwrite
```

### Backup before updates

**Linux / macOS**
```bash
# Backup current vars
sh scripts/linux/vercel-pull-env.sh -p my-project -e production -o "backup-$(date +%Y%m%d).env"

# Make changes locally, test with dry-run, then apply
sh scripts/linux/vercel-push-env.sh -p my-project -e production -f .env.production --dry-run
sh scripts/linux/vercel-push-env.sh -p my-project -e production -f .env.production --overwrite
```

**Windows**
```powershell
$date = Get-Date -Format 'yyyyMMdd'
.\scripts\windows\vercel-pull-env.ps1 -Project my-project -Environment production -Output "backup-$date.env"

.\scripts\windows\vercel-push-env.ps1 -Project my-project -Environment production -File .env.production -DryRun
.\scripts\windows\vercel-push-env.ps1 -Project my-project -Environment production -File .env.production -Overwrite
```

## Security best practices

- ✅ **Never commit tokens to version control**
- ✅ Store tokens in CI/CD secrets or secure vaults
- ✅ Use environment-specific tokens with minimal permissions
- ✅ Rotate tokens regularly
- ✅ Add to `.gitignore`:

```gitignore
.env*
!.env.example
.vercel
*.pulled
```

## Troubleshooting

### "'vercel' CLI not found"
```bash
npm install -g vercel
```

### "Not logged in"
```bash
# Option 1: Interactive login
vercel login

# Option 2: Use a token
export VERCEL_TOKEN="your_token"      # Linux/macOS
$env:VERCEL_TOKEN = "your_token"      # Windows
```

### "Invalid or expired token"
Generate a new token at https://vercel.com/account/tokens

### Variables not appearing after push
Wait a few seconds, then verify:
```bash
vercel env ls --project my-project
```

### Windows: "running scripts is disabled on this system"
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

## Why the CLI and not the API?

These scripts deliberately use the Vercel CLI (`vercel env pull`, `vercel env add`, `vercel env rm`) rather than calling the Vercel REST API directly. Here's why.

### Custom environments are first-class citizens

Vercel lets you create custom environments beyond the three defaults (`production`, `preview`, `development`) — for example `staging`, `canary`, or `qa`. The CLI understands these environments natively: it resolves them the same way the Vercel dashboard does.

The REST API, on the other hand, works at a lower abstraction level. When you create or update a variable through the API targeting a custom environment, the variable is stored correctly under the hood — but the Vercel UI may not reflect it properly. The variable won't always appear in the environment's dedicated section on the dashboard, making it hard to verify what's actually set without running another API call. This creates a gap between what your scripts do and what you see in the interface.

### What you push is what you see

When the CLI pushes a variable, Vercel's backend processes it through the same pipeline as a manual action in the UI. The result is identical: the variable shows up immediately in the correct environment column, with the right type (encrypted, sensitive, plain), and is visible to every team member. There is no state drift between the CLI and the dashboard.

With direct API calls, you may run into edge cases where the variable exists in the data model but is not surfaced in the right place in the UI — particularly for custom environments and for the "sensitive" type. Debugging this requires cross-referencing raw API responses against the UI, which defeats the purpose of having a simple automation script.

### Flexible authentication

The CLI supports both interactive login (`vercel login`) and token-based authentication (`--token` or `$VERCEL_TOKEN`). This makes it ideal for:
- **Local development**: Use `vercel login` for a seamless interactive experience
- **CI/CD pipelines**: Use tokens stored in secure secrets managers
- **Team collaboration**: No need to share tokens for local work

You don't need to manage API token lifecycle manually for local work, but you have the flexibility to use tokens when automation requires it.

### Stability

The REST API is versioned (`/v9/projects/...`) but Vercel occasionally changes field names, deprecates endpoints, or alters the shape of responses for env vars — especially as they add features like custom environments and branching. The CLI abstracts over these changes. Pinning to a specific CLI version (`npm i -g vercel@latest`) is more reliable than maintaining raw API calls that may silently break when Vercel updates their backend.

## License

MIT
