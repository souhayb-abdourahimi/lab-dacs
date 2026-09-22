#!/usr/bin/env bash
#
# install.sh — Déploiement guidé du lab DACS
#
# Ce script prépare la machine de contrôle et déploie tout le lab sur un
# serveur Debian/Ubuntu que vous possédez déjà et qui est accessible en SSH
# par clé. Il ne crée pas le serveur et ne configure pas la clé SSH :
# ces deux étapes sont décrites dans docs/07-deploiement-ansible.md.
#
# Usage : ./install.sh
#
set -euo pipefail

# --- Couleurs pour la lisibilité -------------------------------------------
BLEU="\033[1;34m"; VERT="\033[1;32m"; ROUGE="\033[1;31m"; JAUNE="\033[1;33m"; RAZ="\033[0m"
titre()   { echo -e "\n${BLEU}==> $1${RAZ}"; }
ok()      { echo -e "${VERT}✔ $1${RAZ}"; }
attention(){ echo -e "${JAUNE}⚠ $1${RAZ}"; }
erreur()  { echo -e "${ROUGE}✘ $1${RAZ}" >&2; }

# --- On se place dans le dossier ansible/ ----------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/ansible" || { erreur "Dossier ansible/ introuvable. Lancez ce script depuis la racine du dépôt."; exit 1; }

echo -e "${BLEU}"
echo "  ┌────────────────────────────────────────────┐"
echo "  │        Déploiement du lab DACS               │"
echo "  └────────────────────────────────────────────┘"
echo -e "${RAZ}"
echo "Ce script va préparer Ansible puis déployer le lab sur votre serveur."
echo "Prérequis : un serveur Debian/Ubuntu accessible en SSH par clé."
echo "(Voir docs/07-deploiement-ansible.md si ce n'est pas encore le cas.)"
echo
read -r -p "Continuer ? [o/N] " reponse
[[ "$reponse" =~ ^[oO]$ ]] || { echo "Annulé."; exit 0; }

# --- 1. Vérifier / installer Ansible ---------------------------------------
titre "1/6 — Vérification d'Ansible"
if command -v ansible-playbook >/dev/null 2>&1; then
  ok "Ansible est déjà installé ($(ansible --version | head -1))."
else
  attention "Ansible n'est pas installé."
  if   command -v dnf    >/dev/null 2>&1; then INSTALL="sudo dnf install -y ansible"
  elif command -v apt    >/dev/null 2>&1; then INSTALL="sudo apt update && sudo apt install -y ansible"
  elif command -v pacman >/dev/null 2>&1; then INSTALL="sudo pacman -S --noconfirm ansible"
  else erreur "Gestionnaire de paquets non reconnu. Installez Ansible manuellement, puis relancez."; exit 1; fi
  echo "Commande d'installation : $INSTALL"
  read -r -p "Installer Ansible maintenant ? [o/N] " rep
  [[ "$rep" =~ ^[oO]$ ]] || { erreur "Ansible est requis. Arrêt."; exit 1; }
  eval "$INSTALL"
  ok "Ansible installé."
fi

# --- 2. Collection Docker --------------------------------------------------
titre "2/6 — Collection Ansible pour Docker"
ansible-galaxy collection install community.docker >/dev/null
ok "Collection community.docker prête."

# --- 3. Inventaire (adresse du serveur) ------------------------------------
titre "3/6 — Adresse de votre serveur"
read -r -p "Adresse IP du serveur à configurer : " SERVEUR_IP
read -r -p "Nom d'utilisateur SSH sur le serveur [souhayb] : " SERVEUR_USER
SERVEUR_USER="${SERVEUR_USER:-souhayb}"

mkdir -p inventory
cat > inventory/hosts.yml <<YAML
# Généré par install.sh
serveurs:
  hosts:
    lab-vm:
      ansible_host: ${SERVEUR_IP}
      ansible_user: ${SERVEUR_USER}
      ansible_python_interpreter: /usr/bin/python3
YAML
ok "Inventaire écrit (serveur ${SERVEUR_IP}, utilisateur ${SERVEUR_USER})."

# --- 4. Secrets (coffre Vault) ---------------------------------------------
# IMPORTANT : les secrets sont créés AVANT le test de connexion, car le test
# (comme tout appel Ansible) a besoin du .vault_pass pour déchiffrer le coffre.
titre "4/6 — Vos secrets (chiffrés avec Ansible Vault)"
mkdir -p group_vars
if [[ -f group_vars/all.yml ]] && head -1 group_vars/all.yml | grep -q ANSIBLE_VAULT; then
  ok "Un coffre chiffré existe déjà, il sera réutilisé."
  read -r -s -p "Mot de passe de ce coffre : " VAULT_PASS; echo
  printf '%s' "$VAULT_PASS" > .vault_pass
  chmod 600 .vault_pass
else
  echo "On va créer votre coffre de secrets. Choisissez vos propres valeurs."
  read -r -s -p "Mot de passe admin Grafana : "        GRAFANA_PASS; echo
  read -r -p        "Sujet ntfy (ex: monlab-a1b2c3d4) : " NTFY_TOPIC
  read -r -p        "Identifiant admin AdGuard [admin] : " AG_USER
  AG_USER="${AG_USER:-admin}"
  read -r -s -p "Mot de passe admin AdGuard : "        AG_PASS; echo
  echo
  echo "Choisissez enfin un mot de passe pour PROTÉGER ce coffre."
  echo "(C'est lui qui déchiffrera vos secrets à chaque déploiement — retenez-le.)"
  read -r -s -p "Mot de passe du coffre : "        VAULT_PASS;  echo
  read -r -s -p "Confirmez le mot de passe du coffre : " VAULT_PASS2; echo
  [[ "$VAULT_PASS" == "$VAULT_PASS2" ]] || { erreur "Les mots de passe ne correspondent pas. Arrêt."; exit 1; }

  # Fichier de mot de passe de coffre, conservé en .vault_pass (jamais versionné)
  printf '%s' "$VAULT_PASS" > .vault_pass
  chmod 600 .vault_pass

  # On écrit les secrets en clair puis on chiffre le fichier sur place
  cat > group_vars/all.yml <<YAML
grafana_admin_password: ${GRAFANA_PASS}
ntfy_topic: ${NTFY_TOPIC}
adguard_auth: ${AG_USER}:${AG_PASS}
YAML
  ansible-vault encrypt group_vars/all.yml --vault-password-file .vault_pass >/dev/null
  ok "Coffre créé et chiffré."
fi

# --- 5. Test de connexion SSH ----------------------------------------------
titre "5/6 — Test de connexion au serveur"
if ansible serveurs -m ping --vault-password-file .vault_pass >/dev/null 2>&1; then
  ok "Connexion au serveur réussie."
else
  erreur "Impossible de joindre le serveur en SSH."
  echo "Vérifiez que :"
  echo "  - le serveur est allumé et joignable (ping ${SERVEUR_IP}) ;"
  echo "  - votre clé SSH est installée dessus (ssh ${SERVEUR_USER}@${SERVEUR_IP}) ;"
  echo "  - Python 3 est installé sur le serveur (Ansible en a besoin) ;"
  echo "  - voir la section Dépannage de docs/07-deploiement-ansible.md."
  echo
  echo "Détail de l'erreur :"
  ansible serveurs -m ping --vault-password-file .vault_pass || true
  exit 1
fi

# --- 6. Déploiement --------------------------------------------------------
titre "6/6 — Déploiement du lab"
echo "Ansible va maintenant configurer le serveur. Votre mot de passe SSH (sudo)"
echo "sur le serveur va être demandé (BECOME password)."
echo
ansible-playbook site.yml --ask-become-pass --vault-password-file .vault_pass

echo
ok "Déploiement terminé."
echo -e "${BLEU}Vérifiez le résultat :${RAZ}"
echo "  - Grafana   : tunnel  ssh -L 3000:127.0.0.1:3000 ${SERVEUR_USER}@${SERVEUR_IP}  puis http://localhost:3000"
echo "  - AdGuard   : tunnel  ssh -L 8090:127.0.0.1:8090 ${SERVEUR_USER}@${SERVEUR_IP}  puis http://localhost:8090"
echo "  - CrowdSec  : sur le serveur, sudo cscli metrics"
echo
attention "Le fichier ansible/.vault_pass contient le mot de passe de votre coffre."
attention "Il reste sur CETTE machine et ne doit JAMAIS être envoyé sur Git (déjà dans .gitignore)."
