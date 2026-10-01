# ADR 0003 — Séparation de la télémétrie et de l'alerting

- Statut : Accepté
- Date : 2026-10-01

## Contexte

Un événement de sécurité doit rester observable même lorsque ntfy est indisponible.

## Décision

Les collecteurs interrogent la source, dédupliquent et journalisent les événements, puis déclenchent éventuellement un notifier. Les scripts d'alerting reçoivent un événement déjà qualifié et ne possèdent pas l'état du collecteur.

## Conséquences

Loki conserve la visibilité lorsque ntfy est indisponible et une panne du canal push ne provoque pas la réémission infinie des mêmes événements.
