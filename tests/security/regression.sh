#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
ECHECS=0
ok(){ printf '✔ %s\n' "$1"; }
echec(){ printf '✘ %s\n' "$1" >&2; ECHECS=$((ECHECS+1)); }
controle(){ local m=$1; shift; if "$@"; then ok "$m"; else echec "$m"; fi; }
absent_git(){ ! git ls-files --error-unmatch "$1" >/dev/null 2>&1; }
contient(){ grep -qF -- "$2" "$1"; }
ne_contient_pas(){ ! grep -qF -- "$2" "$1"; }
mode_secret_alertes(){ grep -A8 -F "dest: /etc/lab-alertes.conf" ansible/roles/secrets/tasks/main.yml | grep -qF 'mode: "0600"'; }
mode_secret_grafana(){ grep -A8 -F "supervision/grafana_admin_password" ansible/roles/supervision/tasks/main.yml | grep -qF 'mode: "0400"'; }
pam_optionnel(){ grep -qF "session optional pam_exec.so /usr/local/bin/alerte-connexion.sh" ansible/roles/alertes/tasks/main.yml && grep -qF "session optional pam_exec.so seteuid /usr/local/bin/alerte-sudo.sh" ansible/roles/alertes/tasks/main.yml; }
aucun_docker_socket(){ ! grep -R -E '/var/run/docker\.sock|/run/docker\.sock' supervision adguard docker --include='*.yml' --include='*.yaml'; }
aucun_privileged(){ ! grep -R -E '^[[:space:]]*privileged:[[:space:]]*true' supervision adguard docker --include='*.yml' --include='*.yaml'; }
admin_localhost(){ grep -qF '"127.0.0.1:3000:3000"' supervision/docker-compose.yml && grep -qF '"127.0.0.1:8090:80/tcp"' adguard/docker-compose.yml; }
shell_strict(){ local f; for f in install.sh install-pc.sh scripts/lib/*.sh; do [[ -f "$f" ]] || continue; grep -qE '^set -E?euo pipefail$|^set -euo pipefail$' "$f" || return 1; done; }
controle "ansible/.vault_pass n'est pas versionné" absent_git ansible/.vault_pass
controle "le coffre réel n'est pas versionné" absent_git ansible/group_vars/all.yml
controle "aucune clé privée SSH n'est versionnée" bash -c '! git ls-files | grep -Eq "(^|/)(id_rsa|id_ed25519|id_ecdsa)$"'
controle "/etc/lab-alertes.conf est déployé en 0600" mode_secret_alertes
controle "le mot de passe Grafana est déployé en 0400" mode_secret_grafana
controle "root est interdit en SSH" contient ansible/roles/ssh/tasks/main.yml "PermitRootLogin no"
controle "les mots de passe SSH sont interdits" contient ansible/roles/ssh/tasks/main.yml "PasswordAuthentication no"
controle "les mots de passe vides sont interdits" contient ansible/roles/ssh/tasks/main.yml "PermitEmptyPasswords no"
controle "la configuration SSH est validée" contient ansible/roles/ssh/tasks/main.yml "validate: /usr/sbin/sshd -t -f %s"
controle "les hooks PAM restent optionnels" pam_optionnel
controle "aucun socket Docker n'est monté" aucun_docker_socket
controle "aucun conteneur applicatif n'est privilégié" aucun_privileged
controle "les interfaces admin restent sur localhost" admin_localhost
controle "les installateurs Bash utilisent le mode strict" shell_strict
controle "host_key_checking n'est pas désactivé" ne_contient_pas ansible/ansible.cfg "host_key_checking = False"
controle "StrictHostKeyChecking utilise accept-new" contient ansible/ansible.cfg "StrictHostKeyChecking=accept-new"
((ECHECS==0)) && printf 'Tous les contrôles de régression sécurité sont passés.\n' || printf '%d contrôle(s) en échec.\n' "$ECHECS" >&2
exit "$ECHECS"
