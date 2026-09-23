#!/bin/bash
# Autorise ou non la capture webcam pendant le mode vigilance
DRAPEAU="$HOME/.local/state/photo-autorisee"
mkdir -p "$(dirname "$DRAPEAU")"
CONF="$HOME/.config/lab-dacs/detection.conf"
[ -r "$CONF" ] && . "$CONF"
case "$1" in
  on)
    if [ "$WEBCAM_ACTIVE" != "oui" ]; then
      echo "Webcam non installee. Pour l'ajouter, relancez install-pc.sh et acceptez l'option webcam."
      exit 1
    fi
    touch "$DRAPEAU"; echo "Photo webcam ACTIVEE" ;;
  off) rm -f "$DRAPEAU"; echo "Photo webcam desactivee" ;;
  statut) [ -f "$DRAPEAU" ] && echo "ACTIVEE" || echo "desactivee" ;;
  *) echo "Usage : photo-toggle.sh {on|off|statut}" ;;
esac
