# Alertes en temps réel — ntfy

## Objectif

Être prévenu sur mon téléphone dès qu'un événement de sécurité important se produit. Une alerte qui part au bon moment permet de réagir même si l'attaquant efface ensuite ses traces sur la machine. Le principe clé : **les preuves doivent quitter le serveur immédiatement**.

## Les quatre alertes

| Événement | Déclencheur | Priorité |
|-----------|-------------|----------|
| Connexion SSH | module PAM `pam_exec` à l'ouverture de session | haute |
| Passage en root (`sudo`) | module PAM sur le service `sudo` | haute |
| IP bannie | timer systemd interrogeant CrowdSec | haute |
| Site dangereux bloqué | timer systemd interrogeant l'API AdGuard | haute |

Le transport est **ntfy** : un service de notification gratuit. Le serveur envoie un message sur un « sujet » secret, et l'application ntfy sur le téléphone le reçoit.

## Deux mécanismes de déclenchement

**PAM (immédiat)** pour SSH et sudo. PAM est le système d'authentification de Linux : on y branche un script qui s'exécute pile au moment de la connexion ou de l'élévation de privilèges. L'option `optional` garantit que si l'alerte échoue (pas de réseau), la connexion fonctionne quand même — impossible de s'enfermer dehors.

**Timer systemd (toutes les 30 s)** pour CrowdSec et AdGuard. Un petit script interroge régulièrement chaque outil et notifie les nouveautés, en retenant ce qui a déjà été envoyé pour ne jamais alerter deux fois.

## Gestion des secrets

Le sujet ntfy et les identifiants AdGuard vivent dans `/etc/lab-alertes.conf` (permissions `600`, jamais versionné). Les scripts lisent ce fichier, ils ne contiennent aucun secret en dur. Le dépôt fournit un modèle `lab-alertes.conf.example` avec des valeurs fictives.

## Problèmes rencontrés

**`sudo` : identité réelle contre identité effective.** Le script d'alerte sudo échouait (code 2). Cause : `pam_exec` lançait le script avec l'identité de l'utilisateur d'origine (souhayb), qui n'a pas le droit de lire `/etc/lab-alertes.conf` (réservé à root). Solution : l'option `seteuid`, qui exécute le script avec les droits effectifs de root.

> C'est exactement le mécanisme qui fait fonctionner `sudo` lui-même : un processus a une identité *réelle* (qui l'a lancé) et une identité *effective* (avec quels droits il agit).

**Déluge de notifications sudo.** L'alerte sudo se déclenchait à chaque commande, saturant le téléphone pendant les phases d'installation. Ajout d'un anti-spam : une seule alerte sudo, puis silence pendant 10 minutes.

**Déluge de notifications AdGuard.** Le premier script notifiait *tout* ce qui était bloqué, y compris les pubs et traqueurs (des dizaines par minute). Corrigé en ne notifiant que les blocages venant des listes de **danger** (phishing, malware), identifiées par leur `filter_list_id` dans l'API. Les pubs et traqueurs restent bloqués, mais en silence, consultables dans le journal.

**Délai sur iPhone.** Les notifications arrivaient parfois avec une minute de retard (regroupement par iOS en mode économie d'énergie). Corrigé en marquant les alertes comme prioritaires (`Priority: high`).

## Le compromis anti-spam, assumé

Réduire les alertes crée un angle mort : un attaquant qui utilise `sudo` dans les 10 minutes suivant une utilisation légitime ne déclenche pas de seconde alerte. Mais il aura déjà déclenché l'alerte de **connexion SSH** en entrant. Le risque est donc couvert par une autre alerte.

C'est le vrai enjeu d'un système d'alerte : **trop d'alertes tue l'alerte** (fatigue d'alerte, un problème réel des équipes de sécurité). Mieux vaut peu d'alertes fiables que beaucoup d'alertes ignorées.

## Choix de conception : alerter vs journaliser

Deux niveaux séparés :

- **Notification (le téléphone sonne)** → réservée à ce qui est grave et rare (intrusion, phishing).
- **Journal (trace écrite, sans notification)** → pour tout le reste (pubs, traqueurs, chaque IP bannie), consultable à la demande.

Pour les IP bannies, une notification par IP suffit dans un lab non exposé. En production, avec des milliers d'attaques par jour, il faudrait passer à un **résumé quotidien** pour éviter la fatigue d'alerte. Ne pas coder cette agrégation maintenant est un choix délibéré : on n'ajoute pas de complexité pour un problème qu'on n'a pas encore.

## Pistes d'amélioration

- **Résumé quotidien groupé** des bannissements, activable le jour où le serveur sera exposé.
- **Alertes silencieuses la nuit** (plage horaire) sauf événement critique.
- **Boutons d'action** dans la notification (bannir/débannir à distance) via un bot Telegram.
