#!/bin/sh
# Envoie une notification pour chaque nouvelle alerte CrowdSec
. /etc/lab-alertes.conf
ETAT=/var/lib/lab-alertes/dernier-id-crowdsec
mkdir -p /var/lib/lab-alertes
DERNIER=$(cat "$ETAT" 2>/dev/null || echo 0)
cscli alerts list -o json 2>/dev/null \
  | jq -r --argjson d "$DERNIER" '.[]? | select(.id > $d) | "\(.id)|\(.source.value // "?")|\(.scenario // "?")"' \
  | sort -t'|' -k1,1n \
  | while IFS='|' read -r id ip scenario; do
      curl -s -m 5 -H "Title: IP bannie sur $(hostname)" -H "Tags: shield" -H "Priority: high" \
        -d "IP : $ip
Raison : $scenario
Quand : $(date '+%d/%m/%Y %H:%M')" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1
      echo "$id" > "$ETAT"
    done
