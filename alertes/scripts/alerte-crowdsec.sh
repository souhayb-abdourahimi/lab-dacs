#!/bin/sh
set -eu
IP=${1:?IP CrowdSec requise}
SCENARIO=${2:?Scénario CrowdSec requis}
# shellcheck source=/dev/null
. /etc/lab-alertes.conf
curl --fail --silent --show-error --max-time 5 \
  -H "Title: IP bannie sur $(uname -n)" -H "Tags: shield" -H "Priority: high" \
  -d "IP : $IP
Raison : $SCENARIO
Quand : $(date '+%d/%m/%Y %H:%M')" \
  "${NTFY_SERVEUR:-https://ntfy.sh}/$NTFY_TOPIC" >/dev/null
