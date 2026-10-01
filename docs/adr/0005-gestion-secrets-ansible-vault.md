# ADR 0005 — Gestion des secrets avec Ansible Vault

- Statut : Accepté
- Date : 2026-10-01

## Contexte

Le déploiement nécessite des secrets Grafana, AdGuard et ntfy qui ne doivent pas être stockés en clair dans Git.

## Décision

Les secrets de déploiement sont stockés dans Ansible Vault. /etc/lab-alertes.conf appartient à root:root en 0600. Le mot de passe Grafana est fourni par un fichier dédié en lecture seule. Les tâches pouvant révéler des secrets utilisent no_log.

## Conséquences

Aucun secret opérationnel n'est requis dans le dépôt Git. La sécurité du coffre dépend du secret Vault et de la machine de contrôle.
