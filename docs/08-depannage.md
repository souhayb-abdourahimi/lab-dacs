# Journal de dépannage

Ce document rassemble les problèmes réels rencontrés pendant la construction du lab et leur résolution. Chacun est raconté avec le symptôme, la cause et le correctif, parce que la façon dont un problème est diagnostiqué en dit plus long qu'une installation qui marche du premier coup.

---

## 1. Docker sur l'hôte bloquait tout le réseau de la VM

**Le symptôme.** La VM ne pouvait pas accéder à internet. Le PC hôte, lui, y accédait sans problème. La VM joignait sa passerelle (`ping 192.168.122.1` répondait), mais aucun paquet ne ressortait vers internet.

**La traque.** Le diagnostic s'est fait de bas en haut :
- `ping 1.1.1.1` depuis la VM → 100 % de perte.
- `traceroute` → le paquet atteignait le PC hôte (hop 1) puis mourait (hop 2 = `* * *`). Le blocage était donc sur l'hôte.
- `tcpdump -i wlp2s0` sur l'hôte pendant un ping de la VM → **0 paquet capturé** sur le wifi. Le paquet était jeté avant même d'atteindre la carte wifi.
- Inspection des règles : `nft list chain ip filter FORWARD` → la chaîne avait `policy drop`.

**La cause.** Docker, installé sur le PC hôte, configure au démarrage une chaîne `FORWARD` avec une politique par défaut à **drop**. Cette chaîne intercepte le trafic *transféré* (le forwarding) avec une priorité qui passe avant firewalld. Résultat : même si firewalld autorisait le trafic de la VM, la chaîne Docker le jetait en amont. Pire, cette chaîne **survivait à l'arrêt de Docker** : désactiver le service ne suffisait pas, sa règle nftables restait en place.

**La résolution.**

```bash
# Remettre la policy de la chaine FORWARD a accept
sudo nft chain ip filter FORWARD '{ policy accept; }'
```

Pour rendre le correctif permanent, un service systemd le réapplique à chaque démarrage (`fix-forward.service`), car la chaîne peut être recréée par Docker Desktop.

**La leçon.** Deux outils qui gèrent le même pare-feu (Docker et libvirt/firewalld) peuvent se neutraliser sans avertissement. Et une règle nftables peut persister après l'arrêt du service qui l'a créée. Le diagnostic de bas en haut (ping → traceroute → tcpdump → inspection des règles) a permis de localiser précisément où le paquet mourait, au lieu de deviner.

---

## 2. Faux problème : le wifi de l'IUT (eduroam)

**Le symptôme.** Pendant une session à l'IUT, plus rien ne marchait côté réseau VM, et même le PC semblait limité.

**La cause.** Le réseau eduroam de l'établissement filtre beaucoup de trafic : partage de connexion vers une VM, forwarding, et parfois le ping sortant. Ce n'était pas un problème du lab.

**La leçon, et la plus importante de toutes.** Avant de suspecter sa propre configuration, **toujours vérifier la connectivité de base** : est-ce que le PC lui-même a internet (`ping 1.1.1.1`) ? Beaucoup de temps a été perdu à débuguer le NAT alors que le réseau de l'IUT bloquait en amont. De retour sur un wifi personnel, le vrai problème (la chaîne FORWARD de Docker) est réapparu, isolé.

---

## 3. Clavier QWERTY / AZERTY sur la console de la VM

**Le symptôme.** Les premières connexions à la console de la VM échouaient sur le mot de passe, alors qu'il était correct.

**La cause.** La VM était en QWERTY et le PC en AZERTY. Les mêmes touches physiques produisaient des caractères différents (les chiffres notamment, qui demandent Maj en AZERTY).

**La résolution.** `sudo loadkeys fr` pour la session, puis `sudo dpkg-reconfigure keyboard-configuration` pour rendre le choix permanent.

---

## 4. Docker contourne le pare-feu ufw (exposition involontaire)

**Le piège.** En publiant un port avec Docker (`3000:3000`), Docker l'ouvre à tout le monde en insérant sa propre règle *avant* ufw. Une interface qu'on croit protégée par le pare-feu se retrouve exposée sur le réseau.

**La résolution.** Lier explicitement les ports d'administration à `127.0.0.1` (`127.0.0.1:3000:3000`). L'accès se fait alors uniquement par tunnel SSH, quel que soit l'état du pare-feu.

---

## 5. Grafana et Prometheus : permission denied

**Le symptôme.** Les conteneurs Grafana et Prometheus redémarraient en boucle.

**La cause.** Ils tournent avec un utilisateur non-root (bonne pratique), mais les fichiers de config copiés n'étaient lisibles que par le compte utilisateur.

**La résolution.** `chmod -R a+rX prometheus grafana` (ces fichiers ne contiennent aucun secret).

---

## 6. Les deux fichiers `prometheus.yml` inversés

**Le symptôme.** Prometheus redémarrait en boucle avec une erreur `field apiVersion not found`.

**La cause.** Le projet a deux fichiers du même nom : la config Prometheus et la source de données Grafana. Leur contenu s'était retrouvé échangé. Prometheus lisait une config Grafana qu'il ne comprenait pas.

**La résolution.** Réécrire le bon contenu dans `prometheus/prometheus.yml`. Diagnostic par `docker compose logs prometheus`, qui pointait la ligne exacte. Leçon : lire les logs d'un conteneur qui redémarre en boucle plutôt que deviner.

---

## 7. CrowdSec : dépôt tiers cassé bloquant apt

**Le symptôme.** `apt update` échouait à cause du dépôt CrowdSec (`does not have a Release file`), ce qui bloquait toute installation, y compris via Ansible.

**La cause.** Le dépôt tiers de CrowdSec ne fournissait pas de fichier de signature valide pour Debian 13.

**La résolution.** Désactiver le dépôt en le renommant avec une extension invalide, et utiliser la version de CrowdSec empaquetée par Debian elle-même. Le playbook Ansible installe directement la version Debian, sans ce dépôt problématique — il est donc plus propre que l'installation manuelle initiale.

---

## 8. Conflit entre Docker officiel et Docker Debian

**Le symptôme.** L'installation Ansible de Docker échouait avec `trying to overwrite ... also in package docker-buildx`.

**La cause.** La VM avait le Docker de Debian (`docker.io`), et le rôle tentait d'installer le Docker officiel (`docker-ce`). Les deux se marchaient dessus sur les mêmes fichiers.

**La résolution.** Aligner le rôle sur ce qui marche déjà : installer la version Debian (`docker.io` + `docker-compose`). Leçon : un playbook doit refléter l'état voulu réel, pas imposer une version différente de l'existant.

---

## 9. Port 8080 déjà occupé par CrowdSec

**Le symptôme.** AdGuard ne démarrait pas : `address already in use` sur le port 8080.

**La cause.** CrowdSec utilise déjà le port 8080 pour son interface locale.

**La résolution.** Déplacer l'admin AdGuard sur 8090. Diagnostic avec `ss -tlpn | grep :8080`. Réflexe : toujours vérifier les ports occupés avant d'en attribuer.

---

## 10. AdGuard muselé par ufw dans la VM

**Le symptôme.** AdGuard tournait mais ne résolvait aucun vrai domaine ; le DNS timeout, même en interrogeant `127.0.0.1`.

**La cause.** ufw, dans la VM, n'autorisait que les ports 22 et 80 en entrée. Le port **53 (DNS)** était bloqué. AdGuard ne recevait donc aucune requête.

**La résolution.** `sudo ufw allow 53/tcp` et `sudo ufw allow 53/udp`. Ce diagnostic a été révélé par les tests réels : sans tester, on aurait cru AdGuard fonctionnel alors qu'il était bloqué.

---

## 11. CrowdSec ne détectait pas les attaques SSH sur Debian 13

**Le symptôme.** CrowdSec lisait bien les logs SSH (`cscli metrics` : 72 lignes lues), mais toutes en **« unparsed »** (non analysées). Aucune attaque n'était donc détectée.

**La traque.** L'outil `cscli explain` a montré l'arbre de traitement d'une ligne de log : le parser SSH (`crowdsecurity/sshd-logs`) ne reconnaissait pas la ligne. En lisant le parser officiel, son filtre était `evt.Parsed.program == 'sshd'`. Or les logs de Debian 13 montraient un programme nommé **`sshd-session`**, pas `sshd`.

**La cause.** Debian 13 a renommé le processus SSH de `sshd` en `sshd-session`. Le parser CrowdSec, qui cherche `sshd`, ne reconnaissait donc plus les logs. C'est un décalage entre une distribution très récente et l'outil.

**La résolution.** Un parser correctif qui renomme `sshd-session` en `sshd`, placé au début de l'étape `s01-parse` (préfixe `aaa-` pour passer avant le parser SSH) :

```yaml
filter: "evt.Parsed.program == 'sshd-session'"
name: debian13/sshd-session-rename
statics:
  - parsed: program
    value: sshd
```

Point clé : le correctif devait s'exécuter **après** que le champ `program` soit rempli (étape s01), pas dans l'étape s00 où il était initialement placé et où il ne matchait pas.

**Validation.** `cscli explain` a ensuite montré tout l'arbre en vert, y compris les 4 scénarios `ssh-bf`. Un test réel (attaque par force brute depuis le PC, après retrait temporaire de la liste blanche) a déclenché un vrai bannissement, confirmé par « 2 decision(s) deleted » au nettoyage, et l'alerte est arrivée sur le téléphone.

**Automatisation.** Le correctif est intégré au rôle Ansible avec une condition `when` : il ne s'applique que sur Debian 13 et supérieur. Sur Debian 12 ou Ubuntu, où le processus s'appelle encore `sshd`, la tâche est automatiquement sautée.

---

## 12. Le DNS de la VM pointait vers le PC hôte

**Le symptôme.** La VM ne résolvait aucun nom de domaine.

**La cause.** Le `/etc/resolv.conf` de la VM pointait vers `192.168.122.1` (le PC hôte), qui n'est pas un serveur DNS.

**La résolution.** Une fois AdGuard fonctionnel, pointer la VM vers elle-même (`nameserver 127.0.0.1`). Attention : une manipulation antérieure du `resolv.conf` (lien symbolique cassé) avait complètement coupé la résolution ; ce fichier est critique et toute modification doit être testée immédiatement par un `ping`.

---

## 13. Boucle de verrouillage infinie (détection PC)

Traitée en détail dans [06-detection-pc.md](06-detection-pc.md) : au déverrouillage, le mouvement de souris pour taper le mot de passe était détecté comme une intrusion et reverrouillait aussitôt. Résolu par le désarmement automatique de la vigilance au déverrouillage, et le découplage armement-en-attente / armement-au-verrouillage.

---

## Ce que ces problèmes ont en commun

La plupart ne venaient pas d'une erreur de configuration simple, mais de **conflits entre couches** (Docker vs firewalld vs libvirt vs ufw) ou de **décalages avec une distribution très récente** (Debian 13 : dépôt CrowdSec, renommage sshd-session). Les résoudre a demandé de diagnostiquer méthodiquement, du plus bas niveau au plus haut, avec les bons outils : `ping`, `traceroute`, `tcpdump`, `ss`, `nft list`, `cscli explain`, et la lecture des logs. C'est cette démarche, plus que chaque correctif individuel, qui constitue la vraie compétence.
