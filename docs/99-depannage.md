# 99 — Dépannage et reprise d'activité

## Perte du mot de passe root : mode single user

Procédure de récupération via GRUB, applicable lorsqu'aucun accès
administrateur n'est disponible.

1. Au démarrage, interrompre GRUB et appuyer sur `e`
2. Sur la ligne du noyau (`linux …`), remplacer `ro` par :
   ```
   rw init=/bin/bash
   ```
3. Démarrer avec `Ctrl+X`
4. Une fois sur l'invite, réinitialiser :
   ```bash
   passwd root
   passwd souhayb
   ```
5. Redémarrer :
   ```bash
   exec /sbin/init
   ```

Cette manipulation illustre un point de sécurité important : **un accès
physique (ou console) à une machine équivaut à un accès root**, sauf si GRUB
est protégé par mot de passe et le disque chiffré.

## Session SSH coupée après activation du pare-feu

Symptôme : la connexion se ferme et ne se rétablit pas.
Cause : ufw activé sans règle autorisant le port 22.

Correctif, depuis la console virt-manager :

```bash
sudo ufw allow 22/tcp
sudo ufw reload
```

## Connexion par clé refusée après durcissement

```bash
sudo cp /etc/ssh/sshd_config.bak-<horodatage> /etc/ssh/sshd_config
sudo systemctl restart ssh
```

Causes fréquentes : permissions incorrectes sur `~/.ssh` (doit être `700`)
ou sur `authorized_keys` (doit être `600`).

## Docker : permission denied sur le socket

```
Got permission denied while trying to connect to the Docker daemon socket
```

L'utilisateur a été ajouté au groupe `docker` mais la session n'a pas été
renouvelée. Se déconnecter et se reconnecter, puis vérifier avec `id`.

## Nginx ne redémarre pas

```bash
sudo nginx -t                     # affiche la ligne fautive
sudo journalctl -xeu nginx
sudo ss -tulpn | grep :80         # vérifier qu'aucun autre service n'occupe le port
```
