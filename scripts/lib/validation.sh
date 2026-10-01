# shellcheck shell=bash
# Validation des entrées utilisateur et helpers de sérialisation.
set -euo pipefail

# Chaîne YAML entre apostrophes : dans ce style, seule l'apostrophe est doublée.
yaml_quote() {
  local v=${1//\'/\'\'}
  printf "'%s'" "$v"
}

confirmer_continuation() {
  local reponse
  read -r -p "Continuer ? [o/N] " reponse
  if [[ ! "$reponse" =~ ^[oO]$ ]]; then
    echo "Annulé."
    exit 0
  fi
}

exiger_utilisateur_non_root() {
  if [[ $EUID -eq 0 ]]; then
    erreur "Ne lancez pas ce script en root : lancez-le avec votre compte habituel."
    return 1
  fi
}

pc_mode_depuis_args() {
  RETIRER=false
  [[ "${1:-}" == "--retirer" ]] && RETIRER=true
}

# Demande l'adresse du serveur ntfy et l'écrit dans NTFY_SERVEUR, sans « / » final.
demander_serveur_ntfy() {
  local reponse
  while true; do
    read -r -p "Serveur ntfy [https://ntfy.sh, ou le vôtre ex: https://ntfy.mondomaine.fr] : " reponse
    reponse="${reponse:-https://ntfy.sh}"
    while [[ "$reponse" == */ ]]; do reponse="${reponse%/}"; done
    if [[ "$reponse" =~ ^https?://[^/[:space:]]+(/[^[:space:]]*)?$ ]]; then
      NTFY_SERVEUR="$reponse"
      return 0
    fi
    attention "Adresse invalide : elle doit commencer par https:// (ou http://)."
  done
}
