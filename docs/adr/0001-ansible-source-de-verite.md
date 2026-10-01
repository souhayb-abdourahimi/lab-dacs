# ADR 0001 — Ansible comme source de vérité du déploiement

- Statut : Accepté
- Date : 2026-10-01

## Contexte

Le lab doit pouvoir être reconstruit sur plusieurs distributions Linux sans dépendre d'opérations manuelles difficilement reproductibles.

## Décision

Ansible est la source de vérité de l'état du serveur et du poste protégé. Les scripts Bash collectent et valident les paramètres, préparent Ansible, l'inventaire et le coffre, puis déclenchent les playbooks. Ils ne réimplémentent pas les rôles Ansible.

## Conséquences

Le déploiement peut être rejoué sans modification lorsque la machine est déjà dans l'état attendu. La logique système reste testable avec Molecule et les scénarios E2E.
