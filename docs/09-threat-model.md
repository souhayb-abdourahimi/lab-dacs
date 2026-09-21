# Modèle de menaces (Threat Model)

Ce document décrit honnêtement ce que le lab protège, ce qu'il ne protège pas, et ses limites. Un système de sécurité qui prétend tout protéger n'est pas crédible. La valeur d'un modèle de menaces est justement de tracer clairement les frontières.

---

## Nature du projet

Ce lab est un **laboratoire d'apprentissage** de la détection et de la réponse sur un serveur Linux auto-hébergé et sur un poste de travail. Ce n'est **pas** un produit de sécurité certifié, ni un EDR (Endpoint Detection and Response) commercial. Il démontre des principes et des compétences, dans un environnement maîtrisé.

---

## Ce que le système vise à faire

**Sur le serveur :**
- Rendre inutile un mot de passe SSH volé (authentification par clé uniquement).
- Détecter et bloquer automatiquement les attaques par force brute SSH (CrowdSec + bouncer nftables).
- Filtrer les domaines de phishing, de malware et de pistage au niveau DNS (AdGuard Home).
- Alerter l'administrateur en temps réel sur mobile lors d'un événement de sécurité (connexion SSH, passage en root, IP bannie, site dangereux bloqué).
- Superviser l'état du serveur pour rendre visible un comportement anormal (Prometheus + Grafana).

**Sur le poste de travail :**
- Détecter un accès physique non autorisé pendant une absence (activité clavier/souris, déverrouillage, branchement USB).
- Réagir automatiquement : verrouiller l'écran, capturer une photo, alerter, conserver une preuve hors de la machine.

**Sur le déploiement :**
- Reconstruire l'ensemble du serveur de façon reproductible et automatisée (Ansible), sans exposer de secret (Ansible Vault).

---

## Ce que le système ne vise PAS à faire

Ces limites sont assumées et importantes :

- **Il ne remplace pas un EDR ou un antivirus.** Il ne détecte pas les malwares en mémoire, les rootkits, ni les techniques d'évasion avancées.
- **Il ne résiste pas à un attaquant qui a déjà obtenu les droits root.** Un attaquant root peut désactiver CrowdSec, effacer les alertes locales et arrêter les scripts. La seule mitigation en place est que les alertes et les preuves **quittent la machine immédiatement** (notification push, copie sur le serveur), donc l'événement est signalé avant qu'il puisse être effacé — mais le système lui-même n'est pas inviolable.
- **Il ne garantit pas une preuve forensique irréfutable.** Les photos et logs sont des indices, pas des preuves à valeur légale (pas de chaîne de custody, pas d'horodatage certifié).
- **Il ne protège pas contre les canaux qui contournent le DNS.** Un VPN, le DNS-over-HTTPS d'un navigateur, ou une application utilisant son propre résolveur échappent au filtre AdGuard. Cette limite a été observée directement pendant les tests.
- **Il ne se substitue pas à une étude juridique.** Le module de détection d'accès au poste capture des images via webcam. Sur une machine personnelle, c'est un droit. En entreprise, filmer des personnes est strictement encadré (RGPD, CNIL, information obligatoire des salariés) et ne peut pas être déployé sans cadre légal.

---

## Précision importante : pas de keylogging

Le module de détection d'accès au poste surveille **l'activité** clavier et souris, c'est-à-dire la présence de mouvements ou de frappes, pour détecter que quelqu'un utilise la machine. Il **ne capture pas le contenu** de ce qui est tapé. Ce n'est **pas** un keylogger. Cette distinction est essentielle : détecter qu'une touche est pressée est très différent d'enregistrer quelles touches sont pressées, tant sur le plan technique que juridique.

---

## Adversaires considérés

Le lab est pensé face à des adversaires réalistes pour un particulier ou une petite structure :

| Adversaire | Couvert ? | Comment |
|------------|-----------|---------|
| Attaquant distant testant des mots de passe SSH | Oui | Clé obligatoire + CrowdSec |
| Bot scannant internet à la recherche de failles | Partiellement | CrowdSec + liste communautaire (si serveur exposé) |
| Utilisateur curieux accédant physiquement au poste | Oui | Détection d'activité + verrouillage + photo |
| Phishing / faux site visité par l'utilisateur | Partiellement | Filtre DNS (sauf contournement VPN/DoH) |
| Attaquant ayant déjà le root sur la machine | Non | Hors périmètre (alerte avant effacement seulement) |
| Malware sophistiqué / rootkit | Non | Hors périmètre |
| Attaque physique avec accès matériel (démontage) | Non | Hors périmètre |

---

## Hypothèses de confiance

Le modèle suppose que :
- Le PC hôte et l'administrateur sont de confiance.
- La clé SSH privée reste secrète.
- Le mot de passe du coffre Ansible Vault reste secret et hors de Git.
- Le serveur de notification (ntfy) et le canal secret ne sont pas compromis.
- La machine n'est pas déjà compromise au moment du déploiement.

---

## Principes de sécurité appliqués

Le lab met en œuvre plusieurs principes reconnus :

- **Moindre privilège** : root interdit en direct, une clé SSH par machine, ports d'admin liés à localhost.
- **Défense en profondeur** : plusieurs couches (clé SSH + CrowdSec + alertes) plutôt qu'une seule barrière.
- **Les preuves quittent la machine attaquée** : alertes push et copie des preuves sur un autre hôte, pour résister à l'effacement.
- **Séparation des secrets** : aucun secret dans le code, chiffrement Vault, fichiers de secrets générés au déploiement.
- **Fatigue d'alerte maîtrisée** : notification uniquement pour les événements graves et rares ; le reste est journalisé sans déranger.

---

## Pistes d'amélioration du modèle

Pour renforcer réellement le niveau de sécurité, dans l'ordre de valeur :

1. **Centraliser les journaux hors de la VM** en temps réel, pour résister à un attaquant root qui effacerait les traces locales.
2. **Détection PAM des échecs de connexion**, pour repérer une attaque avant même l'ouverture de session.
3. **Surveillance réseau** (ARP, scan de ports) pendant le mode vigilance, en mode alerte.
4. **Intégrité des logs et des événements** (horodatage, hachage en chaîne) pour se rapprocher d'une valeur forensique.
5. **Tests automatisés (CI)** validant que chaque brique répond comme attendu après un changement.

---

*Ce modèle de menaces est volontairement honnête sur ses limites. C'est cette honnêteté qui distingue un travail d'ingénierie sérieux d'une démonstration qui surestime ses propres capacités.*
