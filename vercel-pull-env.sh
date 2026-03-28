#!/usr/bin/env bash
# =============================================================================
# vercel-pull-env.sh
# Fetch les variables d'environnement d'un projet Vercel distant via le CLI.
#
# Usage:
# ./vercel-pull-env.sh [options]
#
# Options:
# -p, --project <PROJECT>  Nom ou ID du projet Vercel
# -e, --env <ENV>          Environnement cible (ex: production, preview, development, staging)
# -o, --output <FILE>      Fichier de sortie (défaut: .env.pulled)
# -t, --token <TOKEN>      Token d'authentification Vercel (ou via $VERCEL_TOKEN)
# -h, --help               Affiche cette aide
#
# Exemples:
# ./vercel-pull-env.sh -p my-project -e production -o .env.production
# ./vercel-pull-env.sh -p my-project -e staging -o .env.staging -t "your_token"
# export VERCEL_TOKEN="your_token"
# ./vercel-pull-env.sh -p my-project -e preview
# =============================================================================

set -euo pipefail

# ── Couleurs ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log() { echo -e "${CYAN}[INFO]${RESET} $*"; }
ok() { echo -e "${GREEN}[OK]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
die() { error "$*"; exit 1; }

# ── Valeurs par défaut ────────────────────────────────────────────────────────
PROJECT=""
ENVIRONMENT="production"
OUTPUT_FILE=".env.pulled"
VERCEL_TOKEN="${VERCEL_TOKEN:-}"

# ── Parsing des arguments ─────────────────────────────────────────────────────
usage() {
  grep '^#' "$0" | grep -v '#!/' | sed 's/^# \{0,\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project) PROJECT="$2"; shift 2 ;;
    -e|--env)     ENVIRONMENT="$2"; shift 2 ;;
    -o|--output)  OUTPUT_FILE="$2"; shift 2 ;;
    -t|--token)   VERCEL_TOKEN="$2"; shift 2 ;;
    -h|--help)    usage ;;
    *) die "Argument inconnu : $1. Utilisez -h pour l'aide." ;;
  esac
done

# ── Vérifications ─────────────────────────────────────────────────────────────
[[ -z "$PROJECT" ]] && die "Projet manquant. Utilisez -p <project-name>."

command -v vercel &>/dev/null || die "'vercel' CLI introuvable. Installez-le : npm i -g vercel"

# Vérification auth avec token si fourni
if [[ -n "$VERCEL_TOKEN" ]]; then
  vercel whoami --token "$VERCEL_TOKEN" &>/dev/null || die "Token invalide ou expiré."
else
  vercel whoami &>/dev/null || die "Vous n'êtes pas connecté. Utilisez --token ou : vercel login"
fi

# ── Fetch des variables ───────────────────────────────────────────────────────
log "Récupération des variables du projet '${PROJECT}' (env: ${ENVIRONMENT})..."

TMP_FILE=$(mktemp /tmp/vercel_env_pull_XXXXXX)
trap 'rm -f "$TMP_FILE"' EXIT

# Construction de la commande avec token optionnel
VERCEL_CMD=(vercel env pull "$TMP_FILE"
  --project "$PROJECT"
  --environment "$ENVIRONMENT"
  --yes)

[[ -n "$VERCEL_TOKEN" ]] && VERCEL_CMD+=(--token "$VERCEL_TOKEN")

if ! "${VERCEL_CMD[@]}" 2>&1 | grep -v '^Vercel CLI'; then
  die "Échec de 'vercel env pull'. Vérifiez le nom du projet et de l'environnement."
fi

if [[ ! -s "$TMP_FILE" ]]; then
  warn "Aucune variable retournée pour l'environnement '${ENVIRONMENT}'."
  exit 0
fi

# ── Écriture avec en-tête propre ──────────────────────────────────────────────
{
  echo "# ============================================================"
  echo "# Vercel env vars — projet : ${PROJECT}"
  echo "# Environnement : ${ENVIRONMENT}"
  echo "# Généré le : $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "# ============================================================"
  echo ""
  grep -v '^# Created by Vercel CLI' "$TMP_FILE" || true
} > "$OUTPUT_FILE"

COUNT=$(grep -c '^[^#[:space:]]' "$OUTPUT_FILE" || true)
ok "${COUNT} variable(s) écrite(s) dans ${BOLD}${OUTPUT_FILE}${RESET}"

# ── Aperçu (clés uniquement, valeurs masquées) ────────────────────────────────
echo ""
echo -e "${BOLD}Aperçu (valeurs masquées) :${RESET}"
while IFS='=' read -r key _; do
  [[ -z "$key" || "$key" =~ ^# ]] && continue
  printf "  %-40s = %s\n" "$key" "***"
done < "$OUTPUT_FILE"
