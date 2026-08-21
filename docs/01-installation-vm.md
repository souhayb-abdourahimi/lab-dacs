# 01 — Installation de la machine virtuelle

## Hôte

Fedora Linux avec la pile de virtualisation native :

```bash
sudo dnf install @virtualization virt-manager -y
sudo systemctl enable --now libvirtd
```

## Choix d'installation Debian 13

| Étape | Valeur retenue |
|---|---|
| Nom d'hôte | `debian-dacs-lab` |
| Domaine | *(vide)* |
| Partitionnement | Assisté, disque entier, tout dans une partition |
| Miroir | `deb.debian.org` (France) |
| Environnement de bureau | **décoché** |
| Serveur web | **décoché** (nginx installé manuellement ensuite) |
| Serveur SSH | **coché** |
| Utilitaires standards | **coché** |
| GRUB | Installé sur `/dev/vda` |

Le refus de l'environnement graphique n'est pas un détail : un serveur de
production n'en a pas. Cela réduit la consommation mémoire et la surface d'attaque.

## Vérification post-installation

```bash
hostnamectl
ip a
systemctl is-active ssh
```

## Instantané

Un instantané est pris depuis virt-manager immédiatement après l'installation.
Il permet de revenir à un état sain après toute manipulation destructrice —
condition nécessaire pour expérimenter sans crainte.
