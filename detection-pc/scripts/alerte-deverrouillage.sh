#!/bin/bash
# Verrouillage : arme la vigilance si elle etait en attente
# Deverrouillage : alerte + desarme la vigilance
TOPIC=$(sudo grep -oP '(?<=NTFY_TOPIC=).*' /etc/lab-alertes.conf 2>/dev/null)
[ -z "$TOPIC" ] && exit 0
ATTENTE="$HOME/.local/state/vigilance-en-attente"
ARME="$HOME/.local/state/mode-vigilance"
DERNIER=0

dbus-monitor --session "type='signal',interface='org.gnome.ScreenSaver'" 2>/dev/null |
while read -r ligne; do
  MAINTENANT=$(date +%s)

  if echo "$ligne" | grep -q "boolean true"; then
    # ecran VERROUILLE
    if [ -f "$ATTENTE" ]; then
      rm -f "$ATTENTE"; touch "$ARME"
      curl -s -m 5 -H "Title: Vigilance armee" -H "Tags: shield" \
        -d "Surveillance active (ecran verrouille)
Quand : $(date '+%d/%m/%Y %H:%M:%S')" "https://ntfy.sh/$TOPIC" >/dev/null 2>&1
    fi
  elif echo "$ligne" | grep -q "boolean false"; then
    # ecran DEVERROUILLE
    [ $((MAINTENANT - DERNIER)) -lt 3 ] && continue
    DERNIER=$MAINTENANT
    rm -f "$ARME"
    curl -s -m 5 -H "Title: PC deverrouille" -H "Tags: unlock" -H "Priority: high" \
      -d "Session ouverte, vigilance desarmee
Quand : $(date '+%d/%m/%Y %H:%M:%S')" "https://ntfy.sh/$TOPIC" >/dev/null 2>&1
  fi
done
