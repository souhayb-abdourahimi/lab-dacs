#!/bin/bash
# Alerte quand un peripherique USB est branche.
# Lance par alerte-usb@.service (root) ; le nom de l'appareil arrive en argument,
# car les variables udev ne sont pas transmises au service systemd.
CONF="/etc/lab-dacs/detection.conf"
[ -r "$CONF" ] && . "$CONF"
[ -z "$NTFY_TOPIC" ] && exit 0
APPAREIL="${1:-inconnu}"
curl -s -m 5 -H "Title: Peripherique USB branche" -H "Tags: floppy_disk" -H "Priority: high" \
  -d "Un appareil USB vient d etre connecte au PC
Appareil : ${APPAREIL//_/ }
Quand : $(date '+%d/%m/%Y %H:%M:%S')" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1
