# Supervision — Prometheus, node-exporter, Loki, Alloy, Grafana

## Objectif

Voir en continu l'état du serveur : processeur, mémoire, disque, réseau. Sans supervision, on ne sait pas qu'un disque se remplit ou qu'un service est surchargé avant la panne. C'est aussi la base de la détection : un comportement anormal (pic de trafic, disque qui se remplit d'un coup) devient visible.

## Comment ça marche

Trois conteneurs Docker qui se passent les données en chaîne :

- **node-exporter** — le capteur. Il mesure en permanence l'état du serveur.
- **Prometheus** — la mémoire. Toutes les 15 secondes, il lit les mesures et les enregistre avec leur historique.
- **Grafana** — l'écran. Il transforme les données de Prometheus en graphiques lisibles.

Le tableau de bord utilisé est le *Node Exporter Full* (ID 1860), une référence de la communauté.

## Journaux et tableau de bord « Sécurité »

Deux conteneurs de plus s'occupent des **journaux** :

- **Alloy** — le collecteur. Il lit le journal systemd du serveur, monté en lecture seule, et l'envoie à Loki.
- **Loki** — l'archive des journaux, conservés 15 jours comme les métriques. Il n'a aucun port publié.

Tout ce qui compte pour la sécurité passe par le journal systemd :

| Événement | Source dans le journal |
| --- | --- |
| Connexion SSH réussie ou échouée | `sshd` (ou `sshd-session`, OpenSSH ≥ 9.8) |
| Utilisation de `sudo` | `sudo` (lignes `COMMAND=`) |
| IP bannie par CrowdSec | `lab-securite`, écrit par `alerte-crowdsec.sh` (`evenement=ip_bannie ip=… raison=…`) |
| Domaine bloqué par AdGuard | `lab-dns`, écrit par `alerte-adguard.sh` (`evenement=domaine_bloque domaine=… liste=…`) |

Grafana affiche le tableau de bord **Sécurité**, provisionné automatiquement (Tableaux de bord → Sécurité). On y trouve :

- les compteurs de la période : connexions SSH, sudo, IP bannies, domaines bloqués ;
- une courbe de tous ces événements dans le temps, échecs SSH compris ;
- le détail des connexions et des commandes sudo ;
- les IP bannies et les domaines bloqués les plus fréquents.

Les pubs et traqueurs bloqués y figurent aussi. En revanche, seuls les sites **dangereux** (phishing, malware) déclenchent une notification ntfy.

Le journal doit être conservé sur disque (`/var/log/journal`). C'est le cas d'origine sur Debian/Ubuntu. Sur Fedora/RHEL, le déploiement crée ce dossier.

## Sécurité

Grafana n'écoute que sur `127.0.0.1:3000` de la VM. On y accède depuis le PC par un tunnel SSH :

```bash
ssh -L 3000:127.0.0.1:3000 souhayb@192.168.122.31
```

Aucune interface d'administration n'est donc exposée sur le réseau.

## Problèmes rencontrés

**Docker contourne le pare-feu ufw.** Piège classique : quand on publie un port avec Docker (`3000:3000`), Docker l'ouvre à tout le monde en insérant sa propre règle, *avant* ufw. Une interface qu'on croit protégée par le pare-feu se retrouve exposée. Solution retenue : lier explicitement le port à `127.0.0.1` (`127.0.0.1:3000:3000`), ce qui empêche toute exposition réseau quel que soit l'état du pare-feu.

**Grafana et Prometheus ne démarraient pas (permission denied).** Les deux conteneurs tournent avec un utilisateur non-root (bonne pratique), mais les fichiers de config, téléchargés puis copiés, n'étaient lisibles que par mon compte. Corrigé en rendant les fichiers de config lisibles par tous (ils ne contiennent aucun secret) :

```bash
chmod -R a+rX prometheus grafana
```

**Les deux fichiers `prometheus.yml` inversés.** Le projet a deux fichiers portant le même nom : la config de Prometheus (`prometheus/prometheus.yml`) et la source de données de Grafana (`grafana/provisioning/datasources/prometheus.yml`). Au téléchargement, leur contenu s'est retrouvé échangé. Prometheus lisait donc une config Grafana (`apiVersion`, `datasources`) qu'il ne comprenait pas, et redémarrait en boucle. Diagnostic par les logs (`docker compose logs prometheus`), qui pointaient la ligne exacte. Leçon : toujours lire les logs d'un conteneur qui redémarre en boucle plutôt que deviner.

**Le nom du serveur affichait un identifiant de conteneur.** Grafana montrait `21ed013bc406` au lieu du nom du serveur. Corrigé en fixant `hostname: debian-dacs-lab` dans le `docker-compose.yml`.

## Pistes d'amélioration

- **Ajouter des alertes Grafana** sur les seuils critiques (disque > 90 %, RAM saturée) reliées à ntfy, pour être prévenu avant la panne.
- **Superviser les conteneurs eux-mêmes** (cAdvisor) et pas seulement la machine hôte.
- **Surveiller le trafic réseau sortant** pour repérer une exfiltration de données : un serveur qui envoie soudain un volume anormal est un signal d'alerte fort.
