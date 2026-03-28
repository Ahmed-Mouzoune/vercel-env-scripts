# vercel-env-scripts

Two Bash scripts to manage Vercel environment variables from the command line — pull them from a remote environment into a local file, or push a local .env file to a remote environment.

Both scripts are built on top of the Vercel CLI (not the REST API). See [Why the CLI and not the API?](#why-the-cli-and-not-the-api) at the bottom for the reasoning.

**Requirements:** Vercel CLI must be installed. Authentication can be done either via `vercel login` or by providing a Vercel token.

## Scripts

| Script | Description |
|--------|-------------|
| `vercel-pull-env.sh` | Fetch env vars from a remote Vercel environment → local file |
| `vercel-push-env.sh` | Push env vars from a local file → remote Vercel environment |

## Setup

```bash
git clone https://github.com/<your-username>/vercel-env-scripts.git
cd vercel-env-scripts
chmod +x vercel-pull-env.sh vercel-push-env.sh
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
# Method 1: Environment variable
export VERCEL_TOKEN="your_vercel_token_here"
./vercel-pull-env.sh -p my-project -e production

# Method 2: CLI parameter
./vercel-pull-env.sh -p my-project -e production -t "your_token"

# Method 3: From a local .env file (don't commit this!)
source .env.local  # contains VERCEL_TOKEN=...
./vercel-pull-env.sh -p my-project -e production
```

## vercel-pull-env.sh

Fetches all environment variables for a given Vercel environment and writes them to a local file.

### Usage

```bash
./vercel-pull-env.sh [options]
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-p, --project <PROJECT>` | Project name or ID | *required* |
| `-e, --env <ENV>` | Target environment: `production` \| `preview` \| `development` \| `<custom>` | `production` |
| `-o, --output <FILE>` | Output file | `.env.pulled` |
| `-t, --token <TOKEN>` | Vercel authentication token (or use `$VERCEL_TOKEN`) | - |
| `-h, --help` | Show help | - |

### Examples

```bash
# Pull production vars (using vercel login session)
./vercel-pull-env.sh -p my-project -e production -o .env.production

# Pull using a token
./vercel-pull-env.sh -p my-project -e production -o .env.production -t "your_token"

# Pull a custom environment (e.g. staging)
./vercel-pull-env.sh -p my-project -e staging -o .env.staging

# Pull preview vars with token from environment variable
export VERCEL_TOKEN="your_token"
./vercel-pull-env.sh -p my-project -e preview -o .env.preview
```

### Output

The script writes a `.env`-formatted file and prints a summary with keys only (values are masked in the terminal):

```
[INFO] Récupération des variables du projet 'my-project' (env: staging)...
[OK] 12 variable(s) écrite(s) dans .env.staging

Aperçu (valeurs masquées) :
  DATABASE_URL                              = ***
  NEXT_PUBLIC_API_URL                       = ***
  SECRET_KEY                                = ***
  ...
```

## vercel-push-env.sh

Reads a local `.env` file and pushes each variable to the specified Vercel environment.

### Usage

```bash
./vercel-push-env.sh [options]
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-p, --project <PROJECT>` | Project name or ID | *required* |
| `-e, --env <ENV>` | Target environment: `production` \| `preview` \| `development` \| `<custom>` | `production` |
| `-f, --file <FILE>` | Source file | `.env` |
| `-t, --token <TOKEN>` | Vercel authentication token (or use `$VERCEL_TOKEN`) | - |
| `--dry-run` | Simulate without pushing anything | `false` |
| `--overwrite` | Overwrite existing variables | `false` |
| `-h, --help` | Show help | - |

### Examples

```bash
# Push .env.production to production (using vercel login session)
./vercel-push-env.sh -p my-project -e production -f .env.production

# Push using a token
./vercel-push-env.sh -p my-project -e production -f .env.production -t "your_token"

# Push to a custom environment (e.g. staging)
./vercel-push-env.sh -p my-project -e staging -f .env.staging

# Push and overwrite existing vars
./vercel-push-env.sh -p my-project -e production -f .env.production --overwrite

# Dry-run: see what would be pushed without touching anything
./vercel-push-env.sh -p my-project -e staging -f .env --dry-run

# CI/CD usage with token
export VERCEL_TOKEN="${CI_VERCEL_TOKEN}"
./vercel-push-env.sh -p my-project -e production -f .env.production --overwrite
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

[INFO] Récupération des vars existantes sur 'staging'...
[INFO] 3 variable(s) déjà présente(s) pour 'staging'.

[INFO] Lecture de '.env.staging'...

[OK] CRÉÉE DATABASE_URL
[OK] CRÉÉE NEXT_PUBLIC_API_URL
[SKIP] SECRET_KEY (existe déjà — utilisez --overwrite pour écraser)
[OK] MISE À JOUR ANOTHER_VAR

──────────────── Résumé ────────────────
[OK] Créées      : 8
[OK] Mises à jour : 1
[WARN] Ignorées     : 3
────────────────────────────────────────
```

## Common workflows

### Copy vars from one environment to another

```bash
# 1. Pull from production
./vercel-pull-env.sh -p my-project -e production -o .env.production

# 2. Review, then push to staging
./vercel-push-env.sh -p my-project -e staging -f .env.production --dry-run
./vercel-push-env.sh -p my-project -e staging -f .env.production --overwrite
```

### Sync vars across multiple projects

```bash
for project in project-a project-b project-c; do
  ./vercel-push-env.sh -p "$project" -e production -f .env.shared --overwrite
done
```

### Bootstrap a new project from an existing one

```bash
./vercel-pull-env.sh -p existing-project -e production -o .env.base
# Edit .env.base as needed
./vercel-push-env.sh -p new-project -e production -f .env.base
```

### CI/CD automation

```bash
#!/bin/bash
# deploy-env.sh

# Token should be stored in CI/CD secrets
export VERCEL_TOKEN="${CI_VERCEL_TOKEN}"

# Pull production vars
./vercel-pull-env.sh -p my-app -e production -o .env.production

# Add build-specific vars
echo "BUILD_ID=$(git rev-parse HEAD)" >> .env.production
echo "DEPLOY_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> .env.production

# Push to preview environment
./vercel-push-env.sh -p my-app -e preview -f .env.production --overwrite
```

### Backup before updates

```bash
# Backup current vars
./vercel-pull-env.sh -p my-project -e production -o backup-$(date +%Y%m%d).env

# Make changes locally
vim .env.production

# Test with dry-run
./vercel-push-env.sh -p my-project -e production -f .env.production --dry-run

# Apply changes
./vercel-push-env.sh -p my-project -e production -f .env.production --overwrite
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

### "vercel CLI introuvable"
```bash
npm install -g vercel
```

### "Vous n'êtes pas connecté"
```bash
# Option 1: Interactive login
vercel login

# Option 2: Use a token
export VERCEL_TOKEN="your_token"
./vercel-pull-env.sh -p my-project -e production
```

### "Token invalide ou expiré"
Generate a new token at https://vercel.com/account/tokens

### Variables not appearing after push
Wait a few seconds, then verify:
```bash
vercel env ls --project my-project
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
