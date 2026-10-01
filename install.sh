#!/usr/bin/env bash
#
# install.sh — Déploiement guidé du lab DACS
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
# shellcheck source=scripts/lib/server_installer.sh
. "$SCRIPT_DIR/scripts/lib/server_installer.sh"

cd "$SCRIPT_DIR/ansible" || { erreur "Dossier ansible/ introuvable. Lancez ce script depuis la racine du dépôt."; exit 1; }

afficher_intro_serveur
confirmer_continuation
preparer_ansible_serveur
configurer_inventaire_serveur
valider_cle_hote_serveur
preparer_coffre_serveur
verifier_connexion_serveur
deployer_serveur
afficher_fin_serveur
