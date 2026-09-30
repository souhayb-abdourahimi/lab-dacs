#!/usr/bin/env bash
#
# tests/e2e/verifier.sh — Vérifications « pour de vrai » sur la VM de test,
# depuis la machine qui a lancé install.sh (le runner de CI).
#
# Usage : verifier.sh avant | apres | apres-relance
#   avant         état de référence de la VM neuve (SSH par mot de passe et root
#                 ACCEPTÉS) : prouve que les contrôles suivants ont un sens
#   apres         après le premier déploiement (sshd doit avoir redémarré)
#   apres-relance après le second déploiement (sshd ne doit PAS redémarrer)
#
# Variables : E2E_DIR, E2E_ADRESSE, E2E_UTILISATEUR, E2E_SUDO_PW, E2E_GRAFANA_PW,
#             E2E_NTFY_TOPIC, E2E_NTFY_SERVEUR (défaut https://ntfy.sh)
# Chaque contrôle affiche ✔ ou ✘ ; le script échoue si un seul contrôle échoue.
# Les fonctions de contrôle sont appelées indirectement (via controle/reessayer)
# shellcheck disable=SC2317,SC2329
set -uo pipefail

MODE="${1:?usage : verifier.sh avant|apres|apres-relance}"
DIR="${E2E_DIR:-/tmp/lab-e2e}"
ADRESSE="${E2E_ADRESSE:-127.0.0.2}"
UTILISATEUR="${E2E_UTILISATEUR:-labadmin}"
NTFY="${E2E_NTFY_SERVEUR:-https://ntfy.sh}"
ECHECS=0

ok()      { echo "✔ $1"; }
echec()   { echo "✘ $1" >&2; ECHECS=$((ECHECS + 1)); }
section() { echo; echo "=== $1"; }
# controle "libellé" commande... : ✔ si la commande réussit, ✘ sinon
controle() {
  local libelle=$1; shift
  if "$@"; then ok "$libelle"; else echec "$libelle"; fi
}
# reessayer N PAUSE commande... : relance tant que la commande échoue
reessayer() {
  local n=$1 pause=$2 i; shift 2
  for ((i = 1; i <= n; i++)); do "$@" && return 0; sleep "$pause"; done
  return 1
}

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=yes
          -o UserKnownHostsFile="$DIR/known_hosts" -o LogLevel=ERROR)
# (commande distante volontairement construite côté runner)
# shellcheck disable=SC2029
vm()      { ssh "${SSH_OPTS[@]}" "$UTILISATEUR@$ADRESSE" "$@"; }
# sudo sur la VM : mot de passe envoyé sur l'entrée standard, jamais en argument
vm_sudo() { printf '%s\n' "$E2E_SUDO_PW" | vm "sudo -S -p '' $*"; }
root_se_connecte() { ssh "${SSH_OPTS[@]}" "root@$ADRESSE" true 2>/dev/null; }
root_refuse()      { ! root_se_connecte; }

# Méthodes d'authentification proposées par sshd, lues dans le refus du client
methodes_ssh() {
  ssh "${SSH_OPTS[@]}" -o PubkeyAuthentication=no -o PreferredAuthentications=none \
      "$UTILISATEUR@$ADRESSE" true 2>&1 | sed -n 's/.*Permission denied (\(.*\)).*/\1/p'
}
service_ssh()    { vm 'systemctl cat ssh.service >/dev/null 2>&1 && echo ssh || echo sshd'; }
horodatage_ssh() { vm "systemctl show -p ActiveEnterTimestampMonotonic --value $1"; }
contient()       { [[ "$1" == *"$2"* ]]; }
egal()           { [[ "$1" == "$2" ]]; }
different()      { [[ -n "$1" && "$1" != "$2" ]]; }

# ---------------------------------------------------------------------------
if [[ "$MODE" == avant ]]; then
  section "État de référence (VM neuve, avant déploiement)"
  controle "connexion SSH par clé" vm true
  controle "root peut se connecter (avant durcissement)" root_se_connecte
  m="$(methodes_ssh)"
  controle "mot de passe proposé par sshd ($m)" contient "$m" password
  svc="$(service_ssh)"
  horodatage_ssh "$svc" > "$DIR/ssh_demarrage"
  controle "démarrage de $svc relevé ($(cat "$DIR/ssh_demarrage"))" test -s "$DIR/ssh_demarrage"
  exit "$ECHECS"
fi

# ---------------------------------------------------------------------------
section "SSH"
controle "connexion par clé" vm true
m="$(methodes_ssh)"
controle "seule la clé est acceptée (méthodes proposées : $m)" egal "$m" publickey
controle "connexion root refusée" root_refuse
svc="$(service_ssh)"
avant="$(cat "$DIR/ssh_demarrage" 2>/dev/null)"
maintenant="$(horodatage_ssh "$svc")"
if [[ "$MODE" == apres ]]; then
  controle "$svc redémarré par le déploiement ($avant → $maintenant)" different "$maintenant" "$avant"
else
  controle "$svc non redémarré au second passage" egal "$maintenant" "$avant"
fi
echo "$maintenant" > "$DIR/ssh_demarrage"

# ---------------------------------------------------------------------------
section "Pare-feu ufw"
statut="$(vm_sudo ufw status verbose)"
echo "$statut"
controle "ufw actif" contient "$statut" "Status: active"
controle "entrée refusée par défaut" contient "$statut" "deny (incoming)"
autorises="$(awk '/ALLOW IN/ {print $1}' <<<"$statut" | sort -u | tr '\n' ' ')"
controle "seuls 22/tcp et 53 sont ouverts ($autorises)" egal "$autorises" "22/tcp 53/tcp 53/udp "
# Un vrai service écoute sur 8081 : joignable depuis la VM, bloqué de l'extérieur
vm_sudo "systemd-run --unit=e2e-http --quiet python3 -m http.server 8081" >/dev/null
http_local()   { vm "curl -fs -o /dev/null http://127.0.0.1:8081/"; }
http_externe_bloque() { ! curl -fs -m 5 -o /dev/null "http://$ADRESSE:8081/"; }
controle "service de test à l'écoute sur 8081 (depuis la VM)" reessayer 10 1 http_local
controle "port 8081 injoignable depuis le runner (pare-feu)" http_externe_bloque
vm_sudo "systemctl stop e2e-http" >/dev/null 2>&1

# ---------------------------------------------------------------------------
section "CrowdSec"
controle "crowdsec actif" vm "systemctl is-active --quiet crowdsec"
controle "crowdsec-firewall-bouncer actif" vm "systemctl is-active --quiet crowdsec-firewall-bouncer"
vm_sudo "cscli bouncers list"
pull_recent() {
  local lp age
  lp="$(vm_sudo "cscli bouncers list -o json" \
        | jq -r '[.[] | select(.name | test("firewall"; "i")) | select(.last_pull != null)]
                 | sort_by(.last_pull) | last | .last_pull // empty')"
  [[ -n "$lp" && "$lp" != null ]] || return 1
  age=$(( $(vm date -u +%s) - $(date -u -d "$lp" +%s) ))
  echo "  dernier « pull » du bouncer : $lp (il y a ${age}s)"
  (( age >= 0 && age < 120 ))
}
controle "bouncer inscrit, « Last API pull » récent" reessayer 6 10 pull_recent
# Blocage réel : la décision doit arriver dans le pare-feu du noyau
IP_TEST=203.0.113.7
vm_sudo "cscli decisions add --ip $IP_TEST --duration 10m --reason e2e" >/dev/null
# (deux appels : vm_sudo n'élève que la première commande d'une ligne)
regles_parefeu() { vm_sudo "nft list ruleset" 2>/dev/null; vm_sudo "ipset list" 2>/dev/null; }
ip_bloquee() { regles_parefeu | grep -qF "$IP_TEST"; }
ip_liberee() { ! ip_bloquee; }
# (le bouncer interroge l'API toutes les 10 s, avec un délai de reconnexion possible)
controle "$IP_TEST bloquée dans le pare-feu (nft/ipset)" reessayer 24 5 ip_bloquee
if ! ip_bloquee; then
  echo "  --- éléments pour comprendre :"
  vm_sudo "grep -H mode /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml*" 2>&1 | sed 's/^/  /'
  regles_parefeu | grep -E 'table|set |elements|Members|^[0-9]' | head -20 | sed 's/^/  /'
  vm_sudo "tail -n 8 /var/log/crowdsec-firewall-bouncer.log" 2>&1 | sed 's/^/  /'
fi
vm_sudo "cscli decisions delete --ip $IP_TEST" >/dev/null
controle "$IP_TEST retirée du pare-feu après suppression" reessayer 12 5 ip_liberee

# ---------------------------------------------------------------------------
section "Grafana (tunnel SSH) et AdGuard (DNS)"
SOCK="$DIR/tunnel.sock"
ssh "${SSH_OPTS[@]}" -M -S "$SOCK" -fN -o ExitOnForwardFailure=yes \
    -L 13000:127.0.0.1:3000 "$UTILISATEUR@$ADRESSE"
grafana_ok() {
  curl -fs -m 5 -u "admin:$E2E_GRAFANA_PW" http://127.0.0.1:13000/api/org >/dev/null \
    && curl -fs -m 5 http://127.0.0.1:13000/api/health | jq -e '.database == "ok"' >/dev/null
}
controle "Grafana répond via le tunnel (santé OK, mot de passe du coffre accepté)" reessayer 30 5 grafana_ok
ssh -S "$SOCK" -O exit "$UTILISATEUR@$ADRESSE" 2>/dev/null
dns_ok() {
  local r
  r="$(dig +time=3 +tries=1 @"$ADRESSE" example.com A)"
  grep -q 'status: NOERROR' <<<"$r" && grep -qE 'ANSWER: [1-9]' <<<"$r"
}
controle "AdGuard répond au DNS sur le port 53 (example.com résolu)" reessayer 20 3 dns_ok

# ---------------------------------------------------------------------------
section "Alertes ntfy (sujet de test aléatoire)"
DEBUT=$(date +%s)
sleep 1
vm true   # connexion SSH -> alerte « Connexion SSH »
# L'alerte sudo est limitée à une toutes les 10 min : on remet le compteur à zéro
vm_sudo "rm -f /var/lib/lab-alertes/dernier-sudo"
vm_sudo true   # sudo -> alerte « sudo utilisé »
titres() { curl -fs -m 10 "$NTFY/$E2E_NTFY_TOPIC/json?poll=1&since=$DEBUT" | jq -r '.title // empty'; }
alerte_recue() { titres | grep -q "$1"; }
controle "alerte « Connexion SSH » reçue sur ntfy" reessayer 12 5 alerte_recue "Connexion SSH"
controle "alerte « sudo utilisé » reçue sur ntfy" reessayer 12 5 alerte_recue "sudo utilis"
echo "  titres reçus depuis le début du contrôle :"
titres | sed 's/^/    /'

echo
if (( ECHECS == 0 )); then
  echo "Tous les contrôles ($MODE) sont passés."
else
  echo "$ECHECS contrôle(s) en échec ($MODE)." >&2
fi
exit "$ECHECS"
