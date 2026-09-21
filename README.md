# lab-dacs — Serveur Debian auto-hébergé, supervisé et défendu

Laboratoire personnel de sécurité et d'administration système, monté dans le cadre de ma préparation au BUT Informatique parcours DACS (Déploiement d'Applications Communicantes et Sécurisées).

L'objectif : partir d'une VM Debian nue et la transformer en un serveur **durci, supervisé et capable de se défendre seul**, avec des alertes en temps réel sur mon téléphone. En complément, un module protège le **poste de travail** lui-même contre un accès physique non autorisé. Tout le serveur se redéploie **en une commande** grâce à Ansible.

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

## Ce qui tourne aujourd'hui

| Brique | Rôle | Détail |
|--------|------|--------|
| **Architecture** | Choix techniques et schéma réseau | [docs/00-architecture.md](docs/00-architecture.md) |
| **Supervision** | Voir l'état du serveur en continu | [docs/01-supervision.md](docs/01-supervision.md) |
| **Durcissement SSH** | Connexion par clé uniquement, root interdit | [docs/02-ssh.md](docs/02-ssh.md) |
| **CrowdSec** | Détecter et bloquer les attaques | [docs/03-crowdsec.md](docs/03-crowdsec.md) |
| **Alertes ntfy** | Être prévenu en temps réel sur mobile | [docs/04-alertes.md](docs/04-alertes.md) |
| **Filtre DNS** | Bloquer les sites d'arnaque et le pistage | [docs/05-adguard.md](docs/05-adguard.md) |
| **Détection d'accès au PC** | Protéger le poste contre un accès physique | [docs/06-detection-pc.md](docs/06-detection-pc.md) |
| **Déploiement Ansible** | Tout redéployer en une commande | [docs/07-deploiement-ansible.md](docs/07-deploiement-ansible.md) |

## Menaces couvertes

Ce lab répond aux modes d'attaque les plus courants contre les particuliers et les petites structures :

- **Identifiants volés** → connexion SSH par clé, alerte à chaque connexion.
- **Attaque par force brute** → CrowdSec détecte et bannit automatiquement.
- **Élévation de privilèges** → root direct interdit, alerte à chaque `sudo`.
- **Sites de phishing / malware** → filtre DNS avec listes mises à jour quotidiennement.
- **Pistage publicitaire** → bloqué au niveau réseau, sans logiciel sur les appareils.
- **Accès physique au poste** → détection d'intrusion, verrouillage automatique, photo de l'intrus.

## Stack technique

Debian 13 · Fedora · KVM/QEMU · Ansible (+ Vault) · Docker & Docker Compose · Prometheus · Grafana · node-exporter · CrowdSec · nftables · AdGuard Home · systemd (services & timers) · PAM · udev · evdev · ffmpeg · ntfy · Bash · Python · Git

## Structure du dépôt

```
lab-dacs/
├── README.md                  ← ce fichier
├── install.sh                 ← déploiement guidé en une commande
├── docs/                      ← documentation détaillée (une page par brique)
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

## Suite du projet

Les pistes d'évolution sont détaillées à la fin de chaque fichier de `docs/`. Les grandes lignes, par ordre de priorité :

1. **Installateur du module détection PC** — un second script, à lancer sur le poste de travail.
2. **Détection PAM des échecs de connexion** — capturer une tentative avant même l'ouverture de session.
3. **Surveillance réseau en mode vigilance** — détecter une attaque ARP ou un scan de ports pendant l'absence (mode alerte).
4. **Centralisation des journaux hors de la VM** — résister à l'effacement des traces par un attaquant root.
5. **Réécriture du moteur de détection en Go** — binaire unique, concurrent, plus difficile à altérer.
6. **Vitrine sur le portfolio** — compteur d'attaques bloquées, capture Grafana, lien vers ce dépôt.

---

*Projet personnel — Souhayb Abdourahimi — [souhayb-abdourahimi.netlify.app](https://souhayb-abdourahimi.netlify.app)*
