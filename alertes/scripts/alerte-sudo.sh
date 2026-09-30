#!/bin/sh
# Appelé par PAM à chaque utilisation de sudo
[ "$PAM_TYPE" = "open_session" ] || exit 0
# Fichier généré par Ansible (modèle : alertes/lab-alertes.conf.example).
# shellcheck source=/dev/null
. /etc/lab-alertes.conf
DERNIER=/var/lib/lab-alertes/dernier-sudo
mkdir -p /var/lib/lab-alertes
[ -f "$DERNIER" ] && [ $(( $(date +%s) - $(cat "$DERNIER") )) -lt 600 ] && exit 0
date +%s > "$DERNIER"
curl -s -m 5 -H "Title: sudo utilisé sur $(uname -n)" -H "Tags: warning" -H "Priority: high" \
  -d "Utilisateur : $PAM_RUSER devient $PAM_USER
Quand : $(date '+%d/%m/%Y %H:%M')" \
  "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1 &
exit 0
