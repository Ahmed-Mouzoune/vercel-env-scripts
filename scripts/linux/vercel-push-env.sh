#!/bin/sh
# =============================================================================
# vercel-push-env.sh
# Push environment variables from a local file to a Vercel project via the CLI.
#
# Usage:
#   sh scripts/linux/vercel-push-env.sh [options]
#
# Options:
#   -p, --project <PROJECT>  Project name or ID
#   -e, --env <ENV>          Target environment (production, preview, development)
#   -f, --file <FILE>        Source file (default: .env)
#   -t, --token <TOKEN>      Vercel auth token (or via $VERCEL_TOKEN)
#   --dry-run                Simulate without pushing anything
#   --overwrite              Overwrite existing variables (default: skip)
#   -h, --help               Show this help
#
# Source file format:
#   KEY=value       normal variable
#   # comment       ignored
#   MY_KEY="value"  quotes stripped automatically
#
# Examples:
#   sh scripts/linux/vercel-push-env.sh -p my-project -e production -f .env.production
#   sh scripts/linux/vercel-push-env.sh -p my-project -e staging --overwrite -t "your_token"
#   export VERCEL_TOKEN="your_token"
#   sh scripts/linux/vercel-push-env.sh -p my-project -e preview -f .env --dry-run
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
skip()  { printf '%s[SKIP]%s %s\n'  "$YELLOW" "$RESET" "$*"; }
dry()   { printf '  %s[DRY]%s %s\n' "$YELLOW" "$RESET" "$*"; }
error() { printf '%s[ERROR]%s %s\n' "$RED"    "$RESET" "$*" >&2; }
die()   { error "$*"; exit 1; }

PROJECT=""
ENVIRONMENT="production"
SOURCE_FILE=".env"
VERCEL_TOKEN="${VERCEL_TOKEN:-}"
DRY_RUN=false
OVERWRITE=false
COUNT_PUSHED=0
COUNT_SKIPPED=0
COUNT_UPDATED=0
COUNT_ERRORS=0

usage() {
  grep '^#' "$0" | grep -v '#!/' | sed 's/^# \{0,\}//'
  exit 0
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -p|--project)  PROJECT="$2"; shift 2 ;;
    -e|--env)      ENVIRONMENT="$2"; shift 2 ;;
    -f|--file)     SOURCE_FILE="$2"; shift 2 ;;
    -t|--token)    VERCEL_TOKEN="$2"; shift 2 ;;
    --dry-run)     DRY_RUN=true; shift ;;
    --overwrite)   OVERWRITE=true; shift ;;
    -h|--help)     usage ;;
    *) die "Unknown argument: $1. Use -h for help." ;;
  esac
done

[ -z "$PROJECT" ]       && die "Missing project. Use -p <project-name>."
[ ! -f "$SOURCE_FILE" ] && die "Source file not found: '${SOURCE_FILE}'"

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

printf '\n%s╔══════════════════════════════════════════╗%s\n' "$BOLD" "$RESET"
printf '%s║  Vercel Push Env — %s        ║%s\n' "$BOLD" "$(date '+%H:%M:%S')" "$RESET"
printf '%s╚══════════════════════════════════════════╝%s\n\n' "$BOLD" "$RESET"

[ "$DRY_RUN"   = "true" ] && warn "DRY-RUN mode — no changes will be made"
[ "$OVERWRITE" = "true" ] && warn "OVERWRITE mode — existing variables will be replaced"
echo ""

log "Fetching existing vars on '${ENVIRONMENT}'..."

EXISTING_VARS=$(run_vercel env ls --project "$PROJECT" 2>/dev/null | \
  awk -v env="$ENVIRONMENT" '$0 ~ env {print $1}' || true)

is_existing() {
  printf '%s\n' "$EXISTING_VARS" | grep -qx "$1"
}

EXISTING_COUNT=$(printf '%s\n' "$EXISTING_VARS" | grep -c '[^[:space:]]' || true)
log "${EXISTING_COUNT} variable(s) already present for '${ENVIRONMENT}'."
echo ""

log "Reading '${SOURCE_FILE}'..."
echo ""

LINE_NUM=0
while IFS= read -r line || [ -n "$line" ]; do
  LINE_NUM=$((LINE_NUM + 1))

  # Strip leading whitespace and skip empty lines / comments
  TRIMMED=$(printf '%s' "$line" | sed 's/^[[:space:]]*//')
  case "$TRIMMED" in
    ''|'#'*) continue ;;
  esac

  # Validate KEY=VALUE format
  if ! printf '%s\n' "$TRIMMED" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*='; then
    warn "Line ${LINE_NUM} ignored (invalid format): ${line}"
    continue
  fi

  # Extract key (before first '=') and value (after first '=')
  KEY=$(printf '%s\n' "$TRIMMED" | sed 's/=.*//')
  VALUE=$(printf '%s\n' "$TRIMMED" | sed 's/^[^=]*=//')

  # Strip surrounding double or single quotes from value
  case "$VALUE" in
    '"'*'"') VALUE=$(printf '%s' "$VALUE" | sed 's/^"//;s/"$//') ;;
    "'"*"'") VALUE=$(printf '%s' "$VALUE" | sed "s/^'//;s/'$//") ;;
  esac

  # DRY-RUN mode
  if [ "$DRY_RUN" = "true" ]; then
    if is_existing "$KEY"; then
      [ "$OVERWRITE" = "true" ] \
        && dry "WOULD UPDATE ${KEY}" \
        || dry "WOULD SKIP ${KEY} (already exists, --overwrite not set)"
    else
      dry "WOULD CREATE ${KEY}"
    fi
    continue
  fi

  # Existing variable
  if is_existing "$KEY"; then
    if [ "$OVERWRITE" = "true" ]; then
      run_vercel env rm "$KEY" "$ENVIRONMENT" --project "$PROJECT" --yes >/dev/null 2>&1 || true
      if printf '%s\n' "$VALUE" | run_vercel env add "$KEY" "$ENVIRONMENT" \
           --project "$PROJECT" --sensitive >/dev/null 2>&1; then
        ok "UPDATED ${BOLD}${KEY}${RESET}"
        COUNT_UPDATED=$((COUNT_UPDATED + 1))
      else
        error "FAILED to update ${KEY}"
        COUNT_ERRORS=$((COUNT_ERRORS + 1))
      fi
    else
      skip "${KEY} (already exists — use --overwrite to replace)"
      COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
    fi
    continue
  fi

  # New variable — value is read from stdin to avoid leaking it in process lists
  if printf '%s\n' "$VALUE" | run_vercel env add "$KEY" "$ENVIRONMENT" \
       --project "$PROJECT" >/dev/null 2>&1; then
    ok "CREATED ${BOLD}${KEY}${RESET}"
    COUNT_PUSHED=$((COUNT_PUSHED + 1))
  else
    error "FAILED to create ${KEY}"
    COUNT_ERRORS=$((COUNT_ERRORS + 1))
  fi
done < "$SOURCE_FILE"

echo ""
printf '%s──────────────── Summary ────────────────%s\n' "$BOLD" "$RESET"
if [ "$DRY_RUN" = "true" ]; then
  warn "Simulation complete. No variables were modified."
else
  ok "Created  : ${COUNT_PUSHED}"
  [ "$COUNT_UPDATED" -gt 0 ] && ok   "Updated  : ${COUNT_UPDATED}"
  [ "$COUNT_SKIPPED" -gt 0 ] && warn  "Skipped  : ${COUNT_SKIPPED}"
  [ "$COUNT_ERRORS"  -gt 0 ] && error "Errors   : ${COUNT_ERRORS}"
fi
printf '%s─────────────────────────────────────────%s\n\n' "$BOLD" "$RESET"

[ "$COUNT_ERRORS" -gt 0 ] && exit 1
exit 0
