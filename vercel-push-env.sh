#!/usr/bin/env bash
# =============================================================================
# vercel-push-env.sh
# Pousse les variables d'un fichier local vers un projet Vercel via le CLI.
#
# Usage:
# ./vercel-push-env.sh [options]
#
# Options:
# -p, --project <PROJECT>  Nom ou ID du projet Vercel
# -e, --env <ENV>          Environnement cible (ex: production, preview, development, staging)
# -f, --file <FILE>        Fichier source (défaut: .env)
# -t, --token <TOKEN>      Token d'authentification Vercel (ou via $VERCEL_TOKEN)
# --dry-run                Simule sans rien pousser
# --overwrite              Écrase les vars existantes (défaut: skip)
# -h, --help               Affiche cette aide
#
# Format du fichier source :
# KEY=valeur      → variable normale
# # commentaire   → ignoré
# MY_KEY="valeur" → guillemets supprimés automatiquement
#
# Exemples:
# ./vercel-push-env.sh -p my-project -e production -f .env.production
# ./vercel-push-env.sh -p my-project -e staging -f .env.staging --overwrite -t "your_token"
# export VERCEL_TOKEN="your_token"
# ./vercel-push-env.sh -p my-project -e preview -f .env --dry-run
# =============================================================================

set -euo pipefail

# ── Couleurs ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log() { echo -e "${CYAN}[INFO]${RESET} $*"; }
ok() { echo -e "${GREEN}[OK]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
skip() { echo -e "${YELLOW}[SKIP]${RESET} $*"; }
error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
dry() { echo -e "  ${YELLOW}[DRY]${RESET} $*"; }
die() { error "$*"; exit 1; }

# ── Valeurs par défaut ────────────────────────────────────────────────────────
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

# ── Parsing des arguments ─────────────────────────────────────────────────────
usage() {
  grep '^#' "$0" | grep -v '#!/' | sed 's/^# \{0,\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project)  PROJECT="$2"; shift 2 ;;
    -e|--env)      ENVIRONMENT="$2"; shift 2 ;;
    -f|--file)     SOURCE_FILE="$2"; shift 2 ;;
    -t|--token)    VERCEL_TOKEN="$2"; shift 2 ;;
    --dry-run)     DRY_RUN=true; shift ;;
    --overwrite)   OVERWRITE=true; shift ;;
    -h|--help)     usage ;;
    *) die "Argument inconnu : $1. Utilisez -h pour l'aide." ;;
  esac
done

# ── Vérifications ─────────────────────────────────────────────────────────────
[[ -z "$PROJECT" ]] && die "Projet manquant. Utilisez -p <project-name>."
[[ ! -f "$SOURCE_FILE" ]] && die "Fichier source introuvable : '${SOURCE_FILE}'"

command -v vercel &>/dev/null || die "'vercel' CLI introuvable. Installez-le : npm i -g vercel"

# Vérification auth avec token si fourni
if [[ -n "$VERCEL_TOKEN" ]]; then
  vercel whoami --token "$VERCEL_TOKEN" &>/dev/null || die "Token invalide ou expiré."
else
  vercel whoami &>/dev/null || die "Vous n'êtes pas connecté. Utilisez --token ou : vercel login"
fi

# Options communes pour toutes les commandes vercel
VERCEL_OPTS=(--project "$PROJECT")
[[ -n "$VERCEL_TOKEN" ]] && VERCEL_OPTS+=(--token "$VERCEL_TOKEN")

# ── En-tête ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║  Vercel Push Env — $(date '+%H:%M:%S')        ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET}"
echo ""

[[ "$DRY_RUN" == "true" ]] && warn "Mode DRY-RUN activé — aucune modification ne sera faite"
[[ "$OVERWRITE" == "true" ]] && warn "Mode OVERWRITE activé — les vars existantes seront écrasées"
echo ""

# ── Récupération des vars existantes via CLI ──────────────────────────────────
log "Récupération des vars existantes sur '${ENVIRONMENT}'..."

# 'vercel env ls' liste les vars avec leur environnement sous forme tabulaire
EXISTING_VARS=$(vercel env ls "${VERCEL_OPTS[@]}" 2>/dev/null | \
  awk -v env="$ENVIRONMENT" '$0 ~ env {print $1}' || true)

declare -A EXISTING_SET
while IFS= read -r varname; do
  [[ -n "$varname" ]] && EXISTING_SET["$varname"]=1
done <<< "$EXISTING_VARS"

log "${#EXISTING_SET[@]} variable(s) déjà présente(s) pour '${ENVIRONMENT}'."
echo ""

# ── Traitement du fichier source ──────────────────────────────────────────────
log "Lecture de '${SOURCE_FILE}'..."
echo ""

LINE_NUM=0
while IFS= read -r line || [[ -n "$line" ]]; do
  LINE_NUM=$((LINE_NUM + 1))

  # Ignorer lignes vides et commentaires
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

  # Vérifier le format KEY=VALUE
  if [[ ! "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    warn "Ligne ${LINE_NUM} ignorée (format invalide) : ${line}"
    continue
  fi

  KEY="${BASH_REMATCH[1]}"
  VALUE="${BASH_REMATCH[2]}"

  # Supprimer guillemets entourant la valeur
  if [[ "$VALUE" =~ ^\"(.*)\"$ ]] || [[ "$VALUE" =~ ^\'(.*)\'$ ]]; then
    VALUE="${BASH_REMATCH[1]}"
  fi

  # ── Mode DRY-RUN ──────────────────────────────────────────────────────────
  if [[ "$DRY_RUN" == "true" ]]; then
    if [[ -n "${EXISTING_SET[$KEY]+_}" ]]; then
      [[ "$OVERWRITE" == "true" ]] \
        && dry "METTRAIT À JOUR ${KEY}" \
        || dry "SKIPPERAIT ${KEY} (existe déjà, --overwrite non activé)"
    else
      dry "CRÉERAIT ${KEY}"
    fi
    continue
  fi

  # ── Var existante ──────────────────────────────────────────────────────────
  if [[ -n "${EXISTING_SET[$KEY]+_}" ]]; then
    if [[ "$OVERWRITE" == "true" ]]; then
      # Supprimer d'abord, puis recréer (vercel env rm + add)
      vercel env rm "$KEY" "$ENVIRONMENT" "${VERCEL_OPTS[@]}" --yes &>/dev/null || true
      if echo "$VALUE" | vercel env add "$KEY" "$ENVIRONMENT" \
        "${VERCEL_OPTS[@]}" --sensitive &>/dev/null 2>&1; then
        ok "MISE À JOUR ${BOLD}${KEY}${RESET}"
        COUNT_UPDATED=$((COUNT_UPDATED + 1))
      else
        error "ÉCHEC mise à jour de ${KEY}"
        COUNT_ERRORS=$((COUNT_ERRORS + 1))
      fi
    else
      skip "${KEY} (existe déjà — utilisez --overwrite pour écraser)"
      COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
    fi
    continue
  fi

  # ── Nouvelle var ───────────────────────────────────────────────────────────
  # 'vercel env add' lit la valeur sur stdin pour éviter qu'elle apparaisse
  # dans l'historique shell ou les logs process
  if echo "$VALUE" | vercel env add "$KEY" "$ENVIRONMENT" \
    "${VERCEL_OPTS[@]}" &>/dev/null 2>&1; then
    ok "CRÉÉE ${BOLD}${KEY}${RESET}"
    COUNT_PUSHED=$((COUNT_PUSHED + 1))
  else
    error "ÉCHEC création de ${KEY}"
    COUNT_ERRORS=$((COUNT_ERRORS + 1))
  fi
done < "$SOURCE_FILE"

# ── Résumé ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}──────────────── Résumé ────────────────${RESET}"
if [[ "$DRY_RUN" == "true" ]]; then
  warn "Simulation terminée. Aucune variable modifiée."
else
  ok "Créées      : ${COUNT_PUSHED}"
  [[ "$COUNT_UPDATED" -gt 0 ]] && ok "Mises à jour : ${COUNT_UPDATED}"
  [[ "$COUNT_SKIPPED" -gt 0 ]] && warn "Ignorées     : ${COUNT_SKIPPED}"
  [[ "$COUNT_ERRORS" -gt 0 ]] && error "Erreurs      : ${COUNT_ERRORS}"
fi
echo -e "${BOLD}────────────────────────────────────────${RESET}"
echo ""

[[ "$COUNT_ERRORS" -gt 0 ]] && exit 1
exit 0
