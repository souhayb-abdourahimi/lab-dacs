# Architecture et choix techniques

## Le montage

Tout le lab tourne dans une **VM Debian 13** hébergée sur mon PC via **KVM/QEMU**. La VM n'a pas d'interface graphique : elle s'administre entièrement à distance en SSH, comme un vrai serveur. C'est un choix volontaire, pour travailler dans les conditions réelles de l'administration système.

Les services applicatifs (supervision, filtre DNS) tournent dans des **conteneurs Docker**, ce qui rend chaque brique isolée, reproductible et facile à redéployer. Les briques système (SSH, CrowdSec, alertes) sont installées directement sur la VM.

## Pourquoi ces choix

**Une VM plutôt que la machine réelle.** Un lab de sécurité doit pouvoir être cassé et reconstruit sans risque. La VM isole complètement les expérimentations de mon poste de travail.

**Docker pour les services.** Plutôt qu'installer chaque logiciel à la main, un fichier `docker-compose.yml` décrit toute la stack. On relance tout d'une commande, et la configuration est versionnée sur Git. C'est la logique « infrastructure as code ».

**Accès par tunnel SSH plutôt qu'exposition directe.** Les interfaces d'administration (Grafana, AdGuard) n'écoutent que sur `127.0.0.1` de la VM. On y accède en créant un tunnel SSH depuis le PC. Résultat : même si un attaquant est sur le réseau local, il ne voit aucune interface d'admin exposée.

## Le réseau

La VM reçoit une adresse sur le réseau virtuel de KVM (`192.168.122.0/24`) et sort sur internet via le NAT de l'hôte, un peu comme un appareil derrière une box.

Le PC utilise la VM comme **serveur DNS** : chaque site visité est d'abord vérifié par le filtre. Un DNS de secours public (Quad9) est configuré en second, pour garder internet si la VM est éteinte.

## Problèmes rencontrés

**Docker sur l'hôte bloquait le NAT de la VM.** Au premier lancement, la VM n'avait pas internet alors que le PC, oui. Cause : Docker, installé aussi sur le PC, insère au démarrage une règle de pare-feu qui rejette par défaut tout le trafic *transféré* (`FORWARD`), y compris celui des VM de KVM. Solution : autoriser explicitement le trafic de l'interface virtuelle de KVM dans la chaîne prévue par Docker.

```bash
sudo iptables -I DOCKER-USER -i virbr0 -j ACCEPT
sudo iptables -I DOCKER-USER -o virbr0 -j ACCEPT
```

C'est un cas classique de **conflit entre deux outils qui gèrent le même pare-feu** sans se concerter. Diagnostic : le PC pingait internet, la VM non, ce qui pointait vers le transfert de paquets côté hôte.

**Clavier QWERTY/AZERTY sur la console de la VM.** Les premières connexions échouaient sur le mot de passe. La VM était en QWERTY et le PC en AZERTY : les mêmes touches produisaient des caractères différents. Corrigé avec `loadkeys fr` puis `dpkg-reconfigure keyboard-configuration`.

## Limites connues et pistes d'amélioration

- **Le PC dépend de la VM pour naviguer.** Si la VM est éteinte, le DNS de secours prend le relais, mais avec NetworkManager la bascule n'est pas instantanée (quelques secondes, parfois une reconnexion wifi). Un vrai secours haute disponibilité demanderait un second résolveur toujours joignable.
- **Les règles iptables de l'hôte ne survivent pas au redémarrage du PC.** Il faut les remettre après chaque reboot. À rendre permanent avec un service au démarrage ou `iptables-persistent`.
- **Reconstruction manuelle.** Aujourd'hui, remonter le lab demande de rejouer les étapes. Prochaine étape : tout automatiser avec **Ansible**, pour déployer un serveur identique en une commande.
