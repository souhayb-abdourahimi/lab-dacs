#!/usr/bin/env bash
#
# install-pc.sh — Installe la détection d'accès physique sur CE poste de travail.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/runtime.sh
. "$SCRIPT_DIR/scripts/lib/runtime.sh"
# shellcheck source=scripts/lib/ui.sh
. "$SCRIPT_DIR/scripts/lib/ui.sh"
# shellcheck source=scripts/lib/os_detect.sh
. "$SCRIPT_DIR/scripts/lib/os_detect.sh"
# shellcheck source=scripts/lib/validation.sh
. "$SCRIPT_DIR/scripts/lib/validation.sh"
# shellcheck source=scripts/lib/ansible_runner.sh
. "$SCRIPT_DIR/scripts/lib/ansible_runner.sh"
# shellcheck source=scripts/lib/pc_installer.sh
. "$SCRIPT_DIR/scripts/lib/pc_installer.sh"

cd "$SCRIPT_DIR/ansible" || { erreur "Dossier ansible/ introuvable."; exit 1; }

exiger_utilisateur_non_root
pc_mode_depuis_args "$@"
afficher_intro_pc
confirmer_continuation
preparer_ansible_pc
configurer_webcam_pc
preparer_ntfy_pc
deployer_pc
afficher_fin_pc
