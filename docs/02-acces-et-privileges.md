# 02 — Accès distant et gestion des privilèges

## Première connexion SSH

```bash
ssh souhayb@192.168.122.31
```

Au premier contact, le client demande de valider l'empreinte du serveur :

```
ED25519 key fingerprint is SHA256:BEPd1zlEw75OUa17CxzNYNOVX4YdGfPVvRcci9QE+68.
Are you sure you want to continue connecting (yes/no)?
```

Ce mécanisme (*Trust On First Use*) protège contre l'usurpation du serveur :
l'empreinte est mémorisée dans `~/.ssh/known_hosts` et toute modification
ultérieure déclenchera un avertissement.

## Installation de sudo

Sur une Debian minimale où un mot de passe root a été défini, `sudo` n'est pas
installé par défaut. Il faut donc passer par root :

```bash
su -
apt update
apt install sudo -y
usermod -aG sudo souhayb
exit
```

L'appartenance à un groupe n'est évaluée qu'à l'ouverture de session :
**une reconnexion est nécessaire** pour que l'ajout prenne effet.

## Principe retenu

Le compte root n'est plus utilisé directement. L'administration se fait depuis
un compte standard avec élévation ponctuelle via `sudo` — application du
principe de moindre privilège.

## Vérification

```bash
id souhayb          # doit lister les groupes sudo et docker
sudo -v             # valide l'accès sudo
```
