# Durcissement SSH

## Objectif

SSH est la porte d'entrée du serveur, donc la cible numéro un. La grande majorité des intrusions commencent par des identifiants volés ou devinés. L'objectif : rendre le mot de passe inutile pour un attaquant, et empêcher l'accès direct au compte root.

## Ce qui a été mis en place

**Connexion par clé uniquement.** Chaque machine (PC, VM) a sa propre paire de clés ED25519. Le serveur n'accepte plus que ces clés : un mot de passe volé ne sert à rien.

```bash
# Sur le serveur, dans /etc/ssh/sshd_config.d/00-cle-uniquement.conf
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
```

Le préfixe `00-` du nom de fichier garantit que ces règles sont lues en premier et prennent le dessus.

**Root interdit en direct.** Un attaquant ne peut plus viser le compte root directement. Il doit d'abord entrer avec un compte normal (et sa clé), puis passer par `sudo` — ce qui déclenche une alerte (voir [04-alertes.md](04-alertes.md)).

**Une clé par machine.** Le PC et la VM ont chacun leur clé. Si l'une est compromise, on la révoque sans toucher à l'autre. C'est le principe du moindre privilège appliqué aux accès.

## Vérification

Le test de non-régression, à faire depuis un nouveau terminal avant de fermer la session en cours (pour ne pas risquer de s'enfermer dehors) :

```bash
ssh -o PubkeyAuthentication=no souhayb@192.168.122.31
# Résultat attendu : Permission denied (publickey)
```

Ce refus prouve que les mots de passe sont bien rejetés.

## Problèmes rencontrés

**Écrasement accidentel d'une clé existante.** En générant une nouvelle clé, j'ai répondu « oui » à la question d'écrasement, remplaçant une clé qui servait déjà. Il a fallu redéclarer la nouvelle clé partout (GitHub, VM). Leçon : `ssh-keygen` prévient avant d'écraser, il faut lire la question `Overwrite (y/n)?` avant de répondre.

**Deux clés sur GitHub.** Le compte avait déjà une clé (celle de la VM). Chaque machine devant avoir la sienne, j'ai ajouté la clé du PC sans supprimer celle de la VM. Avoir une clé par appareil est la bonne pratique, pas un problème.

**GitHub refuse les mots de passe pour `git push`.** Depuis un certain temps, GitHub n'accepte plus l'authentification par mot de passe en ligne de commande. Solution : passer le dépôt en SSH (`git remote set-url origin git@github.com:...`) et s'authentifier avec la clé.

## Le filet de sécurité

La console de la VM (via KVM) reste toujours accessible en secours. Même en cas de mauvaise manipulation SSH, on ne peut pas se retrouver définitivement enfermé dehors. C'est ce qui permet de durcir SSH sans crainte.

## Pistes d'amélioration

- **Protéger la clé privée par une passphrase** systématiquement, pour qu'une clé volée reste inutilisable.
- **Changer le port SSH** ou ajouter du port-knocking pour réduire le bruit des scans automatisés (cosmétique, mais réduit les logs parasites).
- **Authentification à deux facteurs** sur SSH (clé + code TOTP) pour les accès les plus sensibles.
