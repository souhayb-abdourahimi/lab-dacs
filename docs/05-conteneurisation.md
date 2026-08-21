# 05 — Conteneurisation

## Installation

```bash
sudo apt install docker.io docker-compose -y
sudo systemctl enable --now docker
sudo usermod -aG docker souhayb
```

Reconnexion nécessaire pour que le groupe `docker` prenne effet.

## Validation

```bash
docker run --rm hello-world
```

Ce test valide en une commande : le daemon répond, les droits utilisateur sont
corrects, le réseau sortant fonctionne (image tirée depuis Docker Hub), et le
moteur sait créer et exécuter un conteneur.

## Conteneur ou machine virtuelle

| | Machine virtuelle | Conteneur |
|---|---|---|
| Isolation | Noyau dédié | Noyau partagé avec l'hôte |
| Démarrage | Dizaines de secondes | Moins d'une seconde |
| Empreinte | Plusieurs Go | Quelques Mo à quelques centaines |
| Usage | Systèmes hétérogènes | Applications homogènes, déploiement rapide |

## Stack de démonstration

```bash
cd docker/web-stack
cp .env.example .env      # renseigner un mot de passe réel
docker compose up -d
docker compose ps
docker compose logs -f
```

Points de conception retenus :

- La base PostgreSQL n'est **pas** exposée sur l'hôte. Elle n'est joignable
  que par les conteneurs du réseau `interne`. Publier un port de base de
  données est une erreur fréquente et coûteuse.
- Les données de la base sont dans un **volume nommé**, qui survit à la
  suppression du conteneur.
- Le service web attend que la base soit réellement prête (`healthcheck` +
  `depends_on: condition: service_healthy`), et non simplement démarrée.
- Les identifiants viennent d'un fichier `.env` exclu du dépôt.

## Nettoyage

```bash
docker compose down          # arrête et supprime les conteneurs
docker compose down -v       # supprime aussi les volumes (données perdues)
docker system prune -a       # purge les images inutilisées
```
