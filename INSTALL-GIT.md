# Mise en place du dépôt

Commandes à exécuter sur la VM pour initialiser le dépôt et le publier.

## 1. Identité Git

```bash
git config --global user.name  "Souhayb Abdourahimi"
git config --global user.email "souhayb299@gmail.com"
git config --global init.defaultBranch main
git config --global --list
```

## 2. Initialisation

```bash
cd ~/lab-dacs
git init
git add .
git commit -m "feat: infrastructure de lab DACS (VM, sécurisation, Docker)"
```

## 3. Publication sur GitHub

Créer un dépôt vide nommé `lab-dacs` sur GitHub, **sans** README ni .gitignore
(ils existent déjà ici), puis :

```bash
git remote add origin git@github.com:<utilisateur>/lab-dacs.git
git branch -M main
git push -u origin main
```

Si l'accès SSH à GitHub n'est pas configuré :

```bash
ssh-keygen -t ed25519 -C "souhayb299@gmail.com"
cat ~/.ssh/id_ed25519.pub        # à coller dans GitHub > Settings > SSH keys
ssh -T git@github.com            # doit afficher un message de bienvenue
```

## 4. Convention de commits

Format `type: description à l'infinitif`, en minuscules.

| Type | Usage |
|---|---|
| `feat` | Nouvelle fonctionnalité ou nouveau service |
| `fix` | Correction |
| `docs` | Documentation seule |
| `refactor` | Réorganisation sans changement de comportement |
| `chore` | Maintenance, dépendances |

Exemples :

```bash
git commit -m "feat: ajouter le durcissement SSH et les règles ufw"
git commit -m "docs: documenter la récupération via GRUB"
git commit -m "fix: autoriser le port 22 avant activation de ufw"
```

## 5. Vérification avant publication

```bash
git status --short          # aucun fichier .env ou clé privée
cat .gitignore
git log --oneline
```

> Ne jamais versionner : `.env`, clés privées (`id_ed25519`, `*.key`, `*.pem`),
> sauvegardes de configuration contenant des identifiants.
