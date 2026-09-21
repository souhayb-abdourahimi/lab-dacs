# lab-dacs — Serveur Debian auto-hébergé, supervisé et défendu

Laboratoire personnel de sécurité et d'administration système, monté dans le cadre de ma préparation au BUT Informatique parcours DACS (Déploiement d'Applications Communicantes et Sécurisées).

L'objectif : partir d'une VM Debian nue et la transformer en un serveur **durci, supervisé et capable de se défendre seul**, avec des alertes en temps réel sur mon téléphone. En complément, un module protège le **poste de travail** lui-même contre un accès physique non autorisé. Tout le serveur se redéploie **en une commande** grâce à Ansible.

> Ce projet est un **laboratoire d'apprentissage**, pas un produit de sécurité certifié ni un EDR commercial. Il démontre des principes et des compétences dans un environnement maîtrisé. Voir le [modèle de menaces](docs/09-threat-model.md) pour ce qu'il protège et ce qu'il ne protège pas.

## Déploiement rapide

```bash
git clone https://github.com/souhayb-abdourahimi/lab-dacs.git
cd lab-dacs
./install.sh
```

Le script installe Ansible au besoin, chiffre vos secrets (Ansible Vault) et déploie tout le serveur. Guide pas-à-pas de A à Z (serveur, application ntfy, clé SSH, dépannage) : **[docs/07-deploiement-ansible.md](docs/07-deploiement-ansible.md)**.

## Vue d'ensemble

```
┌─────────────┐        SSH (clé)        ┌──────────────────────────────┐
│   PC hôte   │ ──────tunnel──────────▶ │      VM Debian 13 (KVM)       │
│  (Fedora)   │                         │                              │
│             │ ──────DNS (53)────────▶ │  ┌────────────────────────┐  │
│  Firefox    │ ◀─────filtrage─────────  │  │ AdGuard Home (Docker)  │  │
│             │                         │  ├────────────────────────┤  │
│  détection  │ ──preuves (scp)───────▶ │  │ Prometheus + Grafana   │  │
│  d'accès    │                         │  │ node-exporter (Docker) │  │
└─────────────┘                         │  ├────────────────────────┤  │
       ▲                                │  │ CrowdSec + bouncer     │  │
       │                                │  │ scripts d'alerte + PAM │  │
       │  notifications ntfy            │  └────────────────────────┘  │
   ┌───┴────┐                           └──────────────────────────────┘
   │ iPhone │ ◀─── alertes du serveur ET du poste de travail
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

Ce lab répond aux modes d'attaque les plus courants contre les particuliers et les petites structures :

- **Identifiants volés** → connexion SSH par clé, alerte à chaque connexion.
- **Attaque par force brute** → CrowdSec détecte et bannit automatiquement.
- **Élévation de privilèges** → root direct interdit, alerte à chaque `sudo`.
- **Sites de phishing / malware** → filtre DNS avec listes mises à jour quotidiennement.
- **Pistage publicitaire** → bloqué au niveau réseau, sans logiciel sur les appareils.
- **Accès physique au poste** → détection d'intrusion, verrouillage automatique, photo.

Le [modèle de menaces](docs/09-threat-model.md) détaille précisément le périmètre et les limites.

## Stack technique

Debian 13 · Fedora · KVM/QEMU · Ansible (+ Vault) · Docker & Docker Compose · Prometheus · Grafana · node-exporter · CrowdSec · nftables · AdGuard Home · systemd (services & timers) · PAM · udev · evdev · ffmpeg · ntfy · Bash · Python · Git

## Structure du dépôt

```
lab-dacs/
├── README.md                  ← ce fichier
├── install.sh                 ← déploiement guidé en une commande
├── docs/                      ← documentation détaillée (une page par sujet)
├── ansible/                   ← déploiement automatisé (rôles, playbook, secrets Vault)
├── supervision/               ← Prometheus + Grafana + node-exporter
├── adguard/                   ← filtre DNS AdGuard Home
├── alertes/                   ← alertes serveur (SSH, sudo, CrowdSec, AdGuard)
│   ├── scripts/
│   ├── systemd/
│   └── lab-alertes.conf.example
└── detection-pc/              ← détection d'accès au poste de travail
    ├── scripts/
    ├── systemd/
    └── udev/
```

## Sécurité des secrets

Aucun secret n'est versionné. Les mots de passe et le sujet de notification sont chiffrés avec **Ansible Vault** (`group_vars/all.yml`, illisible sans la clé de coffre). Le dépôt ne contient que des modèles à valeurs fictives (`all.yml.example`, `lab-alertes.conf.example`). Le mot de passe du coffre (`ansible/.vault_pass`) et les fichiers de secrets générés sur le serveur restent hors de Git.

## Compatibilité

Testé sur **Debian 13**. Le déploiement Ansible est prévu pour fonctionner sur **Debian 12** et **Ubuntu LTS** ; certains correctifs spécifiques (comme le renommage `sshd-session` de Debian 13) sont appliqués conditionnellement selon la distribution détectée.

## Suite du projet

Les pistes d'évolution sont détaillées à la fin de chaque fichier de `docs/` et dans le [modèle de menaces](docs/09-threat-model.md). Par ordre de priorité :

1. **Rôles Ansible adaptatifs** pour Ubuntu et Debian 12 (compatibilité élargie).
2. **Centralisation des journaux hors de la VM** — résister à l'effacement des traces par un attaquant root.
3. **Détection PAM des échecs de connexion** — capturer une tentative avant l'ouverture de session.
4. **Tests automatisés (CI GitHub Actions)** — valider chaque brique après un changement.
5. **Installateur du module détection PC** — un second script, à lancer sur le poste de travail.
6. **Réécriture du moteur de détection en Go** — binaire unique, concurrent, plus difficile à altérer.

---

*Projet personnel — Souhayb Abdourahimi — [souhayb-abdourahimi.netlify.app](https://souhayb-abdourahimi.netlify.app)*
