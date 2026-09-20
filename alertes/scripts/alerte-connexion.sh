#!/bin/sh
# Appelé par PAM à chaque ouverture de session SSH
[ "$PAM_TYPE" = "open_session" ] || exit 0
. /etc/lab-alertes.conf
curl -s -m 5 -H "Title: Connexion SSH sur $(hostname)" -H "Tags: key" -H "Priority: high" \
  -d "Utilisateur : $PAM_USER
Depuis : $PAM_RHOST
Quand : $(date '+%d/%m/%Y %H:%M')" \
  "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1 &
exit 0
