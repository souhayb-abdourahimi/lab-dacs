# lab-dacs — Serveur Debian auto-hébergé, supervisé et défendu

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
│             │                         │  pare-feu ufw (22, 53)        │
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
- **Exposition de services** → pare-feu ufw : tout est refusé en entrée sauf SSH et DNS ; les interfaces d'administration ne sont joignables que par tunnel SSH.
- **Élévation de privilèges** → root direct interdit, alerte à chaque `sudo`.
- **Sites de phishing / malware** → filtre DNS avec listes mises à jour quotidiennement.
- **Pistage publicitaire** → bloqué au niveau réseau, sans logiciel sur les appareils.
- **Accès physique au poste** (module optionnel) → détection d'intrusion, verrouillage automatique, et photo si l'option webcam est choisie.

Le [modèle de menaces](docs/09-threat-model.md) détaille précisément le périmètre et les limites.

## Stack technique

Debian 13 · Fedora · Ubuntu · KVM/QEMU · libvirt · Ansible (+ Vault) · Docker & Docker Compose · Prometheus · Grafana · node-exporter · CrowdSec · ufw · nftables · AdGuard Home · systemd (services & timers) · PAM · udev · evdev · ffmpeg · ntfy · Bash · Python · Git

## Structure du dépôt

```
lab-dacs/
├── README.md                  ← ce fichier
├── install.sh                 ← déploiement du serveur, en une commande
├── install-pc.sh              ← installation de la détection d'accès sur le PC
├── docs/                      ← documentation détaillée (une page par sujet)
├── ansible/                   ← déploiement automatisé
│   ├── site.yml               ← playbook du serveur
│   ├── pc.yml                 ← playbook du poste de travail
│   ├── roles/                 ← secrets, docker, supervision, adguard,
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

Le déploiement a été validé **de zéro sur une VM Debian 13 vierge**, depuis deux machines de contrôle : **Fedora** et **Ubuntu**. Le test couvre l'installation complète, le filtrage DNS, la supervision, le pare-feu et les trois types d'alertes. Il est prévu pour fonctionner aussi sur Debian 12 et Ubuntu LTS ; les correctifs propres à une distribution (comme le renommage `sshd-session` de Debian 13) sont appliqués automatiquement selon le système détecté.

Ce test sur machine vierge a révélé une dizaine de défauts invisibles sur la machine de développement ; ils sont décrits dans la [partie 2 du journal de dépannage](docs/08-depannage.md).

## Limites connues et suite du projet

- Le reverse proxy **Nginx** et la stack **PostgreSQL** de la VM de développement ont été installés à la main et ne sont pas encore inclus dans le déploiement automatique.

Pistes d'évolution, par ordre de priorité :

1. **Rôle `web`** : automatiser Nginx et PostgreSQL.
2. **Centralisation des journaux hors de la VM** — résister à l'effacement des traces par un attaquant root.
3. **Tests automatisés (CI GitHub Actions)** — valider le déploiement à chaque modification.
4. **Honeypot SSH** et **fichiers leurres** (honeytokens) branchés sur les alertes.

---

*Projet personnel — Souhayb Abdourahimi — [souhayb-abdourahimi.netlify.app](https://souhayb-abdourahimi.netlify.app)*
