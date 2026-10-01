# shellcheck shell=bash
# Étapes de l'installateur serveur. Aucune logique Ansible interne n'est modifiée.
set -euo pipefail

afficher_intro_serveur() {
  echo -e "${BLEU}"
  echo "  ┌────────────────────────────────────────────┐"
  echo "  │        Déploiement du lab DACS               │"
  echo "  └────────────────────────────────────────────┘"
  echo -e "${RAZ}"
  echo "Ce script va préparer Ansible puis déployer le lab sur votre serveur."
  echo "Prérequis : un serveur Debian, Ubuntu, Fedora, Rocky ou Alma accessible en SSH par clé."
  echo "(Voir docs/07-deploiement-ansible.md si ce n'est pas encore le cas.)"
  echo
}

preparer_ansible_serveur() {
  titre "1/6 — Vérification d'Ansible"
  assurer_ansible
  titre "2/6 — Collections Ansible (Docker, pare-feu, SELinux)"
  installer_collections
  ok "Collections community.docker, community.general et ansible.posix prêtes."
}

configurer_inventaire_serveur() {
  local ancienne_ip
  titre "3/6 — Adresse de votre serveur"
  ancienne_ip=$(sed -n "s/^ *ansible_host: *'\{0,1\}\([^' ]*\)'\{0,1\} *\$/\1/p" inventory/hosts.yml 2>/dev/null | head -1 || true)
  read -r -p "Adresse IP du serveur à configurer${ancienne_ip:+ [$ancienne_ip]} : " SERVEUR_IP
  SERVEUR_IP="${SERVEUR_IP:-$ancienne_ip}"
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
}

valider_cle_hote_serveur() {
  local known_hosts cles_hote rep_cle
  known_hosts="$HOME/.ssh/known_hosts"
  if ssh-keygen -F "$SERVEUR_IP" -f "$known_hosts" >/dev/null 2>&1; then
    ok "Clé d'hôte du serveur déjà connue (~/.ssh/known_hosts)."
    return 0
  fi
  cles_hote=$(ssh-keyscan -T 5 -t ed25519,ecdsa,rsa "$SERVEUR_IP" 2>/dev/null || true)
  if [[ -z "$cles_hote" ]]; then
    attention "Impossible de lire la clé d'hôte de ${SERVEUR_IP} (serveur injoignable ?)."
    attention "Elle sera enregistrée à la première connexion (StrictHostKeyChecking=accept-new)."
    return 0
  fi
  echo "Empreinte(s) de la clé d'hôte du serveur ${SERVEUR_IP} :"
  ssh-keygen -lf - <<<"$cles_hote" | sed 's/^/    /'
  echo "Comparez-la avec celle affichée SUR le serveur :"
  echo "    ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub"
  read -r -p "L'empreinte correspond-elle ? [o/N] " rep_cle
  [[ "$rep_cle" =~ ^[oO]$ ]] || { erreur "Clé d'hôte non confirmée. Arrêt."; return 1; }
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  printf '%s\n' "$cles_hote" >> "$known_hosts"
  chmod 600 "$known_hosts"
  ok "Clé d'hôte ajoutée à ~/.ssh/known_hosts."
}

preparer_coffre_serveur() {
  local vault_pass vault_pass2 grafana_pass ntfy_topic ag_user ag_pass
  titre "4/6 — Vos secrets (chiffrés avec Ansible Vault)"
  mkdir -p group_vars
  if [[ -f group_vars/all.yml ]] && head -1 group_vars/all.yml | grep -q ANSIBLE_VAULT; then
    ok "Un coffre chiffré existe déjà, il sera réutilisé."
    read -r -s -p "Mot de passe de ce coffre : " vault_pass; echo
    printf '%s' "$vault_pass" > .vault_pass
    chmod 600 .vault_pass
    return 0
  fi
  echo "On va créer votre coffre de secrets. Choisissez vos propres valeurs."
  read -r -s -p "Mot de passe admin Grafana : " grafana_pass; echo
  demander_serveur_ntfy
  read -r -p "Sujet ntfy (ex: monlab-a1b2c3d4) : " ntfy_topic
  read -r -p "Identifiant admin AdGuard [admin] : " ag_user
  ag_user="${ag_user:-admin}"
  read -r -s -p "Mot de passe admin AdGuard : " ag_pass; echo
  echo
  echo "Choisissez enfin un mot de passe pour PROTÉGER ce coffre."
  echo "(C'est lui qui déchiffrera vos secrets à chaque déploiement — retenez-le.)"
  read -r -s -p "Mot de passe du coffre : " vault_pass; echo
  read -r -s -p "Confirmez le mot de passe du coffre : " vault_pass2; echo
  [[ "$vault_pass" == "$vault_pass2" ]] || { erreur "Les mots de passe ne correspondent pas. Arrêt."; return 1; }
  printf '%s' "$vault_pass" > .vault_pass
  chmod 600 .vault_pass
  (
    umask 077
    {
      printf 'grafana_admin_password: %s\n' "$(yaml_quote "$grafana_pass")"
      printf 'ntfy_serveur: %s\n' "$(yaml_quote "$NTFY_SERVEUR")"
      printf 'ntfy_topic: %s\n' "$(yaml_quote "$ntfy_topic")"
      printf 'adguard_auth: %s\n' "$(yaml_quote "${ag_user}:${ag_pass}")"
    } > group_vars/all.yml
  )
  ansible-vault encrypt group_vars/all.yml >/dev/null
  ok "Coffre créé et chiffré."
}

verifier_connexion_serveur() {
  titre "5/6 — Test de connexion au serveur"
  if verifier_connexion_ansible; then ok "Connexion au serveur réussie."; return 0; fi
  erreur "Impossible de joindre le serveur en SSH."
  echo "Vérifiez que :"
  echo "  - le serveur est allumé et joignable (ping ${SERVEUR_IP}) ;"
  echo "  - votre clé SSH est installée dessus (ssh ${SERVEUR_USER}@${SERVEUR_IP}) ;"
  echo "  - Python 3 est installé sur le serveur (Ansible en a besoin) ;"
  echo "  - voir la section Dépannage de docs/07-deploiement-ansible.md."
  echo
  echo "Détail de l'erreur :"
  ansible serveurs -m ping || true
  return 1
}

deployer_serveur() {
  titre "6/6 — Déploiement du lab"
  echo "Ansible va maintenant configurer le serveur. Votre mot de passe SSH (sudo)"
  echo "sur le serveur va être demandé (BECOME password)."
  echo
  deployer_serveur_ansible
}

afficher_fin_serveur() {
  echo
  ok "Déploiement terminé."
  echo -e "${BLEU}Vérifiez le résultat :${RAZ}"
  echo "  - Grafana   : tunnel  ssh -L 3000:127.0.0.1:3000 ${SERVEUR_USER}@${SERVEUR_IP}  puis http://localhost:3000"
  echo "  - AdGuard   : tunnel  ssh -L 8090:127.0.0.1:8090 ${SERVEUR_USER}@${SERVEUR_IP}  puis http://localhost:8090"
  echo "  - CrowdSec  : sur le serveur, sudo cscli metrics"
  echo
  attention "Le fichier ansible/.vault_pass contient le mot de passe de votre coffre."
  attention "Il reste sur CETTE machine et ne doit JAMAIS être envoyé sur Git (déjà dans .gitignore)."
}
