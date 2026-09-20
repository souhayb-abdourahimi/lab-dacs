#!/bin/bash
# Autorise ou non la capture webcam pendant le mode vigilance
DRAPEAU="$HOME/.local/state/photo-autorisee"
mkdir -p "$(dirname "$DRAPEAU")"
case "$1" in
  on)  touch "$DRAPEAU"; echo "Photo webcam ACTIVEE" ;;
  off) rm -f "$DRAPEAU"; echo "Photo webcam desactivee" ;;
  statut) [ -f "$DRAPEAU" ] && echo "ACTIVEE" || echo "desactivee" ;;
  *) echo "Usage : photo-toggle.sh {on|off|statut}" ;;
esac
