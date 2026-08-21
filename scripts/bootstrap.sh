#!/usr/bin/env bash
#
# bootstrap.sh — Installation de la stack de base du lab DACS
# Usage : sudo ./scripts/bootstrap.sh
#
set -euo pipefail

readonly PAQUETS=(git curl wget vim htop tree
                  nmap tcpdump net-tools dnsutils
                  ufw nginx
                  docker.io docker-compose)

log()  { printf '\033[1;34m[+]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$1"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$1" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Ce script doit etre execute avec les privileges root."

readonly CIBLE="${SUDO_USER:-root}"
[[ "$CIBLE" != "root" ]] || warn "Aucun utilisateur non-root detecte (SUDO_USER vide)."

log "Mise a jour de l'index des paquets"
apt-get update -qq

log "Mise a niveau du systeme"
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

log "Installation de ${#PAQUETS[@]} paquets"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${PAQUETS[@]}"

log "Activation des services au demarrage"
systemctl enable --now docker
systemctl enable --now nginx
systemctl enable --now ssh

if [[ "$CIBLE" != "root" ]]; then
    log "Ajout de '$CIBLE' aux groupes sudo et docker"
    usermod -aG sudo,docker "$CIBLE"
    warn "Deconnectez-vous et reconnectez-vous pour activer le groupe docker."
fi

log "Versions installees"
printf '    nginx  : %s\n' "$(nginx -v 2>&1 | sed 's|.*/||')"
printf '    docker : %s\n' "$(docker --version | awk '{print $3}' | tr -d ,)"
printf '    git    : %s\n' "$(git --version | awk '{print $3}')"

log "Termine. Etape suivante : sudo ./scripts/firewall.sh"
