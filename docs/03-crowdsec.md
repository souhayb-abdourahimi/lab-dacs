# CrowdSec — Détection et blocage des attaques

## Objectif

Détecter automatiquement les comportements d'attaque (force brute SSH, scans) et bloquer les adresses IP responsables, sans intervention manuelle. C'est la défense active du serveur.

## Comment ça marche

Deux pièces complémentaires :

- **CrowdSec** — le détecteur. Il lit les journaux du serveur (connexions SSH, requêtes web), reconnaît les schémas d'attaque grâce à des scénarios, et décide de bannir une IP.
- **Le firewall-bouncer** — le videur. Quand CrowdSec décide un bannissement, le bouncer l'applique concrètement dans le pare-feu (nftables).

En bonus, CrowdSec partage les IP détectées avec la communauté : le serveur bloque aussi préventivement des adresses ayant attaqué d'autres serveurs ailleurs.

## Vérification

```bash
sudo cscli metrics          # journaux lus par CrowdSec
sudo cscli bouncers list    # le bouncer doit être présent et valide
```

Test d'un bannissement de bout en bout :

```bash
sudo cscli decisions add --ip 203.0.113.10 --reason "test"
sleep 15                                          # laisser le bouncer se synchroniser
sudo nft list ruleset | grep 203.0.113.10         # l'IP doit apparaître dans le pare-feu
sudo cscli decisions delete --ip 203.0.113.10
```

Quand l'IP apparaît dans nftables avec un compte à rebours, toute la chaîne est prouvée : CrowdSec décide, le bouncer bloque.

## Problèmes rencontrés

**Liste de paquets périmée (erreurs 404).** L'installation échouait parce qu'apt cherchait d'anciennes versions de `gpg` remplacées sur les serveurs Debian. Réflexe corrigé : toujours `sudo apt update` avant une installation.

**Le paquet du bouncer introuvable.** Le dépôt officiel de CrowdSec ne proposait pas encore tous ses paquets pour Debian 13 (récent). Solution : utiliser la version empaquetée par Debian elle-même (`crowdsec-firewall-bouncer`), vérifiée avec `apt-cache search crowdsec`.

**CrowdSec ne lisait pas les logs SSH.** Sur Debian 13, les connexions SSH ne sont plus écrites dans un fichier `/var/log/auth.log` mais dans le journal système (journald). Il a fallu déclarer explicitement cette source dans `/etc/crowdsec/acquis.yaml` :

```yaml
source: journalctl
journalctl_filter:
  - "_SYSTEMD_UNIT=ssh.service"
labels:
  type: syslog
```

**Collections « tainted ».** Après mise à jour d'une collection seule, elle apparaissait « tainted » (modifiée localement), puis c'était la collection parente. Résolu en mettant tout à jour d'un coup (`cscli hub upgrade --force`).

## Limite importante à connaître

Tant que le serveur n'est **pas exposé sur internet**, il ne subit quasiment aucune attaque réelle : CrowdSec est prêt mais ne bannit personne. Les vraies statistiques n'apparaîtront que le jour où le serveur sera accessible publiquement. C'est un choix assumé pour un lab : on valide le mécanisme sans prendre le risque d'exposer la machine.

## Pistes d'amélioration

- **Exposer le serveur** (de façon contrôlée, ports minimaux) pour observer de vraies attaques et alimenter le tableau de bord — à faire seulement une fois le durcissement complet.
- **Ajouter des scénarios web** si un service HTTP est publié (détection d'injections, scans de vulnérabilités).
- **Visualiser les bannissements dans Grafana** à côté des métriques système, pour une vue unifiée.
