# shellcheck shell=bash
# Sécurité d'exécution et nettoyage commun aux installateurs.
set -Eeuo pipefail

LAB_TEMP_FILES=()

lab_register_temp() {
  LAB_TEMP_FILES+=("$1")
}

lab_cleanup() {
  local fichier
  for fichier in "${LAB_TEMP_FILES[@]}"; do
    [[ -n "$fichier" ]] && rm -f -- "$fichier"
  done
}

lab_on_error() {
  local statut=$1 ligne=$2 commande=$3
  printf '\033[1;31m✘ Erreur inattendue (code %s) ligne %s : %s\033[0m\n' \
    "$statut" "$ligne" "$commande" >&2
}

lab_on_signal() {
  local signal=$1 code=130
  [[ "$signal" == TERM ]] && code=143
  printf '\n\033[1;33m⚠ Exécution interrompue (%s). Nettoyage en cours.\033[0m\n' "$signal" >&2
  exit "$code"
}

trap 'lab_on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR
trap 'lab_on_signal INT' INT
trap 'lab_on_signal TERM' TERM
trap lab_cleanup EXIT
