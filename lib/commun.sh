# shellcheck shell=bash
#
# lib/commun.sh — Fonctions partagées par install.sh et install-pc.sh
# (machine de contrôle). À sourcer, pas à exécuter.
#
# Portabilité : uniquement bash + outils POSIX (pas de grep -P, sed -r/-E
# spécifiques, sort -V, readlink -f...). Gestionnaires de paquets pris en
# charge : apt, dnf, pacman, zypper.

# Version minimale d'ansible-core : les collections récentes (community.general
# 10+, community.docker 4+) n'acceptent plus les versions plus anciennes.
ANSIBLE_CORE_MIN="2.16"

BLEU="\033[1;34m"; VERT="\033[1;32m"; ROUGE="\033[1;31m"; JAUNE="\033[1;33m"; RAZ="\033[0m"
titre()    { echo -e "\n${BLEU}==> $1${RAZ}"; }
ok()       { echo -e "${VERT}✔ $1${RAZ}"; }
attention(){ echo -e "${JAUNE}⚠ $1${RAZ}"; }
erreur()   { echo -e "${ROUGE}✘ $1${RAZ}" >&2; }

# Chaîne YAML entre apostrophes : dans ce style, seule l'apostrophe doit être
# échappée (en la doublant). Les caractères : # " \ etc. restent littéraux.
yaml_quote() { local v=${1//\'/\'\'}; printf "'%s'" "$v"; }

# Affiche le gestionnaire de paquets de cette machine (vide si inconnu)
gestionnaire_paquets() {
  local g
  for g in apt-get dnf pacman zypper; do
    if command -v "$g" >/dev/null 2>&1; then
      [[ "$g" == apt-get ]] && g=apt
      echo "$g"; return 0
    fi
  done
  echo ""
}

# installer_paquets PAQUET... — installe avec le gestionnaire de la machine
installer_paquets() {
  case "$(gestionnaire_paquets)" in
    apt)    sudo apt-get update && sudo apt-get install -y "$@" ;;
    dnf)    sudo dnf install -y "$@" ;;
    # -Syu : Arch ne prend pas en charge les mises à jour partielles
    pacman) sudo pacman -Syu --needed --noconfirm "$@" ;;
    zypper) sudo zypper --non-interactive install "$@" ;;
    *)      return 1 ;;
  esac
}

# Affiche la version d'ansible-core installée (ex. 2.16), vide si absente.
# « ansible --version » : « ansible [core 2.16.3] » (récent) ou « ansible 2.10.8 ».
version_ansible_core() {
  command -v ansible >/dev/null 2>&1 || return 0
  ansible --version 2>/dev/null | head -n 1 \
    | sed -n 's/^[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\).*$/\1/p'
}

# version_suffisante 2.16 2.14 -> vrai si la 1re version >= la 2e (MAJEUR.MINEUR)
version_suffisante() {
  local a_maj a_min b_maj b_min
  IFS=. read -r a_maj a_min <<<"$1"
  IFS=. read -r b_maj b_min <<<"$2"
  [[ -n "$a_maj" && -n "$a_min" ]] || return 1
  (( a_maj > b_maj || (a_maj == b_maj && a_min >= b_min) ))
}

ansible_suffisant() {
  command -v ansible-playbook >/dev/null 2>&1 \
    && version_suffisante "$(version_ansible_core)" "$ANSIBLE_CORE_MIN"
}

# Affiche un interpréteur Python >= 3.10 (requis par ansible-core récent côté
# contrôle). RHEL 9 : python3 est en 3.9, mais python3.11/3.12 sont installables.
python_recent() {
  local py
  for py in python3 python3.13 python3.12 python3.11 python3.10; do
    if command -v "$py" >/dev/null 2>&1 \
       && "$py" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; then
      command -v "$py"; return 0
    fi
  done
  return 1
}

# Installe ansible-core avec pipx (dans ~/.local/bin), en secours quand la
# version de la distribution est trop ancienne (Debian 12, Ubuntu 22.04, RHEL 9).
# Si pipx n'est pas disponible, un environnement virtuel Python dédié est utilisé.
installer_ansible_pipx() {
  local venv="$HOME/.local/share/lab-dacs/ansible-venv" py
  export PATH="$HOME/.local/bin:$PATH"

  if ! py="$(python_recent)"; then
    if [[ "$(gestionnaire_paquets)" == dnf ]]; then installer_paquets python3.12 || true; fi
    py="$(python_recent)" || { erreur "Python >= 3.10 introuvable (requis par ansible-core)."; return 1; }
  fi

  if ! command -v pipx >/dev/null 2>&1; then
    case "$(gestionnaire_paquets)" in
      apt)    installer_paquets pipx ;;
      dnf)    installer_paquets pipx ;;
      pacman) installer_paquets python-pipx ;;
      zypper) installer_paquets python3-pipx ;;
    esac || true
  fi

  if command -v pipx >/dev/null 2>&1; then
    # --force : remplace une installation pipx antérieure trop ancienne
    pipx install --force --python "$py" ansible-core
  else
    attention "pipx indisponible : installation d'ansible-core dans $venv"
    "$py" -m venv "$venv" || { erreur "$py -m venv a échoué (paquet python3-venv manquant ?)."; return 1; }
    "$venv/bin/pip" install --upgrade pip ansible-core
    mkdir -p "$HOME/.local/bin"
    local outil
    for outil in ansible ansible-playbook ansible-galaxy ansible-vault; do
      ln -sf "$venv/bin/$outil" "$HOME/.local/bin/$outil"
    done
  fi
  hash -r
}

# S'assure qu'ansible-core >= ANSIBLE_CORE_MIN est disponible :
#  1. version déjà installée suffisante -> rien à faire ;
#  2. sinon paquet de la distribution (ansible-core, à défaut ansible) ;
#  3. si toujours trop ancien -> pipx (ou venv) dans ~/.local/bin.
assurer_ansible() {
  # Une installation pipx précédente est dans ~/.local/bin : la voir en priorité
  export PATH="$HOME/.local/bin:$PATH"
  if ansible_suffisant; then
    ok "Ansible est installé ($(ansible --version | head -n 1))."
    return 0
  fi

  local actuelle gp rep
  actuelle="$(version_ansible_core)"
  gp="$(gestionnaire_paquets)"
  if [[ -n "$actuelle" ]]; then
    attention "ansible-core $actuelle est trop ancien (minimum $ANSIBLE_CORE_MIN)."
  else
    attention "Ansible n'est pas installé."
    if [[ -n "$gp" ]]; then
      read -r -p "Installer Ansible avec $gp (sudo) ? [o/N] " rep
      [[ "$rep" =~ ^[oO]$ ]] || { erreur "Ansible est requis. Arrêt."; return 1; }
      installer_paquets ansible-core || installer_paquets ansible || true
      hash -r
      if ansible_suffisant; then
        ok "Ansible installé ($(ansible --version | head -n 1))."
        return 0
      fi
      actuelle="$(version_ansible_core)"
      [[ -n "$actuelle" ]] && attention "La distribution fournit ansible-core $actuelle, trop ancien."
    else
      attention "Gestionnaire de paquets non reconnu (apt, dnf, pacman ou zypper attendu)."
    fi
  fi

  read -r -p "Installer une version récente d'ansible-core pour votre compte, avec pipx (~/.local/bin) ? [o/N] " rep
  [[ "$rep" =~ ^[oO]$ ]] || { erreur "ansible-core >= $ANSIBLE_CORE_MIN est requis. Arrêt."; return 1; }
  installer_ansible_pipx || { erreur "Installation d'ansible-core impossible. Installez-le manuellement puis relancez."; return 1; }
  if ansible_suffisant; then
    ok "ansible-core installé dans ~/.local/bin ($(ansible --version | head -n 1))."
    attention "Ajoutez ~/.local/bin à votre PATH si ce n'est pas déjà le cas."
  else
    erreur "ansible-core >= $ANSIBLE_CORE_MIN reste introuvable après installation."
    return 1
  fi
}

# Installe les collections Ansible listées dans ansible/requirements.yml
# (appeler depuis le dossier ansible/). Galaxy renvoie parfois une réponse
# invalide passagère (« Unexpected Exception ... 'results' ») : 3 essais.
installer_collections() {
  local essai
  for essai in 1 2 3; do
    ansible-galaxy collection install -r requirements.yml >/dev/null && return 0
    [[ $essai -lt 3 ]] && attention "Galaxy indisponible, nouvel essai dans $((essai * 10)) s..." && sleep $((essai * 10))
  done
  return 1
}

# Demande l'adresse du serveur ntfy (Entrée = service public https://ntfy.sh)
# et l'écrit dans la variable NTFY_SERVEUR, sans « / » final.
demander_serveur_ntfy() {
  local reponse
  while true; do
    read -r -p "Serveur ntfy [https://ntfy.sh, ou le vôtre ex: https://ntfy.mondomaine.fr] : " reponse
    reponse="${reponse:-https://ntfy.sh}"
    while [[ "$reponse" == */ ]]; do reponse="${reponse%/}"; done
    if [[ "$reponse" =~ ^https?://[^/[:space:]]+(/[^[:space:]]*)?$ ]]; then
      # shellcheck disable=SC2034  # lue par le script appelant
      NTFY_SERVEUR="$reponse"
      return 0
    fi
    attention "Adresse invalide : elle doit commencer par https:// (ou http://)."
  done
}
