#!/usr/bin/env bash
#
# install-pc.sh — Installe la détection d'accès physique sur CE poste de travail.
#
# À lancer sur le PC à protéger (Fedora, Debian ou Ubuntu, bureau GNOME),
# avec votre compte habituel. Pour tout retirer : ./install-pc.sh --retirer
#
set -euo pipefail

BLEU="\033[1;34m"; VERT="\033[1;32m"; ROUGE="\033[1;31m"; JAUNE="\033[1;33m"; RAZ="\033[0m"
titre()    { echo -e "\n${BLEU}==> $1${RAZ}"; }
ok()       { echo -e "${VERT}✔ $1${RAZ}"; }
attention(){ echo -e "${JAUNE}⚠ $1${RAZ}"; }
erreur()   { echo -e "${ROUGE}✘ $1${RAZ}" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/ansible" || { erreur "Dossier ansible/ introuvable."; exit 1; }

[[ $EUID -eq 0 ]] && { erreur "Ne lancez pas ce script en root : lancez-le avec votre compte habituel."; exit 1; }

RETIRER=false
[[ "${1:-}" == "--retirer" ]] && RETIRER=true

echo -e "${BLEU}"
echo "  ┌────────────────────────────────────────────┐"
echo "  │   Détection d'accès au poste de travail      │"
echo "  └────────────────────────────────────────────┘"
echo -e "${RAZ}"
if $RETIRER; then
  echo "Ce script va RETIRER la détection d'accès de ce PC."
else
  echo "Ce script installe, sur CE PC, la détection d'accès physique :"
  echo "alerte au déverrouillage, alerte USB, mode vigilance, photo webcam (désactivée par défaut)."
  echo "Prérequis : Fedora, Debian ou Ubuntu, bureau GNOME, application ntfy sur votre téléphone."
fi
echo
read -r -p "Continuer ? [o/N] " reponse
[[ "$reponse" =~ ^[oO]$ ]] || { echo "Annulé."; exit 0; }

# --- 1. Ansible ------------------------------------------------------------
titre "1/3 — Vérification d'Ansible"
if command -v ansible-playbook >/dev/null 2>&1; then
  ok "Ansible est installé."
else
  if   command -v dnf >/dev/null 2>&1; then INSTALL="sudo dnf install -y ansible"
  elif command -v apt >/dev/null 2>&1; then INSTALL="sudo apt update && sudo apt install -y ansible"
  else erreur "Installez Ansible manuellement, puis relancez."; exit 1; fi
  read -r -p "Ansible n'est pas installé. L'installer ($INSTALL) ? [o/N] " rep
  [[ "$rep" =~ ^[oO]$ ]] || { erreur "Ansible est requis. Arrêt."; exit 1; }
  eval "$INSTALL"
  ok "Ansible installé."
fi

# --- 2. Sujet ntfy ---------------------------------------------------------
# ansible.cfg déclare .vault_pass : il doit TOUJOURS exister, sinon toute
# commande Ansible échoue (leçon du premier déploiement).
titre "2/3 — Sujet ntfy"
EXTRA=()
TMPVARS=""
if $RETIRER; then
  [[ -f .vault_pass ]] || { printf '%s' "$(head -c 24 /dev/urandom | base64)" > .vault_pass; chmod 600 .vault_pass; }
  ok "Pas besoin du sujet ntfy pour retirer."
elif [[ -f group_vars/all.yml ]] && head -1 group_vars/all.yml | grep -q ANSIBLE_VAULT; then
  ok "Coffre du serveur trouvé : les alertes utiliseront le même sujet ntfy."
  read -r -s -p "Mot de passe du coffre : " VAULT_PASS; echo
  printf '%s' "$VAULT_PASS" > .vault_pass
  chmod 600 .vault_pass
  ansible-vault view group_vars/all.yml >/dev/null 2>&1 || { erreur "Mot de passe du coffre incorrect."; exit 1; }
else
  attention "Aucun coffre de serveur sur cette machine : saisissez votre sujet ntfy."
  read -r -p "Sujet ntfy : " NTFY_TOPIC
  [[ -n "$NTFY_TOPIC" ]] || { erreur "Sujet ntfy requis."; exit 1; }
  [[ -f .vault_pass ]] || { printf '%s' "$(head -c 24 /dev/urandom | base64)" > .vault_pass; chmod 600 .vault_pass; }
  TMPVARS=$(mktemp)
  chmod 600 "$TMPVARS"
  printf 'ntfy_topic: "%s"\n' "$NTFY_TOPIC" > "$TMPVARS"
  trap 'rm -f "$TMPVARS"' EXIT
  EXTRA=(-e "@$TMPVARS")
fi

# --- 3. Déploiement --------------------------------------------------------
titre "3/3 — Déploiement sur ce PC"
echo "Votre mot de passe sudo sur CE PC va être demandé (BECOME password)."
$RETIRER && EXTRA+=(-e retirer=true)
ansible-playbook pc.yml --ask-become-pass "${EXTRA[@]}"

echo
if $RETIRER; then
  ok "Détection d'accès retirée."
else
  ok "Détection d'accès installée."
  attention "Déconnectez-vous puis reconnectez-vous pour tout activer (groupe input, commandes)."
  echo "Ensuite : tapez  absent  puis verrouillez l'écran (Super+L) pour armer la vigilance."
fi
