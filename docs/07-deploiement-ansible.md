# Guide de déploiement — de zéro à un lab complet

Ce guide explique comment déployer le lab de A à Z, sans rien supposer connu. À la fin, vous aurez un serveur supervisé, durci et défendu, **directement utilisable** : Grafana affiche déjà ses graphiques, AdGuard est déjà configuré avec ses listes de blocage, le pare-feu est actif et les alertes arrivent sur votre téléphone.

> Avant de commencer, lisez le [modèle de menaces](09-threat-model.md) : il précise ce que le lab protège, ce qu'il ne protège pas, et ses limites. C'est un laboratoire d'apprentissage, pas un produit de sécurité certifié.

## Ce que contient le projet

Le dépôt réunit **deux choses distinctes** :

1. **Le serveur** (supervision, pare-feu, CrowdSec, AdGuard, alertes, durcissement SSH). Il se déploie automatiquement avec Ansible, via le script `install.sh`. C'est l'objet de ce guide.
2. **La détection d'accès au poste de travail** (dossier `detection-pc/`). Ces scripts tournent sur votre machine physique, pas sur le serveur, et s'installent séparément — voir [06-detection-pc.md](06-detection-pc.md).

## Ce qui est testé

Le déploiement a été validé **de zéro**, sur une VM **Debian 13** vierge, depuis deux machines de contrôle différentes : **Fedora** et **Ubuntu**. Le test couvre l'installation, le filtrage DNS, la supervision, le pare-feu et les trois types d'alertes (SSH, sudo, CrowdSec). Il est prévu pour fonctionner aussi sur un serveur Debian 12 ou Ubuntu LTS.

## Vue d'ensemble des étapes

1. Obtenir un serveur Debian ou Ubuntu.
2. Préparer votre téléphone (application ntfy).
3. Préparer votre clé SSH et la copier sur le serveur.
4. Récupérer le projet et lancer `install.sh`.
5. Vérifier que tout fonctionne.

---

## Étape 1 — Obtenir un serveur

Il vous faut un serveur **Debian 12/13 ou Ubuntu LTS**, accessible en SSH. Deux façons de l'obtenir :

**Option A — une machine virtuelle sur votre PC (gratuit).** Avec virt-manager (KVM), VirtualBox ou GNOME Boxes. Si votre PC est sous Ubuntu et que rien n'est encore installé, suivez l'[annexe A](#annexe-a--créer-la-vm-sous-ubuntu-avec-virt-manager). À l'installation de Debian :
- choisissez le **clavier français** (sinon vos mots de passe seront mal saisis) ;
- laissez le **mot de passe root vide** : votre utilisateur sera alors automatiquement ajouté à `sudo` ;
- à l'écran **Sélection des logiciels**, **décochez** « environnement de bureau » et « GNOME », **cochez** « serveur SSH » ;
- installez **GRUB** sur le disque principal (répondez **Oui**, sinon la VM ne démarrera pas).

Une fois la VM démarrée, notez son adresse IP avec `ip -br a`.

> Sous VirtualBox, mettez la carte réseau en mode **Accès par pont** (Bridged), sinon la machine de contrôle ne pourra pas joindre la VM en SSH.

> L'adresse IP d'une VM peut **changer** après un redémarrage (attribution automatique par DHCP). Pour l'éviter, fixez-la : voir l'[annexe A, étape 6](#6-fixer-lip-de-la-vm).

**Option B — un serveur chez un hébergeur (quelques euros/mois).** Un petit VPS arrive déjà installé et accessible en SSH.

À la fin de cette étape, vous devez connaître : **l'adresse IP du serveur** et **le nom d'utilisateur** pour vous y connecter.

---

## Étape 2 — Préparer votre téléphone (ntfy)

Les alertes du serveur arrivent via **ntfy**, une application de notifications gratuite.

ntfy fonctionne comme une chaîne de radio : le serveur **émet** sur un **sujet**, et tous les téléphones **abonnés** à ce sujet reçoivent les messages. Les alertes ne sont donc pas liées à un téléphone précis, mais au nom du sujet.

1. Installez l'application **ntfy** depuis l'App Store (iPhone) ou le Play Store (Android).
2. Choisissez un sujet **impossible à deviner**, car toute personne qui connaît son nom peut lire vos alertes. Générez-en un sur votre PC :

   ```bash
   echo "monlab-$(openssl rand -hex 4)"
   ```

   **Notez-le**, il servira à l'étape 4.
3. Dans l'application ntfy, appuyez sur **+**, collez ce sujet, laissez le serveur par défaut (`ntfy.sh`), et validez. Autorisez les notifications.

> Ne publiez jamais ce sujet (ni sur GitHub, ni sur une capture d'écran). C'est un secret.

---

## Étape 3 — Préparer la clé SSH

Ansible se connecte au serveur par clé SSH, pas par mot de passe. Cette étape n'est volontairement pas automatisée.

Une clé SSH est une paire de fichiers unique, générée pour vous : une **clé privée** qui ne quitte jamais votre PC, et une **clé publique** que l'on copie sur le serveur. `ed25519` est simplement le type de clé moderne recommandé.

**Sur votre PC**, vérifiez si vous avez déjà une clé :

```bash
ls ~/.ssh/*.pub
```

Si aucun fichier n'apparaît, créez-en une (Entrée à chaque question ; une passphrase est recommandée) :

```bash
ssh-keygen -t ed25519
```

**Copiez la clé publique sur le serveur** :

```bash
ssh-copy-id utilisateur@ip_du_serveur
```

**Vérifiez** :

```bash
ssh utilisateur@ip_du_serveur "echo Connexion OK"
```

Si « Connexion OK » s'affiche sans mot de passe demandé, l'étape est réussie.

---

## Étape 4 — Récupérer le projet et déployer

Il vous faut `git` sur votre PC (`sudo apt install git` sur Ubuntu, `sudo dnf install git` sur Fedora).

```bash
git clone https://github.com/souhayb-abdourahimi/lab-dacs.git
cd lab-dacs
./install.sh
```

Le script vous guide en 6 étapes :

1. **Ansible** : il vérifie qu'Ansible est installé et propose de l'installer sinon.
2. **Collections Ansible** nécessaires (Docker et pare-feu).
3. **Adresse du serveur** : l'IP et l'utilisateur de l'étape 1. Le script écrit lui-même l'inventaire, vous n'avez aucun fichier à modifier. Lors des lancements suivants, il vous propose la dernière IP utilisée : appuyez simplement sur Entrée.
4. **Vos secrets** : vous choisissez **vos propres** identifiants :
   - le mot de passe admin **Grafana** ;
   - votre **sujet ntfy** (étape 2) ;
   - l'identifiant et le mot de passe admin **AdGuard** ;
   - un **mot de passe de coffre**, qui chiffre tous ces secrets (Ansible Vault). Retenez-le : il sera redemandé à chaque redéploiement.
5. **Test de connexion** au serveur.
6. **Déploiement** : le mot de passe `sudo` du serveur vous est demandé (`BECOME password`).

À la fin, un résumé `PLAY RECAP` avec `failed=0` signifie que tout s'est bien passé.

Ce que le déploiement fait automatiquement, sans intervention :
- installe Python sur le serveur s'il manque (Debian minimale) ;
- installe Docker, puis la supervision et AdGuard sous forme de conteneurs ;
- configure **AdGuard** avec votre identifiant, votre mot de passe (haché en bcrypt) et quatre listes de blocage (anti-publicité, anti-phishing, anti-malware) ;
- configure **Grafana** avec votre mot de passe, importe le tableau de bord de supervision et l'affiche sous le vrai nom de votre serveur ;
- installe les **alertes** (et les outils `curl` et `jq` dont elles ont besoin), et les branche sur PAM pour les connexions SSH et l'utilisation de `sudo` ;
- active le **pare-feu ufw** : tout est refusé en entrée, sauf SSH (22) et DNS (53) ;
- installe **CrowdSec** et applique les correctifs propres à la distribution (par exemple le renommage `sshd-session` de Debian 13, sans lequel CrowdSec ne détecterait pas les attaques SSH) ;
- durcit la configuration **SSH** (clé uniquement, root interdit).

Relancer `install.sh` plus tard ne casse rien : Ansible ne refait que ce qui a changé.

---

## Étape 5 — Vérifier

**Les interfaces web.** Ouvrez les deux tunnels d'un coup (laissez ce terminal ouvert) :

```bash
ssh -L 3000:127.0.0.1:3000 -L 8090:127.0.0.1:8090 utilisateur@ip_du_serveur
```

- **Grafana** → `http://localhost:3000`. Connectez-vous avec `admin` et votre mot de passe Grafana. Le tableau de bord **Node Exporter Full** est déjà présent dans le menu Dashboards.
- **AdGuard** → `http://localhost:8090`. Vous arrivez directement sur la page de connexion, sans assistant d'installation. Dans **Filtres → Listes de blocage DNS**, les 4 listes sont déjà actives.

**Le filtrage DNS**, depuis votre PC (installez `dig` si besoin : `sudo apt install bind9-dnsutils` ou `sudo dnf install bind-utils`) :

```bash
dig @ip_du_serveur wikipedia.org +short             # une vraie IP
dig @ip_du_serveur doubleclick.net +short           # 0.0.0.0 (bloqué)
dig @ip_du_serveur exemple-arnaque-test.com +short  # 0.0.0.0 (règle de test)
```

**Le pare-feu**, sur le serveur :

```bash
ssh -t utilisateur@ip_du_serveur "sudo ufw status verbose"
```

Il doit être `active`, avec « deny (incoming) » et les règles 22/tcp, 53/tcp et 53/udp.

**Les alertes**, depuis votre PC. Chaque commande doit faire sonner votre téléphone :

```bash
ssh utilisateur@ip_du_serveur exit                                          # Connexion SSH
ssh -t utilisateur@ip_du_serveur "sudo -k; sudo whoami"                     # sudo utilisé
ssh -t utilisateur@ip_du_serveur "sudo cscli decisions add --ip 203.0.113.10 --reason test"  # IP bannie
```

L'alerte CrowdSec peut mettre jusqu'à 30 secondes à arriver. Retirez ensuite le bannissement de test :

```bash
ssh -t utilisateur@ip_du_serveur "sudo cscli decisions delete --ip 203.0.113.10"
```

---

## Dépannage

La liste complète des problèmes réels rencontrés et résolus est dans le [journal de dépannage](08-depannage.md). Les plus courants au déploiement :

**« Impossible de joindre le serveur » au test de connexion.** Le serveur est éteint, son IP a changé, ou votre clé n'y est pas installée. Pour une VM KVM, vérifiez son état et son IP depuis votre PC avec `sudo virsh list --all` et `sudo virsh domifaddr NOM_DE_LA_VM`.

**`sudo : un terminal est requis` en lançant une commande à distance.** Ajoutez l'option `-t` à `ssh` : `ssh -t utilisateur@ip "sudo ..."`.

**« Failed to update apt cache » à cause d'un dépôt tiers.** Un dépôt externe cassé bloque `apt`. Désactivez le fichier fautif dans `/etc/apt/sources.list.d/` en le renommant, puis relancez.

**Un port déjà utilisé (ex. 8080).** Identifiez le service avec `sudo ss -tlpn | grep :PORT` et changez le port publié dans le `docker-compose.yml` concerné.

**Grafana affiche l'ancien mot de passe.** Grafana n'applique le mot de passe qu'à sa première initialisation. Pour repartir de zéro, supprimez son volume sur le serveur (`sudo docker volume rm supervision_grafana-data`) puis relancez `install.sh`.

**Le script plante au milieu de l'étape des secrets.** Supprimez les fichiers partiels avant de relancer : `rm -f ansible/group_vars/all.yml ansible/.vault_pass`.

**Aucune alerte n'arrive.** Vérifiez que vous êtes abonné au **bon sujet** dans ntfy (celui saisi dans `install.sh`). Puis testez l'envoi direct depuis le serveur :
`ssh -t utilisateur@ip "sudo sh -c '. /etc/lab-alertes.conf && curl -d Test https://ntfy.sh/\$NTFY_TOPIC'"`.

---

## Sécurité — ce qui ne doit jamais partir sur Git

Le dépôt est configuré pour que ces fichiers restent sur votre machine (`ansible/.gitignore`) :

- `ansible/.vault_pass` : le mot de passe de votre coffre, en clair.
- `ansible/group_vars/all.yml` : votre coffre de secrets (chiffré, mais personnel).
- `ansible/inventory/hosts.yml` : l'adresse de votre serveur.

Seuls des **modèles** à valeurs fictives sont versionnés (`all.yml.example`, `hosts.yml.example`). Chaque personne qui clone le dépôt crée ses propres secrets avec `install.sh`.

---

## Annexe A — Créer la VM sous Ubuntu avec virt-manager

Cette annexe reprend pas à pas la création de la VM de test utilisée pour valider le déploiement depuis Ubuntu.

### 1. Vérifier que le processeur supporte la virtualisation

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
```

Un résultat **supérieur à 0** signifie que le processeur la supporte. S'il affiche **0**, activez « Virtualization Technology », « Intel VT-x » ou « AMD-V » dans le BIOS de votre PC.

```bash
sudo apt install -y cpu-checker
sudo kvm-ok
```

La réponse attendue est « KVM acceleration can be used ».

### 2. Installer KVM et virt-manager

```bash
sudo apt install -y qemu-system-x86 libvirt-daemon-system virt-manager
```

> Sur les Ubuntu récents, `qemu-kvm` est un paquet virtuel qui ne s'installe pas directement : le vrai nom est `qemu-system-x86`.

### 3. Démarrer le service et donner les droits à votre utilisateur

```bash
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt,kvm $USER
```

**Déconnectez-vous puis reconnectez-vous** (ou redémarrez) : l'appartenance aux groupes n'est prise en compte qu'à l'ouverture de session. Sans cela, virt-manager affiche « Permission non accordée » sur le socket libvirt. Vérifiez ensuite avec `groups` : `libvirt` et `kvm` doivent apparaître.

> GNOME Boxes peut afficher « No KVM! » tant que ces paquets ne sont pas installés. virt-manager est plus fiable pour cet usage.

### 4. Télécharger Debian

Sur [debian.org](https://www.debian.org/download), téléchargez l'image **netinst** (légère, environ 700 Mo).

### 5. Créer la VM

```bash
virt-manager &
```

1. Vérifiez que la ligne **QEMU/KVM** est connectée (sinon, double-cliquez dessus).
2. Cliquez sur **Créer une machine virtuelle** → **Support d'installation local (image ISO)**.
3. Sélectionnez l'ISO Debian. Si virt-manager propose de **corriger les permissions** d'accès au dossier Téléchargements, répondez **Oui**.
4. Système : **Debian 13** (ou « Debian testing » / « Generic Linux » s'il n'est pas listé).
5. Mémoire : **2048 Mo**, processeurs : **2**, disque : **20 Go**.
6. Nom : par exemple `debian-test`, réseau **NAT** par défaut → **Terminer**.

Installez ensuite Debian en suivant les consignes de l'étape 1 de ce guide (clavier français, root vide, serveur SSH coché, pas de bureau, GRUB sur Oui).

### 6. Fixer l'IP de la VM

Par défaut, la VM reçoit son IP par DHCP, et elle peut changer à chaque redémarrage. On réserve une adresse pour sa carte réseau.

Récupérez l'adresse MAC de la VM :

```bash
sudo virsh domiflist debian-test
```

Puis réservez l'IP actuelle pour cette MAC (remplacez les deux valeurs) :

```bash
sudo virsh net-update default add ip-dhcp-host "<host mac='52:54:00:xx:xx:xx' ip='192.168.122.XXX'/>" --live --config
```

`--live` applique la réservation immédiatement, `--config` la conserve après redémarrage. Vérifiez :

```bash
sudo virsh net-dumpxml default | grep "host mac"
```
