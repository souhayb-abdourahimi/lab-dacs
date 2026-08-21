# 03 — Sécurisation du serveur

## Ordre des opérations

L'ordre est impératif. Activer le pare-feu avant d'autoriser SSH, ou couper
l'authentification par mot de passe avant d'avoir déposé une clé, coupe l'accès
au serveur et impose de repasser par la console de l'hyperviseur.

1. Générer et déposer la clé publique
2. Vérifier que la connexion par clé fonctionne
3. Durcir la configuration SSH
4. Autoriser SSH dans ufw
5. Activer ufw

## Clés SSH

Depuis l'**hôte** :

```bash
ssh-keygen -t ed25519 -C "souhayb@fedora"
ssh-copy-id souhayb@192.168.122.31
ssh -o PasswordAuthentication=no souhayb@192.168.122.31   # doit réussir
```

ED25519 est préféré à RSA : clés plus courtes, vérification plus rapide,
robustesse au moins équivalente.

## Durcissement de sshd

Directives appliquées dans `/etc/ssh/sshd_config` :

| Directive | Valeur | Effet |
|---|---|---|
| `PermitRootLogin` | `no` | Interdit la connexion directe en root |
| `PasswordAuthentication` | `no` | Élimine les attaques par force brute |
| `PubkeyAuthentication` | `yes` | Authentification par clé uniquement |
| `MaxAuthTries` | `3` | Limite les tentatives par connexion |
| `X11Forwarding` | `no` | Supprime une fonction inutile sur un serveur |
| `ClientAliveInterval` | `300` | Ferme les sessions inactives |

```bash
sudo sshd -t                    # valider la syntaxe AVANT de redémarrer
sudo systemctl restart ssh
```

> Garder la session en cours ouverte et tester la reconnexion dans un
> **second terminal**. En cas d'échec, restaurer la sauvegarde.

## Pare-feu

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 22/tcp           # AVANT enable
sudo ufw allow 80/tcp
sudo ufw enable
sudo ufw status verbose
```

`limit` plutôt que `allow` sur le port 22 : ufw bloque temporairement une IP
qui multiplie les tentatives de connexion.

## Contrôle de la surface exposée

Depuis l'hôte :

```bash
nmap 192.168.122.31
```

Seuls les ports 22 et 80 doivent apparaître ouverts.
