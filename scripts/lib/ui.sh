# shellcheck shell=bash
# Affichage commun aux installateurs.
set -euo pipefail

BLEU="\033[1;34m"; VERT="\033[1;32m"; ROUGE="\033[1;31m"; JAUNE="\033[1;33m"; RAZ="\033[0m"
titre()     { echo -e "\n${BLEU}==> $1${RAZ}"; }
ok()        { echo -e "${VERT}✔ $1${RAZ}"; }
attention() { echo -e "${JAUNE}⚠ $1${RAZ}"; }
erreur()    { echo -e "${ROUGE}✘ $1${RAZ}" >&2; }
