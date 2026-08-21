# Lab DACS — Infrastructure de préparation BUT 2 Informatique

Laboratoire personnel de virtualisation, d'administration système et de déploiement
conteneurisé, monté en préparation de la 2ᵉ année de BUT Informatique,
parcours **DACS** (Déploiement d'Applications Communicantes et Sécurisées),
IUT de Montpellier-Sète.

Ce dépôt documente l'ensemble des manipulations : chaque étape est reproductible
à partir des commandes et des fichiers de configuration versionnés ici.

---

## Architecture

```
┌──────────────────────────────────────────────┐
│  HÔTE — Fedora Linux                         │
│  Hyperviseur KVM / QEMU (libvirt)            │
│                                              │
│   ┌────────────────────────────────────┐     │
│   │  VM — debian-dacs-lab              │     │
│   │  Debian 13 (Trixie), sans GUI      │     │
│   │  192.168.122.31/24                 │     │
│   │                                    │     │
│   │   nginx : 80      docker : engine  │     │
│   │   ufw   : filtre  sshd   : 22      │     │
│   └────────────────────────────────────┘     │
│              réseau NAT libvirt (virbr0)     │
└──────────────────────────────────────────────┘
```

| Composant | Choix | Justification |
|---|---|---|
| Hyperviseur | KVM/QEMU + virt-manager | Virtualisation native Linux, sans surcouche |
| Système invité | Debian 13 netinst, sans interface graphique | Configuration proche d'un serveur de production |
| Réseau | NAT libvirt (`virbr0`) | Isolation de la VM tout en gardant l'accès sortant |
| Administration | SSH par clé ED25519 | Suppression de l'authentification par mot de passe |
| Filtrage | ufw (frontal nftables) | Politique de moindre exposition |
| Conteneurisation | Docker + Docker Compose | Déploiement d'applications communicantes |

---

## Contenu du dépôt

```
lab-dacs/
├── README.md                      Ce document
├── docs/
│   ├── 01-installation-vm.md      Installation de la VM Debian
│   ├── 02-acces-et-privileges.md  SSH, sudo, gestion des comptes
│   ├── 03-securisation.md         Clés SSH, durcissement sshd, ufw
│   ├── 04-services-web.md         Nginx, virtual hosts, HTTPS
│   ├── 05-conteneurisation.md     Docker et Docker Compose
│   └── 99-depannage.md            Mode single user, reprise d'activité
├── scripts/
│   ├── bootstrap.sh               Installation de la stack de base
│   ├── harden-ssh.sh              Durcissement du service SSH
│   ├── firewall.sh                Règles ufw
│   └── healthcheck.sh             Rapport d'état du serveur
├── configs/
│   └── nginx/
│       └── lab.conf               Virtual host de démonstration
└── docker/
    └── web-stack/
        ├── docker-compose.yml     Nginx + PostgreSQL
        └── .env.example           Variables d'environnement
```

---

## Mise en route

```bash
git clone <url-du-depot> && cd lab-dacs
chmod +x scripts/*.sh
sudo ./scripts/bootstrap.sh      # stack de base
sudo ./scripts/firewall.sh       # ufw (autorise SSH avant activation)
sudo ./scripts/harden-ssh.sh     # à lancer après avoir déposé sa clé publique
./scripts/healthcheck.sh         # vérification
```

> **Avertissement** — `firewall.sh` autorise explicitement le port 22 **avant**
> d'activer ufw. Activer le pare-feu sans cette règle coupe la session SSH en cours
> et impose de repasser par la console de l'hyperviseur.

---

## Vérifications

| Contrôle | Commande | Attendu |
|---|---|---|
| Services actifs | `systemctl is-active ssh nginx docker` | `active` ×3 |
| Règles de filtrage | `sudo ufw status verbose` | 22 et 80 ouverts, reste refusé |
| Docker sans sudo | `docker run --rm hello-world` | Message de bienvenue |
| Ports en écoute | `sudo ss -tulpn` | Aucun port inattendu |
| Surface exposée | `nmap 192.168.122.31` (depuis l'hôte) | 22 et 80 uniquement |
| SSH par clé | `ssh -o PasswordAuthentication=no souhayb@…` | Connexion acceptée |

---

## Compétences BUT couvertes

**C3 — Administrer des systèmes communicants**
Installation et configuration d'un serveur, gestion des comptes et des privilèges,
services systemd, filtrage réseau, administration à distance sécurisée.

**C1 — Développer des applications communicantes**
Déploiement d'un service web, reverse proxy, orchestration multi-conteneurs.

**C2 — Optimiser**
Système sans interface graphique, conteneurisation, réduction de la surface d'attaque.

---

## Journal

| Date | Étape |
|---|---|
| 2026-08 | Installation de l'hyperviseur et de la VM Debian 13 |
| 2026-08 | Récupération d'accès via GRUB (mode single user) |
| 2026-08 | Administration à distance en SSH, mise en place de sudo |
| 2026-08 | Installation de la stack : git, curl, nmap, ufw, nginx, Docker |
| 2026-08 | Validation de Docker (`hello-world`) sans élévation de privilèges |

---

**Souhayb Abdourahimi** — BUT 2 Informatique, parcours DACS — IUT de Montpellier-Sète
