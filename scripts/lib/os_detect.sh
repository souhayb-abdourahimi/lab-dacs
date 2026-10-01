# shellcheck shell=bash
# Détection de l'environnement local et installation de paquets.
set -euo pipefail

# Affiche le gestionnaire de paquets de cette machine (vide si inconnu).
gestionnaire_paquets() {
  local g
  for g in apt-get dnf pacman zypper; do
    if command -v "$g" >/dev/null 2>&1; then
      [[ "$g" == apt-get ]] && g=apt
      echo "$g"
      return 0
    fi
  done
  echo ""
}

installer_paquets() {
  case "$(gestionnaire_paquets)" in
    apt)    sudo apt-get update && sudo apt-get install -y "$@" ;;
    dnf)    sudo dnf install -y "$@" ;;
    # -Syu : Arch ne prend pas en charge les mises à jour partielles.
    pacman) sudo pacman -Syu --needed --noconfirm "$@" ;;
    zypper) sudo zypper --non-interactive install "$@" ;;
    *)      return 1 ;;
  esac
}

# Affiche un interpréteur Python >= 3.10.
python_recent() {
  local py
  for py in python3 python3.13 python3.12 python3.11 python3.10; do
    if command -v "$py" >/dev/null 2>&1 \
       && "$py" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; then
      command -v "$py"
      return 0
    fi
  done
  return 1
}
