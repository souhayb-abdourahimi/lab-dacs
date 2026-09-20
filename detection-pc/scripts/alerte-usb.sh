#!/bin/bash
# Alerte quand un peripherique USB est branche
TOPIC=$(grep -oP '(?<=NTFY_TOPIC=).*' /etc/lab-alertes.conf 2>/dev/null)
[ -z "$TOPIC" ] && exit 0
curl -s -m 5 -H "Title: Peripherique USB branche" -H "Tags: floppy_disk" -H "Priority: high" \
  -d "Un appareil USB vient d etre connecte au PC
Appareil : ${ID_VENDOR:-inconnu} ${ID_MODEL:-}
Quand : $(date '+%d/%m/%Y %H:%M:%S')" "https://ntfy.sh/$TOPIC" >/dev/null 2>&1
