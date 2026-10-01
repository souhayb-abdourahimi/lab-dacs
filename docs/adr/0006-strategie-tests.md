# ADR 0006 — Stratégie de tests multi-niveaux

- Statut : Accepté
- Date : 2026-10-01

## Contexte

Un conteneur Molecule est rapide mais ne reproduit pas fidèlement toutes les propriétés d'une vraie VM.

## Décision

La validation combine analyse statique, scanners de sécurité, régressions d'invariants, Molecule pour l'idempotence et les services, et E2E VM pour SSH, pare-feu, CrowdSec, tunnels, DNS, alertes et télémétrie.

## Conséquences

Molecule reste la boucle rapide. Les VM E2E couvrent les propriétés impossibles à démontrer correctement dans un conteneur. Les tests privilégient un comportement observable à la simple présence de configuration.
