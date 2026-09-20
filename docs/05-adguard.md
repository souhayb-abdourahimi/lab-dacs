# Filtre DNS — AdGuard Home

## Objectif

Bloquer les sites d'arnaque (phishing, malware) et le pistage publicitaire pour **tout le PC**, au niveau du réseau, sans installer de logiciel sur chaque appareil. C'est la protection la plus efficace contre les faux SMS et les liens piégés : même en cliquant, le site ne se charge pas.

## Comment ça marche

Le PC utilise la VM comme **serveur DNS**. Avant de contacter un site, le PC demande son adresse à AdGuard. Si le domaine figure dans une liste de sites dangereux, AdGuard refuse de le résoudre : le site devient inaccessible. Tout est enregistré dans un journal consultable.

Les listes de blocage utilisées :

| Liste | Rôle |
|-------|------|
| AdGuard DNS filter | pubs et traqueurs (par défaut) |
| Phishing Army | sites d'hameçonnage |
| HaGeZi Multi PRO | malwares, arnaques, traqueurs |
| URLhaus | domaines hébergeant des malwares |

Au total, plus de 560 000 règles, mises à jour automatiquement.

## Branchement du PC

Le DNS du PC est réglé sur la VM en principal, avec un DNS public en secours :

```bash
nmcli connection modify "<wifi>" ipv4.ignore-auto-dns yes
nmcli connection modify "<wifi>" ipv4.dns "192.168.122.31 9.9.9.9"
nmcli connection up "<wifi>"
```

`192.168.122.31` = le filtre (VM), `9.9.9.9` = Quad9 en secours si la VM est éteinte.

## Sécurité

L'interface d'administration n'écoute que sur `127.0.0.1` de la VM, accessible par tunnel SSH uniquement. Seul le port DNS (53) est ouvert sur le réseau, pour que le PC puisse l'interroger. Les données de fonctionnement (`work/`, `conf/`) sont exclues de Git via `.gitignore` : elles contiennent la config générée et les journaux.

## Problèmes rencontrés

**Port 53 réputé occupé.** Sous Debian, le port DNS est souvent pris par `systemd-resolved`. Sur cette VM, le service n'était pas installé, le port était donc libre. À noter pour un autre déploiement où il faudrait le libérer.

**Résolution DNS cassée de la VM.** En manipulant `/etc/resolv.conf`, un lien symbolique a pointé vers un fichier inexistant : la VM ne résolvait plus aucun nom. Corrigé en réécrivant un `resolv.conf` simple pointant vers la passerelle. Leçon : `/etc/resolv.conf` est critique, toute manipulation doit être testée par un `ping` immédiat.

**Port 8080 déjà pris.** AdGuard ne démarrait pas : le port 8080 était occupé par l'interface web locale de **CrowdSec**. Diagnostic avec `ss -tlpn`, puis déplacement de l'admin AdGuard sur 8090. Bon rappel : toujours vérifier les ports déjà utilisés avant d'en attribuer.

**Faux tests de blocage.** Les premiers domaines de test (`test.phishing.army`) apparaissaient « Traité » et non « Bloqué » : ils n'étaient dans aucune liste, ils renvoyaient juste une réponse vide. Solution : créer une règle de filtrage personnelle (`||exemple-arnaque-test.com^`) pour un test 100 % fiable, vérifié dans le journal des requêtes.

## Limites connues

- **Le VPN de navigateur et le DNS-over-HTTPS de Firefox contournent le filtre.** Tant qu'ils sont actifs, les requêtes ne passent pas par AdGuard. Il faut les désactiver pour être réellement protégé — un point à connaître, car beaucoup d'utilisateurs l'ignorent.
- **Faux positifs possibles.** Un site légitime peut être bloqué par erreur par une liste. On le débloque dans le journal des requêtes d'AdGuard. C'est le prix d'un filtrage large.
- **Dépendance à la VM.** Si la VM tombe, le secours Quad9 prend le relais mais la bascule n'est pas instantanée.

## Pistes d'amélioration

- **Protéger aussi le téléphone** en configurant le DNS chiffré (DoT/DoH) d'AdGuard sur mobile, y compris en dehors du réseau local (nécessite d'exposer le service de façon sécurisée).
- **Statistiques de blocage dans Grafana**, pour un tableau de bord unique.
- **Résolveur récursif (Unbound)** en amont d'AdGuard, pour ne plus dépendre d'un DNS public et gagner en confidentialité.
