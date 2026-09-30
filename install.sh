#!/usr/bin/env bash
#
# install.sh — Déploiement guidé du lab DACS
#
# Ce script prépare la machine de contrôle (Linux avec apt, dnf, pacman ou
# zypper) et déploie tout le lab sur un serveur Debian, Ubuntu, Fedora, Rocky
# ou Alma que vous possédez déjà et qui est accessible en SSH par clé. Il ne crée pas le serveur et ne configure pas la clé SSH :
# ces deux étapes sont décrites dans docs/07-deploiement-ansible.md.
#
# Usage : ./install.sh
#
set -euo pipefail

# --- On se place dans le dossier ansible/ ----------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Fonctions communes (couleurs, yaml_quote, installation d'Ansible...)
# shellcheck source=lib/commun.sh
. "$SCRIPT_DIR/lib/commun.sh"
cd "$SCRIPT_DIR/ansible" || { erreur "Dossier ansible/ introuvable. Lancez ce script depuis la racine du dépôt."; exit 1; }

echo -e "${BLEU}"
echo "  ┌────────────────────────────────────────────┐"
echo "  │        Déploiement du lab DACS               │"
echo "  └────────────────────────────────────────────┘"
echo -e "${RAZ}"
echo "Ce script va préparer Ansible puis déployer le lab sur votre serveur."
echo "Prérequis : un serveur Debian, Ubuntu, Fedora, Rocky ou Alma accessible en SSH par clé."
echo "(Voir docs/07-deploiement-ansible.md si ce n'est pas encore le cas.)"
echo
read -r -p "Continuer ? [o/N] " reponse
[[ "$reponse" =~ ^[oO]$ ]] || { echo "Annulé."; exit 0; }

# --- 1. Vérifier / installer Ansible ---------------------------------------
titre "1/6 — Vérification d'Ansible"
assurer_ansible || exit 1

# --- 2. Collections Ansible ------------------------------------------------
titre "2/6 — Collections Ansible (Docker, pare-feu, SELinux)"
installer_collections
ok "Collections community.docker, community.general et ansible.posix prêtes."

# --- 3. Inventaire (adresse du serveur) ------------------------------------
titre "3/6 — Adresse de votre serveur"
# (la valeur peut être entre apostrophes depuis que l'inventaire est échappé)
ANCIENNE_IP=$(sed -n "s/^ *ansible_host: *'\{0,1\}\([^' ]*\)'\{0,1\} *\$/\1/p" inventory/hosts.yml 2>/dev/null | head -1 || true)
read -r -p "Adresse IP du serveur à configurer${ANCIENNE_IP:+ [$ANCIENNE_IP]} : " SERVEUR_IP
SERVEUR_IP="${SERVEUR_IP:-$ANCIENNE_IP}"
read -r -p "Nom d'utilisateur SSH sur le serveur [souhayb] : " SERVEUR_USER
SERVEUR_USER="${SERVEUR_USER:-souhayb}"

mkdir -p inventory
cat > inventory/hosts.yml <<YAML
# Généré par install.sh
serveurs:
  hosts:
    lab-vm:
      ansible_host: $(yaml_quote "$SERVEUR_IP")
      ansible_user: $(yaml_quote "$SERVEUR_USER")
      ansible_python_interpreter: /usr/bin/python3
YAML
ok "Inventaire écrit (serveur ${SERVEUR_IP}, utilisateur ${SERVEUR_USER})."

# --- Clé d'hôte SSH du serveur ---------------------------------------------
# Ansible vérifie les clés d'hôte (ansible.cfg). Si le serveur est inconnu, on
# affiche son empreinte pour que l'utilisateur la compare (sur le serveur :
# ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub) avant de l'enregistrer.
KNOWN_HOSTS="$HOME/.ssh/known_hosts"
if ssh-keygen -F "$SERVEUR_IP" -f "$KNOWN_HOSTS" >/dev/null 2>&1; then
  ok "Clé d'hôte du serveur déjà connue (~/.ssh/known_hosts)."
else
  CLES_HOTE=$(ssh-keyscan -T 5 -t ed25519,ecdsa,rsa "$SERVEUR_IP" 2>/dev/null || true)
  if [[ -z "$CLES_HOTE" ]]; then
    attention "Impossible de lire la clé d'hôte de ${SERVEUR_IP} (serveur injoignable ?)."
    attention "Elle sera enregistrée à la première connexion (StrictHostKeyChecking=accept-new)."
  else
    echo "Empreinte(s) de la clé d'hôte du serveur ${SERVEUR_IP} :"
    ssh-keygen -lf - <<<"$CLES_HOTE" | sed 's/^/    /'
    echo "Comparez-la avec celle affichée SUR le serveur :"
    echo "    ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub"
    read -r -p "L'empreinte correspond-elle ? [o/N] " rep_cle
    [[ "$rep_cle" =~ ^[oO]$ ]] || { erreur "Clé d'hôte non confirmée. Arrêt."; exit 1; }
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    printf '%s\n' "$CLES_HOTE" >> "$KNOWN_HOSTS"
    chmod 600 "$KNOWN_HOSTS"
    ok "Clé d'hôte ajoutée à ~/.ssh/known_hosts."
  fi
fi

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
  demander_serveur_ntfy
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
  # (umask 077 : le fichier en clair n'est jamais lisible par d'autres comptes)
  (
    umask 077
    {
      printf 'grafana_admin_password: %s\n' "$(yaml_quote "$GRAFANA_PASS")"
      printf 'ntfy_serveur: %s\n'           "$(yaml_quote "$NTFY_SERVEUR")"
      printf 'ntfy_topic: %s\n'             "$(yaml_quote "$NTFY_TOPIC")"
      printf 'adguard_auth: %s\n'           "$(yaml_quote "${AG_USER}:${AG_PASS}")"
    } > group_vars/all.yml
  )
  ansible-vault encrypt group_vars/all.yml >/dev/null
  ok "Coffre créé et chiffré."
fi

# --- 5. Test de connexion SSH ----------------------------------------------
titre "5/6 — Test de connexion au serveur"
if ansible serveurs -m ping >/dev/null 2>&1; then
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
  ansible serveurs -m ping || true
  exit 1
fi

# --- 6. Déploiement --------------------------------------------------------
titre "6/6 — Déploiement du lab"
echo "Ansible va maintenant configurer le serveur. Votre mot de passe SSH (sudo)"
echo "sur le serveur va être demandé (BECOME password)."
echo
ansible-playbook site.yml --ask-become-pass

echo
ok "Déploiement terminé."
echo -e "${BLEU}Vérifiez le résultat :${RAZ}"
echo "  - Grafana   : tunnel  ssh -L 3000:127.0.0.1:3000 ${SERVEUR_USER}@${SERVEUR_IP}  puis http://localhost:3000"
echo "  - AdGuard   : tunnel  ssh -L 8090:127.0.0.1:8090 ${SERVEUR_USER}@${SERVEUR_IP}  puis http://localhost:8090"
echo "  - CrowdSec  : sur le serveur, sudo cscli metrics"
echo
attention "Le fichier ansible/.vault_pass contient le mot de passe de votre coffre."
attention "Il reste sur CETTE machine et ne doit JAMAIS être envoyé sur Git (déjà dans .gitignore)."
