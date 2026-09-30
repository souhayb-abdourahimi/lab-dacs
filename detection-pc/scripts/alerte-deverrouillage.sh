#!/bin/bash
# Verrouillage : arme la vigilance si elle etait en attente
# Deverrouillage : alerte + desarme la vigilance
CONF="$HOME/.config/lab-dacs/detection.conf"
# Fichier généré au déploiement, hors dépôt : shellcheck ne peut pas le lire.
# shellcheck source=/dev/null
[ -r "$CONF" ] && . "$CONF"
[ -z "$NTFY_TOPIC" ] && exit 0
ATTENTE="$HOME/.local/state/vigilance-en-attente"
ARME="$HOME/.local/state/mode-vigilance"
mkdir -p "$(dirname "$ARME")"
DERNIER=0

# Signal ActiveChanged(boolean) emis au verrouillage (true) et au deverrouillage (false) :
#   - GNOME      : interface org.gnome.ScreenSaver
#   - KDE Plasma : interface org.freedesktop.ScreenSaver (emis sur deux chemins D-Bus,
#                  d'ou des doublons : l'armement est idempotent, le deverrouillage filtre)
dbus-monitor --session \
  "type='signal',interface='org.gnome.ScreenSaver',member='ActiveChanged'" \
  "type='signal',interface='org.freedesktop.ScreenSaver',member='ActiveChanged'" 2>/dev/null |
while read -r ligne; do
  MAINTENANT=$(date +%s)

  if echo "$ligne" | grep -q "boolean true"; then
    # ecran VERROUILLE
    if [ -f "$ATTENTE" ]; then
      rm -f "$ATTENTE"; touch "$ARME"
      curl -s -m 5 -H "Title: Vigilance armee" -H "Tags: shield" \
        -d "Surveillance active (ecran verrouille)
Quand : $(date '+%d/%m/%Y %H:%M:%S')" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1
    fi
  elif echo "$ligne" | grep -q "boolean false"; then
    # ecran DEVERROUILLE
    [ $((MAINTENANT - DERNIER)) -lt 3 ] && continue
    DERNIER=$MAINTENANT
    rm -f "$ARME"
    curl -s -m 5 -H "Title: PC deverrouille" -H "Tags: unlock" -H "Priority: high" \
      -d "Session ouverte, vigilance desarmee
Quand : $(date '+%d/%m/%Y %H:%M:%S')" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1
  fi
done
