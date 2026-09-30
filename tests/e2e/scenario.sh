#!/usr/bin/env bash
#
# tests/e2e/scenario.sh — Test de bout en bout sur une vraie VM :
#   1. VM neuve (image cloud officielle, QEMU/KVM)        tests/e2e/lancer-vm.sh
#   2. état de référence (root et mot de passe acceptés)   tests/e2e/verifier.sh avant
#   3. vrai ./install.sh, piloté comme au clavier          tests/e2e/install.exp
#   4. vérifications réelles                               tests/e2e/verifier.sh apres
#   5. second ./install.sh : 0 tâche modifiée exigée       (idempotence)
#   6. vérifications réelles à nouveau                     tests/e2e/verifier.sh apres-relance
#
# Les secrets de test sont tirés au hasard s'ils ne sont pas fournis, avec des
# caractères piégés (' : # " $) pour éprouver l'échappement. Sous GitHub Actions,
# ils sont masqués dans les journaux. Aucun secret réel n'est utilisé.
set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$RACINE"

export E2E_DISTRO="${E2E_DISTRO:-debian13}"
export E2E_DIR="${E2E_DIR:-/tmp/lab-e2e}"
export E2E_ADRESSE="${E2E_ADRESSE:-127.0.0.2}"
export E2E_UTILISATEUR="${E2E_UTILISATEUR:-labadmin}"
mkdir -p "$E2E_DIR"

masquer() { [[ -z "${GITHUB_ACTIONS:-}" ]] || echo "::add-mask::$1"; }
# Sous GitHub Actions, les étapes suivantes (diagnostic en cas d'échec) en ont besoin
partager() { [[ -z "${GITHUB_ENV:-}" ]] || echo "$1=${!1}" >> "$GITHUB_ENV"; }
aleatoire() { printf '%s' "$(openssl rand -hex 10)' :#\"\$x"; }
for var in E2E_SUDO_PW E2E_VAULT_PW E2E_GRAFANA_PW E2E_ADGUARD_PW; do
  if [[ -z "${!var:-}" ]]; then printf -v "$var" '%s' "$(aleatoire)"; fi
  masquer "${!var}"
  export "${var?}"
  partager "$var"
done
export E2E_NTFY_TOPIC="${E2E_NTFY_TOPIC:-lab-dacs-e2e-$(openssl rand -hex 8)}"
masquer "$E2E_NTFY_TOPIC"
partager E2E_NTFY_TOPIC

etape() { echo; echo "############ $1"; }
sans_couleurs() { sed 's/\x1b\[[0-9;]*m//g'; }

etape "1/6 VM $E2E_DISTRO neuve"
tests/e2e/lancer-vm.sh
E2E_EMPREINTE="$(cat "$E2E_DIR/empreinte")"
export E2E_EMPREINTE

etape "2/6 État de référence"
tests/e2e/verifier.sh avant

etape "3/6 Premier déploiement : ./install.sh"
expect tests/e2e/install.exp 2>&1 | tee "$E2E_DIR/install-1.log"

etape "4/6 Vérifications après déploiement"
tests/e2e/verifier.sh apres

etape "5/6 Second déploiement (idempotence)"
expect tests/e2e/install.exp 2>&1 | tee "$E2E_DIR/install-2.log"
recap="$(sans_couleurs < "$E2E_DIR/install-2.log" | grep -E '^lab-vm +: ok=' | tail -1)"
echo "Bilan du second passage : $recap"
if ! grep -qE 'changed=0 +unreachable=0 +failed=0' <<<"$recap"; then
  echo "✘ Le second passage n'est pas idempotent. Tâches modifiées :" >&2
  sans_couleurs < "$E2E_DIR/install-2.log" \
    | awk '/^TASK \[/ {tache=$0} /^changed:/ {print "   " tache}' | sort -u >&2
  exit 1
fi
echo "✔ Second passage : aucune tâche modifiée"

etape "6/6 Vérifications après le second déploiement"
tests/e2e/verifier.sh apres-relance

echo
echo "✔ Test de bout en bout réussi sur une VM $E2E_DISTRO."
