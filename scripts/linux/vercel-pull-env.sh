#!/bin/sh
# =============================================================================
# vercel-pull-env.sh
# Fetch environment variables from a remote Vercel project via the CLI.
#
# Usage:
#   sh scripts/linux/vercel-pull-env.sh [options]
#
# Options:
#   -p, --project <PROJECT>  Project name or ID
#   -e, --env <ENV>          Target environment (production, preview, development)
#   -o, --output <FILE>      Output file (default: .env.pulled)
#   -t, --token <TOKEN>      Vercel auth token (or via $VERCEL_TOKEN)
#   -h, --help               Show this help
#
# Examples:
#   sh scripts/linux/vercel-pull-env.sh -p my-project -e production -o .env.production
#   sh scripts/linux/vercel-pull-env.sh -p my-project -e staging -t "your_token"
#   export VERCEL_TOKEN="your_token"
#   sh scripts/linux/vercel-pull-env.sh -p my-project -e preview
# =============================================================================

set -eu

RED=$(printf '\033[0;31m')
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[1;33m')
CYAN=$(printf '\033[0;36m')
BOLD=$(printf '\033[1m')
RESET=$(printf '\033[0m')

log()   { printf '%s[INFO]%s %s\n'  "$CYAN"   "$RESET" "$*"; }
ok()    { printf '%s[OK]%s %s\n'    "$GREEN"  "$RESET" "$*"; }
warn()  { printf '%s[WARN]%s %s\n'  "$YELLOW" "$RESET" "$*"; }
error() { printf '%s[ERROR]%s %s\n' "$RED"    "$RESET" "$*" >&2; }
die()   { error "$*"; exit 1; }

PROJECT=""
ENVIRONMENT="production"
OUTPUT_FILE=".env.pulled"
VERCEL_TOKEN="${VERCEL_TOKEN:-}"

usage() {
  grep '^#' "$0" | grep -v '#!/' | sed 's/^# \{0,\}//'
  exit 0
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -p|--project) PROJECT="$2"; shift 2 ;;
    -e|--env)     ENVIRONMENT="$2"; shift 2 ;;
    -o|--output)  OUTPUT_FILE="$2"; shift 2 ;;
    -t|--token)   VERCEL_TOKEN="$2"; shift 2 ;;
    -h|--help)    usage ;;
    *) die "Unknown argument: $1. Use -h for help." ;;
  esac
done

[ -z "$PROJECT" ] && die "Missing project. Use -p <project-name>."

command -v vercel >/dev/null 2>&1 || die "'vercel' CLI not found. Install it: npm i -g vercel"

run_vercel() {
  if [ -n "$VERCEL_TOKEN" ]; then
    vercel "$@" --token "$VERCEL_TOKEN"
  else
    vercel "$@"
  fi
}

if [ -n "$VERCEL_TOKEN" ]; then
  run_vercel whoami >/dev/null 2>&1 || die "Invalid or expired token."
else
  run_vercel whoami >/dev/null 2>&1 || die "Not logged in. Use --token or: vercel login"
fi

log "Fetching variables for project '${PROJECT}' (env: ${ENVIRONMENT})..."

TMP_FILE=$(mktemp /tmp/vercel_env_pull_XXXXXX)
TMP_OUT=$(mktemp /tmp/vercel_env_out_XXXXXX)
trap 'rm -f "$TMP_FILE" "$TMP_OUT"' EXIT

if run_vercel env pull "$TMP_FILE" \
     --project "$PROJECT" \
     --environment "$ENVIRONMENT" \
     --yes > "$TMP_OUT" 2>&1; then
  grep -v '^Vercel CLI' "$TMP_OUT" || true
else
  grep -v '^Vercel CLI' "$TMP_OUT" || true
  die "Failed 'vercel env pull'. Check project name and environment."
fi

if [ ! -s "$TMP_FILE" ]; then
  warn "No variables returned for environment '${ENVIRONMENT}'."
  exit 0
fi

{
  echo "# ============================================================"
  echo "# Vercel env vars — project: ${PROJECT}"
  echo "# Environment: ${ENVIRONMENT}"
  echo "# Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "# ============================================================"
  echo ""
  grep -v '^# Created by Vercel CLI' "$TMP_FILE" || true
} > "$OUTPUT_FILE"

COUNT=$(grep -c '^[^#[:space:]]' "$OUTPUT_FILE" || true)
ok "${COUNT} variable(s) written to ${BOLD}${OUTPUT_FILE}${RESET}"

echo ""
printf '%sPreview (values masked):%s\n' "$BOLD" "$RESET"
while IFS='=' read -r key rest; do
  case "$key" in
    ''|'#'*) continue ;;
  esac
  printf '  %-40s = %s\n' "$key" "***"
done < "$OUTPUT_FILE"
