#!/bin/sh
set -eu
DOMAINE=${1:?Domaine requis}
# shellcheck source=/dev/null
. /etc/lab-alertes.conf
curl --fail --silent --show-error --max-time 5 \
  -H "Title: Site dangereux bloque" -H "Tags: warning" -H "Priority: high" \
  -d "Domaine : $DOMAINE
Quand : $(date '+%d/%m/%Y %H:%M')" \
  "${NTFY_SERVEUR:-https://ntfy.sh}/$NTFY_TOPIC" >/dev/null
