#!/bin/sh
set -eu
ETAT=/var/lib/lab-alertes/dernier-id-crowdsec
mkdir -p /var/lib/lab-alertes
DERNIER=$(cat "$ETAT" 2>/dev/null || printf '0')
cscli alerts list -o json 2>/dev/null |
  jq -r --argjson dernier "$DERNIER" '.[]? | select(.id > $dernier) | "\(.id)|\(.source.value // "?")|\(.scenario // "?")"' |
  sort -t'|' -k1,1n |
  while IFS='|' read -r id ip scenario; do
    raison=$(printf '%s' "$scenario" | tr '"' "'")
    logger -t lab-securite "evenement=ip_bannie ip=$ip raison=\"$raison\""
    if ! /usr/local/bin/alerte-crowdsec.sh "$ip" "$scenario"; then
      logger -p user.warning -t lab-alerting "evenement=echec_notification type=crowdsec ip=$ip"
    fi
    printf '%s\n' "$id" > "$ETAT"
  done
