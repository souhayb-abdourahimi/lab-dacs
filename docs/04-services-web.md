# 04 — Services web

## Nginx

```bash
sudo apt install nginx -y
sudo systemctl enable --now nginx
curl -I http://localhost          # doit renvoyer 200 OK
```

## Virtual host

```bash
sudo mkdir -p /var/www/lab
echo '<h1>Lab DACS</h1>' | sudo tee /var/www/lab/index.html
sudo cp configs/nginx/lab.conf /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/lab.conf /etc/nginx/sites-enabled/
sudo nginx -t                     # valider AVANT de recharger
sudo systemctl reload nginx
```

`reload` plutôt que `restart` : la configuration est rechargée sans interrompre
les connexions en cours.

## HTTPS avec un certificat auto-signé

```bash
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/lab.key \
  -out    /etc/nginx/ssl/lab.crt \
  -subj "/C=FR/ST=Occitanie/L=Montpellier/O=Lab DACS/CN=lab.local"
```

Le navigateur signalera un certificat non fiable : c'est le comportement
attendu. Un certificat auto-signé assure le chiffrement du transport mais pas
l'authentification du serveur, faute d'autorité de certification reconnue.

## Analyse du trafic

```bash
sudo tcpdump -i any -n port 80 -c 20
```

Sur l'hôte, Wireshark permet de suivre une session HTTP complète :
poignée de main TCP (SYN, SYN-ACK, ACK), requête, réponse, fermeture.
