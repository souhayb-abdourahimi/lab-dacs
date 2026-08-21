#!/usr/bin/env bash
#
# firewall.sh — Politique de filtrage ufw
# Usage : sudo ./scripts/firewall.sh
#
# IMPORTANT : SSH est autorise AVANT l'activation du pare-feu.
# Inverser cet ordre coupe la session en cours et impose de repasser
# par la console de l'hyperviseur.
#
set -euo pipefail

log() { printf '\033[1;34m[+]\033[0m %s\n' "$1"; }
die() { printf '\033[1;31m[x]\033[0m %s\n' "$1" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Ce script doit etre execute avec les privileges root."

log "Politique par defaut : tout refuser en entree, tout autoriser en sortie"
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing

log "Autorisation de SSH (22/tcp) — AVANT activation"
ufw limit 22/tcp comment 'SSH avec limitation anti-bruteforce'

log "Autorisation de HTTP (80/tcp)"
ufw allow 80/tcp comment 'Nginx HTTP'

log "Autorisation de HTTPS (443/tcp)"
ufw allow 443/tcp comment 'Nginx HTTPS'

log "Activation du pare-feu"
ufw --force enable

log "Etat des regles"
ufw status verbose
