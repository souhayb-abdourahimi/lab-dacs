# ADR 0002 — Interfaces d'administration par tunnel SSH

- Statut : Accepté
- Date : 2026-10-01

## Contexte

Grafana et AdGuard exposent des interfaces d'administration qui ne doivent pas être directement accessibles depuis le réseau.

## Décision

Les interfaces d'administration sont liées exclusivement à 127.0.0.1. L'accès distant passe par un tunnel SSH authentifié par clé. Prometheus, Loki et Alloy ne publient aucun port vers l'hôte lorsqu'aucun accès externe n'est nécessaire.

## Conséquences

Une machine présente sur le même réseau ne peut pas atteindre directement les interfaces d'administration. Le pare-feu reste une couche supplémentaire et non la seule protection.
