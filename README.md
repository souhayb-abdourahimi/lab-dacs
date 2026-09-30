# lab-dacs — Serveur Debian auto-hébergé, supervisé et défendu

[![lint](https://github.com/souhayb-abdourahimi/lab-dacs/actions/workflows/lint.yml/badge.svg)](https://github.com/souhayb-abdourahimi/lab-dacs/actions/workflows/lint.yml)
[![molecule](https://github.com/souhayb-abdourahimi/lab-dacs/actions/workflows/molecule.yml/badge.svg)](https://github.com/souhayb-abdourahimi/lab-dacs/actions/workflows/molecule.yml)

Laboratoire personnel de sécurité et d'administration système, monté dans le cadre de ma préparation au BUT Informatique parcours DACS (Déploiement d'Applications Communicantes et Sécurisées).

L'objectif : partir d'une VM Debian nue et la transformer en un serveur **durci, supervisé et capable de se défendre seul**, avec des alertes en temps réel sur mon téléphone. En complément, un module protège le **poste de travail** lui-même contre un accès physique non autorisé. Tout le serveur se redéploie **en une commande** grâce à Ansible, et il est **directement utilisable** à la fin du déploiement.

> Ce projet est un **laboratoire d'apprentissage**, pas un produit de sécurité certifié ni un EDR commercial. Voir le [modèle de menaces](docs/09-threat-model.md) pour ce qu'il protège et ce qu'il ne protège pas.

## Déploiement rapide

```bash
git clone https://github.com/souhayb-abdourahimi/lab-dacs.git
cd lab-dacs
./install.sh
```

Le script installe Ansible au besoin, vous fait choisir vos propres identifiants, les chiffre (Ansible Vault) et déploie tout le serveur. À la fin, Grafana affiche déjà ses graphiques, AdGuard est déjà configuré avec ses listes de blocage, le pare-feu est actif et les alertes arrivent sur votre téléphone.

**En option**, vous pouvez aussi protéger votre **poste de travail** contre un accès physique en votre absence (alerte au déverrouillage, alerte USB, verrouillage automatique). Lancez `./install-pc.sh` sur ce PC : voir [docs/06-detection-pc.md](docs/06-detection-pc.md). Ce module est indépendant du serveur.

> **Webcam : un bonus facultatif.** Le module peut aussi photographier la personne devant le PC lors d'une intrusion. Cette option est **refusée par défaut** : l'installateur la propose à part, avec ses avertissements. Même installée, la photo reste désactivée tant que vous ne l'autorisez pas avec `photo-on`. Filmer quelqu'un est encadré par la loi : à réserver à un ordinateur qui vous appartient.

Guide pas-à-pas de A à Z (création de la VM, application ntfy, clé SSH, vérifications, dépannage) : **[docs/07-deploiement-ansible.md](docs/07-deploiement-ansible.md)**.

## Vue d'ensemble

```
┌─────────────┐        SSH (clé)        ┌──────────────────────────────┐
│   PC hôte   │ ──────tunnel──────────▶ │      VM Debian 13 (KVM)       │
│             │                         │  ufw/firewalld (22, 53)      │
│             │ ──────DNS (53)────────▶ │  ┌────────────────────────┐  │
│  navigateur │ ◀─────filtrage─────────  │  │ AdGuard Home (Docker)  │  │
│             │                         │  ├────────────────────────┤  │
│  détection  │ ──preuves (scp)───────▶ │  │ Prometheus + Grafana   │  │
│  d'accès    │                         │  │ node-exporter (Docker) │  │
└─────────────┘                         │  ├────────────────────────┤  │
       ▲                                │  │ CrowdSec + bouncer     │  │
       │                                │  │ scripts d'alerte + PAM │  │
       │  notifications ntfy            │  └────────────────────────┘  │
   ┌───┴────┐                           └──────────────────────────────┘
   │ mobile │ ◀─── alertes du serveur ET du poste de travail
   └────────┘
```

## Documentation

| Document | Contenu |
|----------|---------|
| [00 — Architecture](docs/00-architecture.md) | Choix techniques et schéma réseau |
| [01 — Supervision](docs/01-supervision.md) | Prometheus, node-exporter, Grafana |
| [02 — Durcissement SSH](docs/02-ssh.md) | Connexion par clé, root interdit |
| [03 — CrowdSec](docs/03-crowdsec.md) | Détection et blocage des attaques |
| [04 — Alertes ntfy](docs/04-alertes.md) | Notifications temps réel sur mobile |
| [05 — Filtre DNS](docs/05-adguard.md) | Blocage arnaques et pistage (AdGuard) |
| [06 — Détection d'accès au PC](docs/06-detection-pc.md) | Protection du poste de travail |
| [07 — Déploiement Ansible](docs/07-deploiement-ansible.md) | Guide de A à Z, en une commande |
| [08 — Journal de dépannage](docs/08-depannage.md) | Tous les problèmes rencontrés et résolus |
| [09 — Modèle de menaces](docs/09-threat-model.md) | Ce que le lab protège et ne protège pas |

## Menaces couvertes

- **Identifiants volés** → connexion SSH par clé uniquement, alerte à chaque connexion.
- **Attaque par force brute** → CrowdSec détecte et bannit automatiquement, avec alerte.
- **Exposition de services** → pare-feu (ufw ou firewalld) : tout est refusé en entrée sauf SSH et DNS ; les interfaces d'administration ne sont joignables que par tunnel SSH.
- **Élévation de privilèges** → root direct interdit, alerte à chaque `sudo`.
- **Sites de phishing / malware** → filtre DNS avec listes mises à jour quotidiennement.
- **Pistage publicitaire** → bloqué au niveau réseau, sans logiciel sur les appareils.
- **Accès physique au poste** (module optionnel) → détection d'intrusion, verrouillage automatique, et photo si l'option webcam est choisie.

Le [modèle de menaces](docs/09-threat-model.md) détaille précisément le périmètre et les limites.

## Stack technique

Debian · Ubuntu · Fedora · Rocky/Alma · Arch · openSUSE · KVM/QEMU · libvirt · Ansible (+ Vault) · Docker & Docker Compose · Prometheus · Grafana · node-exporter · CrowdSec · ufw · firewalld · SELinux · nftables · AdGuard Home · systemd (services & timers) · PAM · udev · evdev · ffmpeg · ntfy · Bash · Python · Git

## Structure du dépôt

```
lab-dacs/
├── README.md                  ← ce fichier
├── install.sh                 ← déploiement du serveur, en une commande
├── install-pc.sh              ← installation de la détection d'accès sur le PC
├── Makefile                   ← make lint / test / deploy / pc
├── lib/commun.sh              ← fonctions partagées (Ansible, paquets, YAML)
├── docs/                      ← documentation détaillée (une page par sujet)
├── ansible/                   ← déploiement automatisé
│   ├── site.yml               ← playbook du serveur
│   ├── pc.yml                 ← playbook du poste de travail
│   ├── requirements.yml       ← collections Ansible nécessaires
│   ├── molecule/              ← tests d'intégration (Molecule + Docker)
│   ├── roles/                 ← secrets, selinux, docker, supervision, adguard,
│   │                             alertes, parefeu, crowdsec, ssh,
│   │                             detection_pc
│   ├── group_vars/            ← all.yml.example (modèle de secrets)
│   └── inventory/             ← hosts.yml.example (modèle d'inventaire)
├── supervision/               ← Prometheus + Grafana + node-exporter
├── adguard/                   ← filtre DNS AdGuard Home
├── alertes/                   ← alertes serveur (SSH, sudo, CrowdSec, AdGuard)
└── detection-pc/              ← détection d'accès au poste de travail
```

## Sécurité des secrets

Aucun secret n'est versionné. Chaque utilisateur choisit ses propres identifiants pendant `install.sh` ; ils sont chiffrés avec **Ansible Vault** dans un coffre qui reste sur sa machine. Le dépôt ne contient que des modèles à valeurs fictives (`all.yml.example`, `hosts.yml.example`, `lab-alertes.conf.example`). Le mot de passe du coffre, le coffre lui-même et l'inventaire sont exclus de Git par `ansible/.gitignore`.

## Compatibilité et tests

Légende : ✅ validé sur machine réelle · 🟢 pris en charge (tâches dédiées, syntaxe vérifiée, pas encore validé sur machine réelle) · ❌ non pris en charge.

> Les validations ✅ datent d'avant la fiabilisation et la portabilité (sessions 1 et 2) : elles sont à refaire sur ces cibles.

### Serveur cible (`install.sh` → `site.yml`)

| Distribution | Statut | Docker + Compose v2 | Pare-feu | CrowdSec + bouncer | SELinux | Service SSH |
|---|---|---|---|---|---|---|
| Debian 13 | ✅ | `docker.io` + `docker-compose` (v2) | ufw | paquets Debian | — | `ssh` |
| Debian 12 | 🟢 | `docker.io` + plugin officiel (empreinte vérifiée) | ufw | paquets Debian | — | `ssh` |
| Ubuntu 24.04 | 🟢 | `docker.io` + `docker-compose-v2` | ufw | paquets Ubuntu | — | `ssh` |
| Ubuntu 22.04 | 🟢 | `docker.io` + `docker-compose-v2` | ufw | dépôt officiel CrowdSec (bouncer iptables) | — | `ssh` |
| Fedora (40+) | 🟢 | `moby-engine` + `docker-compose` | firewalld | dépôt officiel CrowdSec (bouncer nftables) | contextes `container_file_t` | `sshd` |
| Rocky Linux / AlmaLinux 9 | 🟢 | Docker CE (dépôt officiel Docker) | firewalld | dépôt officiel CrowdSec (bouncer nftables) | contextes `container_file_t` | `sshd` |
| Autres (Alpine, Arch, openSUSE…) | ❌ | | | | | |

Détails :

- **CrowdSec** : les paquets de la distribution sont utilisés quand elle fournit à la fois `crowdsec` et `crowdsec-firewall-bouncer`. Sinon, le rôle déclare le dépôt officiel (packagecloud). `crowdsec_forcer_depot_officiel: true` force ce dépôt partout.
- **SELinux** n'est jamais désactivé. Quand il est actif, le dossier du lab reçoit le contexte `container_file_t`, et node-exporter tourne avec `label=disable` pour lire le système hôte.
- **OpenSSH ≥ 9.8** (Debian 13, Fedora 41+) : le correctif CrowdSec `sshd-session` s'applique automatiquement dès que le binaire est détecté.
- **Rocky/Alma** : le paquet `podman-docker` doit être retiré avant le déploiement ; le rôle s'arrête avec un message clair s'il est présent.

### Machine de contrôle (`install.sh`, `install-pc.sh`)

| Gestionnaire de paquets | Distributions | ansible-core de la distribution |
|---|---|---|
| `apt` | Debian, Ubuntu, Mint | Debian 13, Ubuntu 24.04 : suffisant · Debian 12, Ubuntu 22.04 : trop ancien → pipx |
| `dnf` | Fedora, Rocky, Alma | Fedora : suffisant · EL 9 : trop ancien → pipx (ou venv) avec Python ≥ 3.10 |
| `pacman` | Arch, Manjaro, EndeavourOS | suffisant |
| `zypper` | openSUSE Tumbleweed / Leap | Tumbleweed : suffisant · Leap : selon version → pipx |

Il faut **ansible-core ≥ 2.16**. Si la distribution fournit une version plus ancienne, les scripts proposent d'installer une version récente pour votre compte seulement, avec **pipx** (dans `~/.local/bin`) ou, à défaut, dans un environnement virtuel Python. Les collections nécessaires sont listées dans [`ansible/requirements.yml`](ansible/requirements.yml). Les scripts n'utilisent que bash et des options POSIX (pas de `grep -P`), et shellcheck les vérifie en CI.

### Module poste de travail (`install-pc.sh` → `pc.yml`)

| | GNOME | KDE Plasma | Autre bureau |
|---|---|---|---|
| Alertes verrouillage / déverrouillage | ✅ `org.gnome.ScreenSaver` | 🟢 `org.freedesktop.ScreenSaver` | ❌ (avertissement) |
| Alerte USB, détection d'activité | ✅ | 🟢 | 🟢 |

Distributions : Fedora, Debian, Ubuntu (prises en charge d'origine), Arch Linux 🟢 (`pacman`), openSUSE Tumbleweed/Leap 🟢 (`zypper`). Les systèmes immuables (Fedora Silverblue/Kinoite, openSUSE MicroOS/Aeon) sont refusés.

### Tests automatiques (CI)

À chaque push, GitHub Actions lance :

- **lint** : shellcheck, yamllint, ansible-lint (profil *production*) et ruff (lint et format du Python) ;
- **molecule** : `site.yml` déployé dans un conteneur systemd sur **Debian 12, Debian 13, Ubuntu 24.04 et Rocky 9**. Un second passage doit afficher **0 changed** (idempotence). Viennent ensuite des vérifications fonctionnelles : Grafana répond sur `127.0.0.1:3000`, AdGuard répond au DNS sur le port 53, CrowdSec et son bouncer sont actifs, la connexion root et les mots de passe sont refusés par sshd, les timers d'alerte tournent.

En conteneur, le pare-feu n'est pas appliqué et sshd n'est pas redémarré (variable `lab_test_conteneur`). La configuration SSH est tout de même validée (`sshd -t`) et vérifiée (`sshd -T`).

En local (Docker requis) :

```bash
make deps                 # outils de développement (requirements-dev.txt)
make lint                 # analyse statique
make test                 # Molecule sur Debian 12
make test DISTRO=rocky9   # ... ou debian13, ubuntu2404
make deploy               # redéploie le serveur après un premier ./install.sh
make pc                   # détection d'accès sur ce poste
```

### Historique des tests

Le déploiement a été validé **de zéro sur une VM Debian 13 vierge**, depuis deux machines de contrôle : **Fedora** et **Ubuntu**. Le test couvre l'installation complète, le filtrage DNS, la supervision, le pare-feu et les trois types d'alertes. Ce test sur machine vierge a révélé une dizaine de défauts invisibles sur la machine de développement ; ils sont décrits dans la [partie 2 du journal de dépannage](docs/08-depannage.md).

## Limites connues et suite du projet

- Le reverse proxy **Nginx** et la stack **PostgreSQL** de la VM de développement ont été installés à la main et ne sont pas encore inclus dans le déploiement automatique.

Pistes d'évolution, par ordre de priorité :

1. **Rôle `web`** : automatiser Nginx et PostgreSQL.
2. **Centralisation des journaux hors de la VM** — résister à l'effacement des traces par un attaquant root.
3. **Honeypot SSH** et **fichiers leurres** (honeytokens) branchés sur les alertes.

---

*Projet personnel — Souhayb Abdourahimi — [souhayb-abdourahimi.netlify.app](https://souhayb-abdourahimi.netlify.app)*
