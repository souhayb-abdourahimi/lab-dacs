#!/usr/bin/env bash
#
# tests/e2e/diagnostic.sh — En cas d'échec du test de bout en bout : état de la VM
# (services, pare-feu, journaux) affiché dans le journal de CI. N'échoue jamais.
set -uo pipefail
DIR="${E2E_DIR:-/tmp/lab-e2e}"
ADRESSE="${E2E_ADRESSE:-127.0.0.2}"
UTILISATEUR="${E2E_UTILISATEUR:-labadmin}"
SSH=(ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=yes
     -o UserKnownHostsFile="$DIR/known_hosts" -o LogLevel=ERROR "$UTILISATEUR@$ADRESSE")

echo "=== Console série (fin)"
sudo tail -n 80 "$DIR/console.log" 2>/dev/null || tail -n 80 "$DIR/console.log" 2>/dev/null

if ! "${SSH[@]}" true 2>/dev/null; then
  echo "VM injoignable en SSH par clé : pas de diagnostic interne."
  exit 0
fi
# Mot de passe sudo sur l'entrée standard, jamais en argument
printf '%s\n' "${E2E_SUDO_PW:-}" | "${SSH[@]}" "sudo -S -p '' bash -s" <<'DIAG' 2>&1
echo "=== Services"
systemctl --no-pager --failed
for s in docker crowdsec crowdsec-firewall-bouncer ssh sshd systemd-resolved; do
  printf '%-28s %s\n' "$s" "$(systemctl is-active "$s" 2>/dev/null)"
done
echo "=== Conteneurs"; docker ps -a
echo "=== Pare-feu"; ufw status verbose; nft list ruleset | head -60
echo "=== CrowdSec"; cscli bouncers list; cscli decisions list
echo "=== Journaux";
for s in crowdsec crowdsec-firewall-bouncer docker; do
  echo "--- $s"; journalctl -u "$s" -n 40 --no-pager
done
tail -n 40 /var/log/crowdsec-firewall-bouncer.log 2>/dev/null
echo "=== sshd"; sshd -T | grep -Ei '^(permitrootlogin|passwordauthentication|kbdinteractive)'
DIAG
exit 0
