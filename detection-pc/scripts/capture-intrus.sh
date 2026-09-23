#!/bin/bash
# Prend une photo de l'intrus, l'envoie sur le tel et en garde une copie sur le serveur
DRAPEAU_PHOTO="$HOME/.local/state/photo-autorisee"
[ -f "$DRAPEAU_PHOTO" ] || exit 0   # photo desactivee : on ne fait rien

CONF="$HOME/.config/lab-dacs/detection.conf"
[ -r "$CONF" ] && . "$CONF"
[ -z "$NTFY_TOPIC" ] && exit 0
WEBCAM="${WEBCAM:-/dev/video0}"

HORODATAGE=$(date '+%Y%m%d-%H%M%S')
PHOTO="/tmp/intrus-$HORODATAGE.jpg"

# Notif d'activation camera (transparence)
curl -s -m 5 -H "Title: Camera activee" -H "Tags: camera" \
  -d "Prise de photo en cours suite a une intrusion" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1

# Capture avec temps de chauffe ; timeout pour liberer la camera quoi qu'il arrive
timeout 10 ffmpeg -y -f v4l2 -i "$WEBCAM" -frames:v 30 -vf "select=eq(n\,29)" -update 1 "$PHOTO" 2>/dev/null
[ -f "$PHOTO" ] || exit 0

# Envoi de la photo en piece jointe sur le telephone
curl -s -m 15 -T "$PHOTO" \
  -H "Title: Photo de l'intrus" -H "Tags: rotating_light" -H "Priority: urgent" \
  -H "Filename: intrus-$HORODATAGE.jpg" \
  "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1

# Copie de preuve sur le serveur (hors de portee d'un intrus sur le PC), si configure.
# BatchMode : jamais de demande de mot de passe qui bloquerait le script.
if [ -n "$SERVEUR_PREUVES" ]; then
  scp -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
    "$PHOTO" "$SERVEUR_PREUVES:~/preuves/" 2>/dev/null
fi

rm -f "$PHOTO"
