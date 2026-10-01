# shellcheck shell=bash
# Étapes de l'installateur PC. Aucune logique Ansible interne n'est modifiée.
set -euo pipefail

afficher_intro_pc() {
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
    echo "Prérequis : Fedora, Debian, Ubuntu, Arch Linux ou openSUSE ; bureau GNOME ou KDE Plasma ;"
    echo "application ntfy sur votre téléphone."
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
}

preparer_ansible_pc() {
  titre "1/4 — Vérification d'Ansible"
  assurer_ansible
  installer_collections
}

configurer_webcam_pc() {
  WEBCAM=false
  $RETIRER && return 0
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
  echo "  - Les photos passent par votre serveur ntfy (ntfy.sh par défaut) et restent sur votre serveur (dossier ~/preuves)."
  echo "  - Vous pourrez changer d'avis plus tard en relançant ce script."
  echo
  local rep_cam
  read -r -p "Installer l'option webcam ? [o/N] " rep_cam
  if [[ "$rep_cam" =~ ^[oO]$ ]]; then
    WEBCAM=true
    ok "Option webcam retenue (photo désactivée tant que vous ne tapez pas photo-on)."
  else
    ok "Pas de webcam : rien de lié à la caméra ne sera installé."
  fi
}

assurer_fichier_vault_pass() {
  if [[ ! -f .vault_pass ]]; then
    printf '%s' "$(head -c 24 /dev/urandom | base64)" > .vault_pass
    chmod 600 .vault_pass
  fi
}

preparer_ntfy_pc() {
  local vault_pass ntfy_topic tmpvars
  titre "3/4 — Sujet ntfy"
  PC_EXTRA_ARGS=()
  if $RETIRER; then
    assurer_fichier_vault_pass
    ok "Pas besoin du sujet ntfy pour retirer."
    return 0
  fi
  if [[ -f group_vars/all.yml ]] && head -1 group_vars/all.yml | grep -q ANSIBLE_VAULT; then
    ok "Coffre du serveur trouvé : les alertes utiliseront le même serveur et le même sujet ntfy."
    read -r -s -p "Mot de passe du coffre : " vault_pass; echo
    printf '%s' "$vault_pass" > .vault_pass
    chmod 600 .vault_pass
    ansible-vault view group_vars/all.yml >/dev/null 2>&1 || { erreur "Mot de passe du coffre incorrect."; return 1; }
    return 0
  fi
  attention "Aucun coffre de serveur sur cette machine : saisissez votre serveur et votre sujet ntfy."
  demander_serveur_ntfy
  read -r -p "Sujet ntfy : " ntfy_topic
  [[ -n "$ntfy_topic" ]] || { erreur "Sujet ntfy requis."; return 1; }
  assurer_fichier_vault_pass
  tmpvars=$(mktemp)
  chmod 600 "$tmpvars"
  {
    printf 'ntfy_serveur: %s\n' "$(yaml_quote "$NTFY_SERVEUR")"
    printf 'ntfy_topic: %s\n' "$(yaml_quote "$ntfy_topic")"
  } > "$tmpvars"
  lab_register_temp "$tmpvars"
  PC_EXTRA_ARGS=(-e "@$tmpvars")
}

deployer_pc() {
  titre "4/4 — Déploiement sur ce PC"
  echo "Votre mot de passe sudo sur CE PC va être demandé (BECOME password)."
  $RETIRER && PC_EXTRA_ARGS+=(-e retirer=true)
  PC_EXTRA_ARGS+=(-e "webcam_active=$WEBCAM")
  deployer_pc_ansible "${PC_EXTRA_ARGS[@]}"
}

afficher_fin_pc() {
  echo
  if $RETIRER; then
    ok "Détection d'accès retirée."
  else
    ok "Détection d'accès installée."
    attention "Déconnectez-vous puis reconnectez-vous pour tout activer (groupe input, commandes)."
    echo "Ensuite : tapez  absent  puis verrouillez l'écran (Super+L) pour armer la vigilance."
    $WEBCAM && echo "Webcam : tapez  photo-on  pour autoriser la photo,  photo-off  pour la couper."
  fi
}
