#!/bin/sh
# Notifie seulement les blocages venant des listes de DANGER (phishing/malware)
. /etc/lab-alertes.conf
ETAT=/var/lib/lab-alertes/adguard-derniers
LISTES_DANGER="1789908844 1789908846"   # Phishing Army + URLhaus
mkdir -p /var/lib/lab-alertes
touch "$ETAT"

filtre_jq=$(echo "$LISTES_DANGER" | tr ' ' ',')
curl -s -m 5 -u "$ADGUARD_AUTH" "http://127.0.0.1:8090/control/querylog?limit=50" \
  | jq -r --argjson ids "[$filtre_jq]" '.data[]? | select(.reason=="FilteredBlackList") | select((.rules[0].filter_list_id // -1) as $id | $ids | index($id)) | "\(.time)|\(.question.name)"' \
  | while IFS='|' read -r horodatage domaine; do
      cle="$horodatage-$domaine"
      grep -qF "$cle" "$ETAT" && continue
      curl -s -m 5 -H "Title: Site dangereux bloque" -H "Tags: warning" -H "Priority: high" \
        -d "Domaine : $domaine
Quand : $(date '+%d/%m/%Y %H:%M')" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1
      echo "$cle" >> "$ETAT"
    done
tail -n 200 "$ETAT" > "$ETAT.tmp" && mv "$ETAT.tmp" "$ETAT"
