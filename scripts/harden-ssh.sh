#!/usr/bin/env bash
#
# harden-ssh.sh — Durcissement du service SSH
# Usage : sudo ./scripts/harden-ssh.sh
#
# PREREQUIS : la cle publique doit deja etre deposee sur le serveur.
#   Depuis l'hote :  ssh-copy-id souhayb@<ip>
#   Puis verifier :  ssh -o PasswordAuthentication=no souhayb@<ip>
#
set -euo pipefail

readonly CONF=/etc/ssh/sshd_config
readonly SAUVEGARDE="${CONF}.bak-$(date +%Y%m%d-%H%M%S)"

log()  { printf '\033[1;34m[+]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$1"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$1" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Ce script doit etre execute avec les privileges root."

readonly CIBLE="${SUDO_USER:-}"
[[ -n "$CIBLE" ]] || die "SUDO_USER vide : impossible de verifier les cles."

# Garde-fou : refuser de couper les mots de passe sans cle installee
CLES="/home/${CIBLE}/.ssh/authorized_keys"
if [[ ! -s "$CLES" ]]; then
    die "Aucune cle publique dans ${CLES}. Lancez d'abord ssh-copy-id depuis l'hote."
fi
log "Cle(s) publique(s) detectee(s) pour '${CIBLE}' : $(wc -l < "$CLES")"

log "Sauvegarde de la configuration dans ${SAUVEGARDE}"
cp "$CONF" "$SAUVEGARDE"

regler() {
    local cle="$1" valeur="$2"
    if grep -qE "^\s*#?\s*${cle}\b" "$CONF"; then
        sed -i "s|^\s*#\?\s*${cle}\b.*|${cle} ${valeur}|" "$CONF"
    else
        printf '%s %s\n' "$cle" "$valeur" >> "$CONF"
    fi
    printf '    %-28s %s\n' "$cle" "$valeur"
}

log "Application des directives de durcissement"
regler PermitRootLogin        no
regler PasswordAuthentication no
regler PubkeyAuthentication   yes
regler PermitEmptyPasswords   no
regler X11Forwarding          no
regler MaxAuthTries           3
regler ClientAliveInterval    300
regler ClientAliveCountMax    2

log "Validation de la syntaxe"
sshd -t || { cp "$SAUVEGARDE" "$CONF"; die "Syntaxe invalide : configuration restauree."; }

log "Redemarrage du service"
systemctl restart ssh

warn "NE FERMEZ PAS cette session."
warn "Ouvrez un SECOND terminal et testez la connexion par cle."
warn "En cas d'echec : sudo cp ${SAUVEGARDE} ${CONF} && sudo systemctl restart ssh"
