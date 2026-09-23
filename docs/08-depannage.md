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

## Partie 2 — Le test sur une machine vierge

Tous les problèmes ci-dessus ont été résolus sur la VM de développement. Pour vérifier que le projet est réellement déployable par quelqu'un d'autre, il a ensuite été déployé **de zéro** sur une VM Debian 13 neuve, depuis un PC Ubuntu, en suivant uniquement le guide. Ce test a révélé une série de défauts invisibles sur la machine de développement, parce qu'ils y avaient été corrigés **à la main** sans être reportés dans Ansible.

### 14. Le coffre de secrets personnel était publié sur GitHub

**Le symptôme.** Sur la machine de test, toute commande Ansible échouait : d'abord « vault password file not found », puis « Decryption failed ».

**La cause.** Le fichier `group_vars/all.yml` (le coffre chiffré avec le mot de passe personnel du développeur) était versionné. Tout nouvel utilisateur récupérait un coffre qu'il ne pouvait pas déchiffrer. Même chose pour `inventory/hosts.yml`, qui contenait l'IP du développeur.

**Un piège dans la correction.** Une première tentative a échoué pour deux raisons : le chemin ajouté dans `ansible/.gitignore` était `ansible/group_vars/all.yml`, alors que les chemins d'un `.gitignore` sont **relatifs à son propre dossier** (il fallait `group_vars/all.yml`) ; et un `git add` sur le fichier juste après le `git rm --cached` l'avait réintégré au commit.

**La résolution.** `git rm --cached` des deux fichiers, chemins corrigés dans le `.gitignore`, vérification avec `git check-ignore -v`. Seuls des modèles `.example` restent versionnés, et chaque utilisateur crée ses propres secrets via `install.sh`.

**La leçon.** Vérifier ce qu'un **clone neuf** contient réellement, et non ce que l'on croit avoir retiré. Le coffre reste dans l'historique Git : il est chiffré, mais les mots de passe qu'il contenait doivent être considérés comme exposés et changés.

### 15. `install.sh` testait la connexion avant de créer le coffre

**Le symptôme.** Sur une machine sans coffre, le script s'arrêtait à « Impossible de joindre le serveur », alors que SSH fonctionnait.

**La cause.** Le test de connexion (étape 4) appelait Ansible, qui a besoin du coffre, créé seulement à l'étape 5. Le message d'erreur masquait en plus la vraie cause.

**La résolution.** Inversion des étapes (secrets, puis test de connexion) et affichage du détail de l'erreur en cas d'échec.

### 16. Le mot de passe du coffre fourni deux fois

**Le symptôme.** À la création d'un coffre neuf : « The vault-ids default,default are available to encrypt ».

**La cause.** Le fichier de mot de passe était déclaré à la fois dans `ansible.cfg` et par l'option `--vault-password-file` du script. Ansible accepte ce doublon pour déchiffrer, mais refuse de choisir pour chiffrer. Le bug n'était jamais apparu, car cette branche du script (création d'un coffre) ne s'exécutait pas sur la machine de développement, où le coffre existait déjà.

**La résolution.** Suppression de l'option en double dans le script.

### 17. Python absent d'une Debian minimale

**La cause.** Presque tous les modules Ansible exigent Python sur la cible.

**La résolution.** Une tâche `pre_tasks` utilisant le module `raw`, le seul qui fonctionne sans Python, installe Python s'il manque.

### 18. Docker Compose : « permission denied » sur le socket Docker

**La cause.** Le rôle `docker` ajoute l'utilisateur au groupe `docker`, mais un changement de groupe ne prend effet qu'à la **connexion suivante**. Les tâches Docker Compose, forcées à s'exécuter avec l'utilisateur (`become: false`), n'avaient donc pas encore les droits.

**La résolution.** Exécution des tâches Docker Compose en root (`become: true`).

### 19. Dossier de destination absent

**Le symptôme.** « Destination directory .../adguard does not exist ».

**La cause.** Ansible crée automatiquement la destination quand il copie un dossier entier, mais pas quand il copie un fichier seul. Sur la machine de développement, le dossier existait déjà.

**La résolution.** Une tâche crée les dossiers AdGuard avant la copie.

### 20. Grafana redémarrait en boucle : permission refusée sur sa configuration

**Le symptôme.** Grafana en état `Restarting`, avec « Datasource provisioning error: permission denied ».

**La cause.** La copie utilisait `mode: preserve`, qui reprend les permissions d'origine des fichiers. Le conteneur Grafana, qui tourne avec un utilisateur non-root, ne pouvait plus lire ses fichiers de provisioning. C'est le même problème que le n°5, qui avait été corrigé à la main au début du projet.

**La résolution.** Permissions explicites dans le rôle : `0644` pour les fichiers, `0755` pour les dossiers (ces fichiers ne contiennent aucun secret ; le `.env` reste en `0600`).

### 21. AdGuard et Grafana démarraient vides

**Le constat.** Le déploiement installait AdGuard sans configuration (assistant d'installation au premier accès) et Grafana sans tableau de bord.

**La résolution.**
- **AdGuard** : un modèle `AdGuardHome.yaml.j2` est rempli par Ansible. Le mot de passe choisi par l'utilisateur est **haché en bcrypt** sur le serveur, et les quatre listes de blocage sont préconfigurées.
- **Grafana** : le tableau de bord Node Exporter est chargé automatiquement par le mécanisme de *provisioning* de Grafana.
- Le **nom du serveur** affiché dans Grafana était écrit en dur dans le `docker-compose.yml`. Il est désormais transmis par une variable remplie par Ansible avec le vrai nom de chaque machine.

### 22. Les alertes ne partaient pas du tout

Deux causes successives, toutes deux liées à des réglages faits à la main sur la machine de développement :

- **`curl` et `jq` absents.** Les scripts d'alerte en ont besoin, et une Debian minimale ne les installe pas. Aucun message d'erreur : les alertes échouaient silencieusement. Ils sont maintenant installés par le rôle `alertes`.
- **Les alertes SSH et sudo n'étaient branchées nulle part.** Elles sont déclenchées par PAM, grâce à deux lignes ajoutées à la main dans `/etc/pam.d/sshd` et `/etc/pam.d/sudo`. Le rôle copiait les scripts sans ajouter ces lignes. Elles sont maintenant ajoutées par `lineinfile`, qui ne les duplique pas si elles existent déjà. L'option `optional` garantit qu'un échec d'alerte ne bloque jamais une connexion.

### 23. Aucun pare-feu sur la machine neuve

**La cause.** ufw avait été configuré à la main au début du projet et n'avait jamais été automatisé.

**La résolution.** Un rôle `parefeu` : tout est refusé en entrée sauf SSH (22) et DNS (53). La règle SSH est ajoutée **avant** l'activation, pour qu'Ansible ne se coupe pas lui-même l'accès. Vérification que la politique `deny (routed)` ne gêne pas les conteneurs Docker, qui gèrent eux-mêmes les règles de leurs réseaux (AdGuard résout toujours les domaines extérieurs).

### 24. L'IP de la VM changeait après un redémarrage

**La cause.** Attribution automatique par DHCP.

**La résolution.** Réservation d'une IP fixe pour l'adresse MAC de chaque VM dans le réseau libvirt (`virsh net-update ... ip-dhcp-host`). Le script propose en plus la dernière IP utilisée lors des lancements suivants.

---

## Ce que ces problèmes ont en commun

La première série venait surtout de **conflits entre couches** (Docker, firewalld, libvirt, ufw) et de **décalages avec une distribution très récente** (Debian 13). Les résoudre a demandé un diagnostic méthodique, du plus bas niveau au plus haut, avec les bons outils : `ping`, `traceroute`, `tcpdump`, `ss`, `nft list`, `cscli explain`, et la lecture des logs.

La seconde série révèle une leçon différente, et sans doute plus importante : **tout ce qui a été corrigé à la main finit par manquer ailleurs**. Python, `curl`, les lignes PAM, les permissions, le pare-feu : sur la machine de développement, tout fonctionnait, parce que ces réglages y avaient été faits au fil de l'eau. Seul un déploiement sur une **machine vierge** les a fait apparaître. Un projet d'infrastructure n'est reproductible que s'il a été testé dans les conditions exactes d'un nouvel utilisateur.

Il reste un écart connu : le reverse proxy **Nginx** et la stack **PostgreSQL** de la VM de développement ont été installés à la main au début du projet et ne sont pas encore automatisés. Ils feront l'objet d'un futur rôle.
