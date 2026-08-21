#!/usr/bin/env bash
#
# healthcheck.sh — Rapport d'etat du serveur
# Usage : ./scripts/healthcheck.sh [-f fichier]
#
set -uo pipefail

SORTIE=""
while getopts ":f:" opt; do
    case $opt in
        f) SORTIE="$OPTARG" ;;
        *) printf 'Usage: %s [-f fichier]\n' "$0" >&2; exit 1 ;;
    esac
done

titre()  { printf '\n=== %s ===\n' "$1"; }
ligne()  { printf '  %-22s %s\n' "$1" "$2"; }

rapport() {
    printf 'RAPPORT D ETAT — %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf '%s\n' "$(printf '=%.0s' {1..48})"

    titre "Systeme"
    ligne "Hote"        "$(hostname)"
    ligne "Noyau"       "$(uname -r)"
    ligne "Distribution" "$(. /etc/os-release && echo "$PRETTY_NAME")"
    ligne "Uptime"      "$(uptime -p 2>/dev/null || echo n/a)"

    titre "Ressources"
    ligne "Charge (1/5/15m)" "$(cut -d' ' -f1-3 /proc/loadavg)"
    ligne "Memoire"     "$(free -h | awk '/^Mem:/{print $3" / "$2}')"
    ligne "Disque /"    "$(df -h / | awk 'NR==2{print $3" / "$2"  ("$5" utilise)"}')"

    titre "Services"
    for s in ssh nginx docker ufw; do
        etat=$(systemctl is-active "$s" 2>/dev/null || echo inactif)
        ligne "$s" "$etat"
    done

    titre "Reseau"
    ligne "Adresse IP" "$(hostname -I | awk '{print $1}')"
    ligne "Passerelle" "$(ip route | awk '/^default/{print $3; exit}')"
    printf '  Ports en ecoute :\n'
    ss -tuln 2>/dev/null | awk 'NR>1{print "    "$1"  "$5}' | sort -u

    titre "Pare-feu"
    if command -v ufw >/dev/null; then
        ufw status 2>/dev/null | sed 's/^/  /'
    else
        printf '  ufw non installe\n'
    fi

    titre "Conteneurs"
    if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
        n=$(docker ps -q | wc -l)
        ligne "En execution" "$n"
        [[ $n -gt 0 ]] && docker ps --format '    {{.Names}}  {{.Image}}  {{.Status}}'
    else
        printf '  Docker inaccessible (daemon arrete ou droits insuffisants)\n'
    fi
    printf '\n'
}

if [[ -n "$SORTIE" ]]; then
    rapport > "$SORTIE"
    printf 'Rapport ecrit dans %s\n' "$SORTIE"
else
    rapport
fi
