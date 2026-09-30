#!/bin/sh
# Journalise chaque domaine bloqué par AdGuard (tag « lab-dns », lu par Loki
# pour le tableau de bord Sécurité) et notifie seulement les blocages venant des
# listes de DANGER (phishing/malware) : les pubs et traqueurs restent silencieux.
# Fichier généré par Ansible (modèle : alertes/lab-alertes.conf.example).
# shellcheck source=/dev/null
. /etc/lab-alertes.conf
ETAT=/var/lib/lab-alertes/adguard-derniers
LISTES_DANGER="1789908844 1789908846"   # Phishing Army + URLhaus
mkdir -p /var/lib/lab-alertes
touch "$ETAT"

curl -s -m 5 -u "$ADGUARD_AUTH" "http://127.0.0.1:8090/control/querylog?limit=100" \
  | jq -r '.data[]? | select(.reason=="FilteredBlackList") | "\(.time)|\(.question.name)|\(.rules[0].filter_list_id // -1)"' \
  | while IFS='|' read -r horodatage domaine liste; do
      cle="$horodatage-$domaine"
      grep -qF "$cle" "$ETAT" && continue
      echo "$cle" >> "$ETAT"
      logger -t lab-dns "evenement=domaine_bloque domaine=$domaine liste=$liste"
      case " $LISTES_DANGER " in
        *" $liste "*) ;;
        *) continue ;;
      esac
      curl -s -m 5 -H "Title: Site dangereux bloque" -H "Tags: warning" -H "Priority: high" \
        -d "Domaine : $domaine
Quand : $(date '+%d/%m/%Y %H:%M')" "${NTFY_SERVEUR:-https://ntfy.sh}/$NTFY_TOPIC" >/dev/null 2>&1
    done
tail -n 500 "$ETAT" > "$ETAT.tmp" && mv "$ETAT.tmp" "$ETAT"
