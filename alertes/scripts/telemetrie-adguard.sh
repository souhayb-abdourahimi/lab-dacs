#!/bin/sh
set -eu
# shellcheck source=/dev/null
. /etc/lab-alertes.conf
ETAT=/var/lib/lab-alertes/adguard-derniers
LISTES_DANGER="1789908844 1789908846"
mkdir -p /var/lib/lab-alertes
touch "$ETAT"
curl --fail --silent --show-error --max-time 5 -u "$ADGUARD_AUTH" "http://127.0.0.1:8090/control/querylog?limit=100" |
  jq -r '.data[]? | select(.reason == "FilteredBlackList") | "\(.time)|\(.question.name)|\(.rules[0].filter_list_id // -1)"' |
  while IFS='|' read -r horodatage domaine liste; do
    cle="$horodatage-$domaine"
    grep -qF "$cle" "$ETAT" && continue
    printf '%s\n' "$cle" >> "$ETAT"
    logger -t lab-dns "evenement=domaine_bloque domaine=$domaine liste=$liste"
    case " $LISTES_DANGER " in
      *" $liste "*) /usr/local/bin/alerte-adguard.sh "$domaine" || logger -p user.warning -t lab-alerting "evenement=echec_notification type=adguard domaine=$domaine" ;;
    esac
  done
tail -n 500 "$ETAT" > "$ETAT.tmp"
mv "$ETAT.tmp" "$ETAT"
