# lab-dacs — Serveur Debian auto-hébergé, supervisé et défendu

Laboratoire personnel de sécurité et d'administration système, monté dans le cadre de ma préparation au BUT Informatique parcours DACS (Déploiement d'Applications Communicantes et Sécurisées).

L'objectif : partir d'une VM Debian nue et la transformer en un serveur **durci, supervisé et capable de se défendre seul**, avec des alertes en temps réel sur mon téléphone. Chaque brique répond à une menace réelle, documentée dans le dossier [`docs/`](docs/).

## Vue d'ensemble

```
┌─────────────┐        SSH (clé)        ┌──────────────────────────────┐
│   PC hôte   │ ──────tunnel──────────▶ │      VM Debian 13 (KVM)       │
│  (Fedora)   │                         │                              │
│             │ ──────DNS (53)────────▶ │  ┌────────────────────────┐  │
│  Firefox    │ ◀─────filtrage─────────  │  │ AdGuard Home (Docker)  │  │
└─────────────┘                         │  ├────────────────────────┤  │
       ▲                                │  │ Prometheus + Grafana   │  │
       │                                │  │ node-exporter (Docker) │  │
       │  notifications ntfy            │  ├────────────────────────┤  │
   ┌───┴────┐                           │  │ CrowdSec + bouncer     │  │
   │ iPhone │ ◀───────────────────────── │  │ scripts d'alerte + PAM │  │
   └────────┘                           │  └────────────────────────┘  │
                                        └──────────────────────────────┘
```

## Ce qui tourne aujourd'hui

| Brique | Rôle | Détail |
|--------|------|--------|
| **Supervision** | Voir l'état du serveur en continu | [docs/01-supervision.md](docs/01-supervision.md) |
| **Durcissement SSH** | Connexion par clé uniquement, root interdit | [docs/02-ssh.md](docs/02-ssh.md) |
| **CrowdSec** | Détecter et bloquer les attaques | [docs/03-crowdsec.md](docs/03-crowdsec.md) |
| **Alertes ntfy** | Être prévenu en temps réel sur mobile | [docs/04-alertes.md](docs/04-alertes.md) |
| **Filtre DNS** | Bloquer les sites d'arnaque et le pistage | [docs/05-adguard.md](docs/05-adguard.md) |
| **Architecture** | Choix techniques et schéma réseau | [docs/00-architecture.md](docs/00-architecture.md) |

## Menaces couvertes

Ce lab répond aux modes d'attaque les plus courants contre les particuliers et les petites structures :

- **Identifiants volés** → connexion SSH par clé, alerte à chaque connexion.
- **Attaque par force brute** → CrowdSec détecte et bannit automatiquement.
- **Élévation de privilèges** → root direct interdit, alerte à chaque `sudo`.
- **Sites de phishing / malware** → filtre DNS avec listes mises à jour quotidiennement.
- **Pistage publicitaire** → bloqué au niveau réseau, sans logiciel sur les appareils.

## Stack technique

Debian 13 · KVM/QEMU · Docker & Docker Compose · Prometheus · Grafana · node-exporter · CrowdSec · nftables · AdGuard Home · systemd (services & timers) · PAM · ntfy · Bash · Git

## Structure du dépôt

```
lab-dacs/
├── README.md                  ← ce fichier
├── docs/                      ← documentation détaillée
├── supervision/               ← Prometheus + Grafana + node-exporter
├── adguard/                   ← filtre DNS AdGuard Home
└── alertes/                   ← scripts d'alerte + timers systemd
    ├── scripts/
    ├── systemd/
    └── lab-alertes.conf.example
```

## Sécurité des secrets

Aucun secret n'est versionné. Les sujets de notification et mots de passe vivent dans `/etc/lab-alertes.conf` sur le serveur (permissions `600`, jamais dans Git). Le dépôt ne contient qu'un modèle `lab-alertes.conf.example` avec des valeurs fictives.

## Suite du projet

Les pistes d'évolution sont détaillées à la fin de chaque fichier de `docs/`. Les grandes lignes :

- Vitrine du projet sur mon portfolio (compteur d'attaques bloquées, capture Grafana).
- Détection d'accès physique non autorisé au poste de travail.
- Centralisation des journaux hors de la VM (résistance à l'effacement des traces).
- Reconstruction automatisée du lab avec Ansible.

---

*Projet personnel — Souhayb Abdourahimi — [souhayb-abdourahimi.netlify.app](https://souhayb-abdourahimi.netlify.app)*
