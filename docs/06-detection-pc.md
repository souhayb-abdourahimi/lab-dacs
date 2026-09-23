# Détection d'accès au poste de travail

## Installation

Le module s'installe **sur le PC à protéger**, avec le compte habituel (pas en root) :

```bash
git clone https://github.com/souhayb-abdourahimi/lab-dacs.git
cd lab-dacs
./install-pc.sh
```

Le script réutilise le coffre du serveur s'il est présent sur la machine (même sujet ntfy, copie des photos sur le serveur). Sinon, il demande seulement le sujet ntfy, et les photos sont uniquement envoyées sur le téléphone. **Déconnectez-vous puis reconnectez-vous** à la fin : l'accès au clavier et à la souris (groupe `input`) n'est actif qu'à l'ouverture de session.

Prérequis : Fedora, Debian ou Ubuntu, avec le bureau GNOME. Les systèmes immuables (Fedora Silverblue) ne sont pas pris en charge.

Utilisation :

| Commande | Effet |
|----------|-------|
| `absent` | met la vigilance en attente ; elle s'arme au verrouillage (Super+L) |
| `present` | désarme la vigilance |
| `vigilance` | affiche l'état de la vigilance |
| `photo-on` / `photo-off` | autorise ou interdit la photo webcam (désactivée par défaut) |

Pour tout retirer : `./install-pc.sh --retirer`.

## Objectif

Détecter quand quelqu'un accède physiquement à mon PC en mon absence, et réagir immédiatement : alerter, verrouiller l'écran, et photographier l'intrus. Contrairement aux autres briques qui protègent le serveur, celle-ci protège la **machine de travail** elle-même. Les alertes partent du PC et remontent au serveur, dans la continuité du système ntfy.

## Les cinq déclencheurs

| Déclencheur | Mécanisme | Toujours actif ? |
|-------------|-----------|------------------|
| Déverrouillage de session | signal D-Bus GNOME (`org.gnome.ScreenSaver`) | oui |
| Branchement USB | règle `udev` | oui |
| Activité clavier/souris | lecture des périphériques (`evdev`) | seulement en vigilance |
| Verrouillage automatique | `loginctl lock-session` sur intrusion | seulement en vigilance |
| Photo de l'intrus | capture `ffmpeg` webcam | vigilance + `photo-on` |

## Le mode vigilance

Le cœur du système est un **interrupteur volontaire** : la surveillance d'activité ne s'active pas en permanence (sinon elle réagirait dès que j'utilise mon PC), mais uniquement quand je décide de partir.

Le déclenchement se fait en deux temps, ce qui est le choix de conception le plus important de ce module :

1. `absent` → met la vigilance **en attente** (rien n'est encore surveillé).
2. Je verrouille l'écran (Super+L) → la vigilance **s'arme** réellement.

Ce découplage résout un problème de fond : si l'armement se faisait dès la commande `absent`, la frappe clavier de la commande elle-même serait détectée comme une activité et déclencherait l'alerte. En armant au verrouillage — moment où je ne touche physiquement plus à rien — le signal de départ est propre.

Au retour, le déverrouillage avec mon mot de passe **désarme automatiquement** la vigilance. Un interrupteur séparé `photo-on` / `photo-off` autorise ou non la capture webcam.

## Réaction à une intrusion

Quand la vigilance est armée et qu'une activité est détectée :

1. **Photo** de la personne devant l'écran (si `photo-on`).
2. **Envoi** de la photo sur le téléphone en pièce jointe, via ntfy.
3. **Copie de preuve** sur le serveur (VM), hors de portée d'un intrus présent sur le PC.
4. **Verrouillage** immédiat de l'écran.
5. **Alerte** sur le téléphone.

La copie sur le serveur applique le même principe que les alertes : les preuves doivent quitter la machine attaquée avant qu'on puisse les effacer.

## Éthique et vie privée

Une webcam qui se déclenche seule doit être maîtrisée. Trois garde-fous :

- La photo ne se prend que si la vigilance est armée **et** la capture explicitement autorisée (`photo-on`).
- Une notification « Caméra activée » est envoyée à chaque capture : jamais de photo cachée.
- Sur ma propre machine, filmer est mon droit. En entreprise, filmer des salariés est encadré par le RGPD et la CNIL : information obligatoire des personnes. À ne jamais transposer tel quel dans un contexte professionnel.

## Problèmes rencontrés

**La boucle de verrouillage infinie.** Première version : au déverrouillage, je bougeais la souris pour taper mon mot de passe, ce qui était détecté comme une activité et reverrouillait aussitôt. Impossible d'entrer. Solution : le déverrouillage désarme automatiquement la vigilance. Sortie de la boucle en secours par un terminal texte (Ctrl+Alt+F3).

**L'armement depuis le clavier se déclenchait seul.** La touche Entrée validant la commande `absent` comptait comme une activité. Résolu par le découplage en deux temps (en attente → armé au verrouillage) décrit plus haut : au moment de l'armement réel, je ne touche plus au clavier.

**ffmpeg bloqué gardant la webcam ouverte.** Un `ffmpeg` interrompu laissait la caméra occupée indéfiniment, retardant l'envoi de la photo. Diagnostic avec `fuser /dev/video0`. Solution : encadrer la capture par `timeout 10` pour garantir la libération de la caméra en toute circonstance.

**Webcam sous-exposée.** Les premières captures étaient noires : la webcam n'avait pas le temps de régler son exposition. Solution : capturer 30 images (~1 à 2 s) et ne garder que la dernière, le temps que l'ajustement se fasse.

**Droits d'accès aux périphériques d'entrée.** Lire le clavier et la souris via `evdev` demande d'appartenir au groupe `input`. Ajout du compte au groupe, effectif après reconnexion.

## Problèmes découverts en automatisant le module

Avant d'écrire le rôle Ansible, le module a été relu à la recherche de tout ce qui avait été réglé à la main sur le PC de développement, en appliquant la leçon du premier déploiement (voir la partie 2 du [journal de dépannage](08-depannage.md)). Dix problèmes sont apparus, dont plusieurs invisibles sur la machine d'origine :

- **Le service `alerte-usb@.service`**, appelé par la règle udev, **n'était pas dans le dépôt** : aucune alerte USB chez un autre utilisateur.
- **Le nom de l'appareil USB n'arrivait jamais au script** : les variables d'environnement de udev ne sont pas transmises au service systemd. Le nom est désormais passé en argument (`%I`).
- **La lecture du sujet ntfy était incohérente** : deux scripts utilisaient `sudo` (qui exigeait une règle sudoers faite à la main), et le script Python lisait sans `sudo` un fichier réservé à root, donc **l'alerte d'intrusion ne partait pas**. Tous les scripts lisent maintenant un fichier de configuration dédié, sans `sudo`.
- **Des valeurs codées en dur** : le chemin `/home/souhayb`, l'adresse et l'utilisateur du serveur de preuves.
- **Le dossier `~/preuves` n'était jamais créé** sur le serveur.
- **Le groupe `input`** n'est actif qu'après reconnexion, et le script de surveillance plantait s'il ne pouvait pas lire le clavier : il s'arrête maintenant proprement avec un message.
- **Les commandes `absent`, `photo-on`...** n'existaient que sur le PC de développement : elles sont installées comme de petits scripts dans `~/.local/bin`, utilisables depuis n'importe quel shell.
- **Les noms de paquets diffèrent** entre Fedora et Ubuntu (`ffmpeg-free` et `ffmpeg`, `libnotify` et `libnotify-bin`) : le rôle vérifie les **commandes** présentes et n'installe que ce qui manque, ce qui évite aussi un conflit avec le ffmpeg de RPM Fusion.

Le test du rôle sur une machine vierge en a révélé trois autres :

- **Index apt périmé** : sur un PC rarement mis à jour, apt réclamait une version de paquet supprimée des miroirs (erreur 404). L'installation met maintenant l'index à jour d'abord.
- **Plantage sans serveur configuré** : Ansible évalue la cible d'une tâche déléguée **avant** sa condition `when`. Sur un PC sans serveur, la tâche qui crée `~/preuves` plantait alors qu'elle aurait dû être ignorée.
- **Rechargement de udev impossible sans démon udev** (WSL, conteneur) : ce rechargement n'est pas indispensable, udev surveille lui-même son dossier de règles. Il ne bloque plus le déploiement.

## Limites connues et pistes d'amélioration

- **Bureau GNOME uniquement** pour les alertes de verrouillage et de déverrouillage, qui reposent sur un signal D-Bus propre à GNOME. Sur un autre bureau, l'installateur prévient ; USB et détection d'activité restent actives.
- **Copie des preuves avec une clé SSH protégée par une phrase de passe** : le service ne peut pas la saisir, la copie est alors ignorée (la photo part quand même sur le téléphone).
- **Un intrus qui connaît le mot de passe** désarme la vigilance en déverrouillant. Mais il a déjà déclenché l'alerte d'intrusion **avant** le verrouillage : le signalement a eu lieu.
- **Détection au niveau de l'écran de connexion (GDM), pas seulement en session.** Piste : brancher PAM sur les échecs d'authentification pour capturer une tentative *avant* même l'ouverture de session (plusieurs mots de passe ratés → photo silencieuse).
- **Réécriture du moteur en Go.** Les scripts actuels (Bash + Python) pourraient devenir un binaire unique : gestion concurrente (clavier, webcam, réseau) via goroutines, et binaire compilé plus difficile à altérer qu'un script en clair.
- **Surveillance réseau en mode vigilance.** Détecter une requête ARP suspecte ou un scan de ports pendant l'absence, en mode alerte d'abord (le durcissement automatique du pare-feu présente un risque de blocage de soi-même).

