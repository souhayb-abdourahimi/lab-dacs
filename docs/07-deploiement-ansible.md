# Guide de déploiement — de zéro à un lab complet

Ce guide explique comment déployer le lab de A à Z, sans rien supposer connu. À la fin, vous aurez un serveur supervisé, durci et défendu, qui vous envoie des alertes sur votre téléphone.

> Avant de commencer, lisez le [modèle de menaces](09-threat-model.md) : il précise ce que le lab protège, ce qu'il ne protège pas, et ses limites. C'est un laboratoire d'apprentissage, pas un produit de sécurité certifié.

## Ce que contient le projet

Le dépôt réunit **deux choses distinctes** :

1. **Le serveur** (supervision, CrowdSec, AdGuard, alertes, durcissement SSH). Il se déploie automatiquement avec Ansible, via le script `install.sh`. C'est l'objet de ce guide.
2. **La détection d'accès au poste de travail** (dossier `detection-pc/`). Ces scripts tournent sur votre machine physique, pas sur le serveur, et s'installent séparément — voir [06-detection-pc.md](06-detection-pc.md).

## Vue d'ensemble des étapes

1. Obtenir un serveur Debian ou Ubuntu.
2. Préparer votre téléphone (application ntfy).
3. Préparer votre clé SSH et la copier sur le serveur.
4. Récupérer le projet et lancer `install.sh`.
5. Vérifier que tout fonctionne.

---

## Étape 1 — Obtenir un serveur

Il vous faut un serveur **Debian 12/13 ou Ubuntu LTS**, accessible en SSH. Deux façons de l'obtenir :

**Option A — une machine virtuelle sur votre PC (gratuit).** Avec KVM/QEMU, VirtualBox ou GNOME Boxes. Installez Debian ou Ubuntu **sans interface graphique**, en cochant **serveur SSH** à l'installation. Notez l'adresse IP de la VM et le nom d'utilisateur créé.

> Sous VirtualBox, mettez la carte réseau en mode **Accès par pont** (Bridged), sinon la machine de contrôle ne pourra pas joindre la VM en SSH.

**Option B — un serveur chez un hébergeur (quelques euros/mois).** Un petit VPS arrive déjà installé et accessible en SSH. Plus simple si vous débutez avec la virtualisation.

Dans les deux cas, à la fin de cette étape vous devez connaître : **l'adresse IP du serveur** et **le nom d'utilisateur** pour vous y connecter.

---

## Étape 2 — Préparer votre téléphone (ntfy)

Les alertes du serveur arrivent via **ntfy**, une application de notifications gratuite. Sans cette étape, le serveur enverra des alertes que vous ne verrez pas.

1. Installez l'application **ntfy** depuis l'App Store (iPhone) ou le Play Store (Android).
2. Choisissez un **sujet** : c'est votre canal privé d'alertes. Il doit être **impossible à deviner**, car toute personne qui connaît le nom peut lire vos alertes. Générez-en un aléatoire sur votre PC :

   ```bash
   echo "monlab-$(openssl rand -hex 4)"
   ```

   Vous obtenez par exemple `monlab-3f9a1c7e`. **Notez-le**, il servira à l'étape 4.
3. Dans l'application ntfy, appuyez sur **+**, collez ce sujet, laissez le serveur par défaut (`ntfy.sh`), et validez. Autorisez les notifications.

> Ne publiez jamais ce sujet (ni sur GitHub, ni sur une capture d'écran). C'est un secret.

---

## Étape 3 — Préparer la clé SSH

Ansible se connecte au serveur par clé SSH (pas par mot de passe). Cette étape n'est volontairement pas automatisée : mieux vaut la faire en conscience.

**Sur votre PC**, si vous n'avez pas encore de clé :

```bash
ssh-keygen -t ed25519
```

Appuyez sur Entrée à chaque question (une passphrase est recommandée).

**Copiez la clé sur le serveur** (remplacez par vos valeurs) :

```bash
ssh-copy-id utilisateur@ip_du_serveur
```

**Vérifiez** que la connexion par clé fonctionne :

```bash
ssh utilisateur@ip_du_serveur "echo Connexion OK"
```

Si vous voyez « Connexion OK » sans qu'on vous demande de mot de passe, l'étape est réussie.

---

## Étape 4 — Récupérer le projet et déployer

**Récupérez le dépôt** sur votre PC :

```bash
git clone https://github.com/souhayb-abdourahimi/lab-dacs.git
cd lab-dacs
```

**Lancez le script d'installation** :

```bash
./install.sh
```

Le script vous guide et vous pose quelques questions :

- **Adresse IP et utilisateur du serveur** (de l'étape 1).
- **Vos mots de passe** pour Grafana et AdGuard (choisissez-les).
- **Votre sujet ntfy** (celui de l'étape 2).
- **Un mot de passe de coffre** : il protège tous vos secrets. Le script chiffre vos mots de passe avec (Ansible Vault). Retenez-le bien.
- **Le mot de passe sudo du serveur** (`BECOME password`), pour qu'Ansible puisse installer les paquets.

Le script installe Ansible au besoin, teste la connexion, crée votre coffre chiffré, puis déploie tout. À la fin, un résumé `PLAY RECAP` avec `failed=0` signifie que tout s'est bien passé.

> Les correctifs spécifiques à une distribution (par exemple le renommage `sshd-session` de Debian 13, qui empêche CrowdSec de détecter les attaques SSH) sont appliqués **automatiquement selon l'OS détecté**. Sur Debian 12 ou Ubuntu, où ils ne sont pas nécessaires, ils sont ignorés. Vous n'avez rien à faire.

---

## Étape 5 — Vérifier

**Grafana** (supervision). Ouvrez un tunnel puis le navigateur :

```bash
ssh -L 3000:127.0.0.1:3000 utilisateur@ip_du_serveur
```

Puis allez sur `http://localhost:3000`, connectez-vous avec `admin` et le mot de passe Grafana choisi. Importez le tableau de bord n° 1860 si besoin.

**AdGuard** (filtre DNS) :

```bash
ssh -L 8090:127.0.0.1:8090 utilisateur@ip_du_serveur
```

Puis `http://localhost:8090`, avec vos identifiants AdGuard.

**CrowdSec** (détection), sur le serveur :

```bash
sudo cscli metrics
sudo cscli bouncers list
```

**Une alerte de test sur votre téléphone**, sur le serveur :

```bash
sudo sh -c '. /etc/lab-alertes.conf && curl -H "Title: Test" -d "Ca marche" "https://ntfy.sh/$NTFY_TOPIC"'
```

Votre téléphone doit sonner.

---

## Dépannage

Une liste complète des problèmes réels rencontrés pendant la construction du lab, avec leur diagnostic et leur résolution, se trouve dans le [journal de dépannage](08-depannage.md). Les plus courants au déploiement :

**« Failed to connect / Connection timed out » au test SSH.** Le serveur est éteint ou injoignable. S'il s'agit d'une VM KVM et que votre PC vient de redémarrer, le partage réseau peut être coupé. Sur le PC hôte, vérifiez que la VM a bien internet ; le journal de dépannage détaille le cas du conflit entre Docker et le forwarding réseau.

**« Failed to update apt cache » à cause d'un dépôt tiers.** Un dépôt externe cassé bloque `apt`. Désactivez le fichier fautif dans `/etc/apt/sources.list.d/` en le renommant, puis relancez.

**Un port déjà utilisé (ex. 8080).** Un service occupe déjà le port. Identifiez-le avec `sudo ss -tlpn | grep :PORT` et changez le port publié dans le `docker-compose.yml` concerné.

**« grafana_admin_password is undefined » au déploiement.** Le fichier de secrets n'est pas chargé. Il doit s'appeler `group_vars/all.yml` (chargé automatiquement).

**CrowdSec ne détecte pas les attaques SSH.** Sur Debian 13, le processus SSH est renommé `sshd-session` et le parser CrowdSec ne le reconnaît pas. Le playbook applique le correctif automatiquement ; le détail est dans le journal de dépannage.

---

## Sécurité — ce qui ne doit jamais partir sur Git

- `ansible/.vault_pass` : le mot de passe de votre coffre, en clair. Il reste sur votre PC (déjà dans `.gitignore`).
- `group_vars/all.yml` **en clair** : ne le versionnez jamais non chiffré. Seuls le coffre **chiffré** (illisible) et le modèle `all.yml.example` (valeurs fictives) vont sur Git.
- Les fichiers `.env` et `/etc/lab-alertes.conf` du serveur : générés par Ansible, jamais versionnés.

Avant chaque `git push`, une vérification anti-fuite est recommandée :

```bash
grep -rn "votre-sujet-ntfy" . && echo "STOP : secret present" || echo "Propre"
```
