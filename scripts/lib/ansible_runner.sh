# shellcheck shell=bash
# Installation d'Ansible et exécution centralisée des commandes Ansible.
set -euo pipefail

ANSIBLE_CORE_MIN="2.16"

version_ansible_core() {
  command -v ansible >/dev/null 2>&1 || return 0
  ansible --version 2>/dev/null | head -n 1 \
    | sed -n 's/^[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\).*$/\1/p'
}

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

installer_ansible_pipx() {
  local venv="$HOME/.local/share/lab-dacs/ansible-venv" py outil
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
    pipx install --force --python "$py" ansible-core
  else
    attention "pipx indisponible : installation d'ansible-core dans $venv"
    "$py" -m venv "$venv" || { erreur "$py -m venv a échoué (paquet python3-venv manquant ?)."; return 1; }
    "$venv/bin/pip" install --upgrade pip ansible-core
    mkdir -p "$HOME/.local/bin"
    for outil in ansible ansible-playbook ansible-galaxy ansible-vault; do
      ln -sf "$venv/bin/$outil" "$HOME/.local/bin/$outil"
    done
  fi
  hash -r
}

assurer_ansible() {
  local actuelle gp rep
  export PATH="$HOME/.local/bin:$PATH"
  if ansible_suffisant; then
    ok "Ansible est installé ($(ansible --version | head -n 1))."
    return 0
  fi

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

installer_collections() {
  local essai
  for essai in 1 2 3; do
    ansible-galaxy collection install -r requirements.yml >/dev/null && return 0
    if [[ $essai -lt 3 ]]; then
      attention "Galaxy indisponible, nouvel essai dans $((essai * 10)) s..."
      sleep $((essai * 10))
    fi
  done
  return 1
}

verifier_connexion_ansible() {
  ansible serveurs -m ping >/dev/null 2>&1
}

deployer_serveur_ansible() {
  ansible-playbook site.yml --ask-become-pass
}

deployer_pc_ansible() {
  ansible-playbook pc.yml --ask-become-pass "$@"
}
