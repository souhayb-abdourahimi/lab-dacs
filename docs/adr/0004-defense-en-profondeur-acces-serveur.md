# ADR 0004 — Défense en profondeur de l'accès serveur

- Statut : Accepté
- Date : 2026-10-01

## Contexte

Aucune protection unique ne doit constituer la seule barrière contre un accès distant non autorisé.

## Décision

SSH impose les clés, interdit root et les mots de passe, limite les essais et désactive X11/agent forwarding. Le pare-feu refuse l'entrée par défaut et n'autorise explicitement que les services requis. CrowdSec analyse les événements et applique ses décisions via le bouncer. Loki et ntfy assurent l'observabilité.

## Conséquences

La compromission ou la mauvaise configuration d'une seule couche ne supprime pas automatiquement les autres protections.
