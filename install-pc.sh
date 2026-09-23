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
  echo "alerte au déverrouillage, alerte USB et mode vigilance."
  echo "Une option webcam, facultative, vous sera proposée à part."
  echo "Prérequis : Fedora, Debian ou Ubuntu, bureau GNOME, application ntfy sur votre téléphone."
  echo
  attention "À savoir avant d'installer :"
  echo "  - Pour détecter une présence, le module lit les événements du clavier et de la souris"
  echo "    (il sait qu'une touche est pressée, il n'enregistre JAMAIS ce qui est tapé)."
  echo "    Votre compte sera ajouté au groupe « input » pour cela."
  echo "  - En mode vigilance, toute activité verrouille l'écran automatiquement :"
  echo "    gardez votre mot de passe de session en tête."
  echo "  - Chaque déverrouillage et chaque clé USB branchée envoient une notification."
  echo "  - Une déconnexion puis reconnexion sera nécessaire à la fin."
  echo "  - N'installez ce module que sur un ordinateur qui vous appartient."
fi
echo
read -r -p "Continuer ? [o/N] " reponse
[[ "$reponse" =~ ^[oO]$ ]] || { echo "Annulé."; exit 0; }

# --- 1. Ansible ------------------------------------------------------------
titre "1/4 — Vérification d'Ansible"
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

# --- 2. Option webcam (facultative, refusée par défaut) --------------------
WEBCAM=false
if ! $RETIRER; then
  titre "2/4 — Option webcam (facultative)"
  echo "En bonus, le module peut photographier la personne devant le PC lors d'une intrusion,"
  echo "envoyer la photo sur votre téléphone et en garder une copie sur votre serveur."
  echo
  attention "Avant d'accepter :"
  echo "  - Filmer une personne est encadré par la loi. Chez vous, sur votre propre ordinateur,"
  echo "    c'est votre droit. Sur un ordinateur de travail, d'école ou partagé, c'est INTERDIT"
  echo "    sans information préalable des personnes (RGPD, CNIL). Dans le doute, refusez."
  echo "  - Même installée, la photo reste DÉSACTIVÉE : il faudra taper photo-on pour l'autoriser."
  echo "  - Une notification « Caméra activée » est envoyée à chaque photo : jamais de capture cachée."
  echo "  - Les photos passent par le service ntfy.sh et restent sur votre serveur (dossier ~/preuves)."
  echo "  - Vous pourrez changer d'avis plus tard en relançant ce script."
  echo
  read -r -p "Installer l'option webcam ? [o/N] " rep_cam
  if [[ "$rep_cam" =~ ^[oO]$ ]]; then
    WEBCAM=true
    ok "Option webcam retenue (photo désactivée tant que vous ne tapez pas photo-on)."
  else
    ok "Pas de webcam : rien de lié à la caméra ne sera installé."
  fi
fi

# --- 3. Sujet ntfy ---------------------------------------------------------
# ansible.cfg déclare .vault_pass : il doit TOUJOURS exister, sinon toute
# commande Ansible échoue (leçon du premier déploiement).
titre "3/4 — Sujet ntfy"
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

# --- 4. Déploiement --------------------------------------------------------
titre "4/4 — Déploiement sur ce PC"
echo "Votre mot de passe sudo sur CE PC va être demandé (BECOME password)."
$RETIRER && EXTRA+=(-e retirer=true)
EXTRA+=(-e "webcam_active=$WEBCAM")
ansible-playbook pc.yml --ask-become-pass "${EXTRA[@]}"

echo
if $RETIRER; then
  ok "Détection d'accès retirée."
else
  ok "Détection d'accès installée."
  attention "Déconnectez-vous puis reconnectez-vous pour tout activer (groupe input, commandes)."
  echo "Ensuite : tapez  absent  puis verrouillez l'écran (Super+L) pour armer la vigilance."
  $WEBCAM && echo "Webcam : tapez  photo-on  pour autoriser la photo,  photo-off  pour la couper."
fi
