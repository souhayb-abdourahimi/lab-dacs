#!/bin/bash
# Alerte au deverrouillage + desarme le mode vigilance (anti-boucle)
TOPIC=$(sudo grep -oP '(?<=NTFY_TOPIC=).*' /etc/lab-alertes.conf 2>/dev/null)
[ -z "$TOPIC" ] && exit 0
DRAPEAU="$HOME/.local/state/mode-vigilance"
DERNIER=0

dbus-monitor --session "type='signal',interface='org.gnome.ScreenSaver'" 2>/dev/null |
while read -r ligne; do
  echo "$ligne" | grep -q "boolean false" || continue
  MAINTENANT=$(date +%s)
  [ $((MAINTENANT - DERNIER)) -lt 3 ] && continue
  DERNIER=$MAINTENANT
  # Deverrouillage = c'est moi qui reviens : on desarme la vigilance
  rm -f "$DRAPEAU"
  curl -s -m 5 -H "Title: PC deverrouille" -H "Tags: unlock" -H "Priority: high" \
    -d "Session ouverte, vigilance desarmee
Quand : $(date '+%d/%m/%Y %H:%M:%S')" "https://ntfy.sh/$TOPIC" >/dev/null 2>&1
done
