#!/bin/bash
# Interrupteur du mode vigilance
ATTENTE="$HOME/.local/state/vigilance-en-attente"
ARME="$HOME/.local/state/mode-vigilance"
mkdir -p "$(dirname "$ARME")"

case "$1" in
  absent)
    touch "$ATTENTE"
    notify-send "Vigilance PRÊTE" "S'armera au verrouillage de l'écran (Super+L)." 2>/dev/null
    echo "Vigilance en attente : verrouille l'écran pour l'armer."
    ;;
  present)
    rm -f "$ATTENTE" "$ARME"
    notify-send "Vigilance désarmée" "Bon retour." 2>/dev/null
    echo "Vigilance désarmée."
    ;;
  statut)
    if [ -f "$ARME" ]; then echo "ARMÉE (surveillance active)"
    elif [ -f "$ATTENTE" ]; then echo "EN ATTENTE (s'armera au verrouillage)"
    else echo "désarmée"; fi
    ;;
  *) echo "Usage : mode-vigilance.sh {absent|present|statut}" ;;
esac
