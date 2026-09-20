#!/bin/bash
# Interrupteur du mode vigilance (surveillance d'absence)
DRAPEAU="$HOME/.local/state/mode-vigilance"
mkdir -p "$(dirname "$DRAPEAU")"
TOPIC=$(grep -oP '(?<=NTFY_TOPIC=).*' /etc/lab-alertes.conf 2>/dev/null)

case "$1" in
  absent)
    touch "$DRAPEAU"
    notify-send "Mode vigilance ARMÉ" "La surveillance d'absence est active." 2>/dev/null
    [ -n "$TOPIC" ] && curl -s -m 5 -H "Title: Vigilance armee" -H "Tags: shield" \
      -d "Surveillance d'absence activee
Quand : $(date '+%d/%m/%Y %H:%M:%S')" "https://ntfy.sh/$TOPIC" >/dev/null 2>&1
    echo "Mode vigilance ARMÉ."
    ;;
  present)
    rm -f "$DRAPEAU"
    notify-send "Mode vigilance désarmé" "Bon retour." 2>/dev/null
    echo "Mode vigilance désarmé."
    ;;
  statut)
    [ -f "$DRAPEAU" ] && echo "ARMÉ" || echo "désarmé"
    ;;
  *)
    echo "Usage : mode-vigilance.sh {absent|present|statut}"
    ;;
esac
