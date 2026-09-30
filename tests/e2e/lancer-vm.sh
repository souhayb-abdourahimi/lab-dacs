#!/usr/bin/env bash
#
# tests/e2e/lancer-vm.sh — Démarre une VRAIE machine virtuelle (QEMU/KVM) à partir
# de l'image cloud officielle, prête à recevoir ./install.sh comme un serveur neuf.
#
# Variables d'environnement :
#   E2E_DISTRO    debian13 | ubuntu2404                       (défaut : debian13)
#   E2E_DIR       dossier de travail (disque, seed, journaux)  (défaut : /tmp/lab-e2e)
#   E2E_CACHE     cache des images téléchargées                (défaut : $E2E_DIR/cache)
#   E2E_ADRESSE   adresse locale où les ports de la VM sont publiés (défaut : 127.0.0.2)
#   E2E_SUDO_PW   mot de passe (sudo) de l'utilisateur de test — OBLIGATOIRE, jamais affiché
#   E2E_MEMOIRE   mémoire de la VM en Mo                       (défaut : 4096)
#
# Réseau : mode utilisateur de QEMU. Les ports 22, 53 (tcp/udp) et 8081 de la VM
# sont publiés sur E2E_ADRESSE : pour install.sh, la VM est un serveur SSH
# ordinaire sur le port 22. Publier le port 22 exige les droits root (sudo).
#
# Sécurité : clé SSH cliente, clé d'hôte et mot de passe sont créés pour ce test
# seulement (jamais versionnés). La clé d'hôte est injectée par cloud-init : son
# empreinte est connue d'avance, ce qui permet de VÉRIFIER l'identité de la VM.
set -euo pipefail

DISTRO="${E2E_DISTRO:-debian13}"
DIR="${E2E_DIR:-/tmp/lab-e2e}"
CACHE="${E2E_CACHE:-$DIR/cache}"
ADRESSE="${E2E_ADRESSE:-127.0.0.2}"
MEMOIRE="${E2E_MEMOIRE:-4096}"
UTILISATEUR=labadmin
: "${E2E_SUDO_PW:?E2E_SUDO_PW doit contenir le mot de passe de test}"

case "$DISTRO" in
  debian13)   IMAGE_URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2" ;;
  ubuntu2404) IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img" ;;
  *) echo "Distribution inconnue : $DISTRO" >&2; exit 2 ;;
esac

SUDO=""; [[ $EUID -eq 0 ]] || SUDO="sudo"
mkdir -p "$DIR" "$CACHE" "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# --- Image officielle (téléchargée une fois, jamais modifiée) ---------------
IMAGE="$CACHE/$(basename "$IMAGE_URL")"
if [[ ! -s "$IMAGE" ]]; then
  echo "Téléchargement de $IMAGE_URL"
  curl -fsSL --retry 5 --retry-delay 5 -o "$IMAGE.part" "$IMAGE_URL"
  mv "$IMAGE.part" "$IMAGE"
fi

# Disque de la VM : couche copie-sur-écriture de 20 Go au-dessus de l'image
rm -f "$DIR/disque.qcow2"
qemu-img create -q -f qcow2 -F qcow2 -b "$IMAGE" "$DIR/disque.qcow2" 20G

# --- Clés : cliente (l'« utilisateur ») et d'hôte (l'identité de la VM) -----
[[ -f "$HOME/.ssh/id_ed25519" ]] || ssh-keygen -q -t ed25519 -N "" -C "lab-e2e" -f "$HOME/.ssh/id_ed25519"
rm -f "$DIR/cle_hote" "$DIR/cle_hote.pub"
ssh-keygen -q -t ed25519 -N "" -C "lab-e2e-hote" -f "$DIR/cle_hote"
ssh-keygen -lf "$DIR/cle_hote.pub" | awk '{print $2}' > "$DIR/empreinte"
# known_hosts propre au test (vérifications), distinct de ~/.ssh/known_hosts
# qu'install.sh remplit lui-même, comme chez un vrai utilisateur
printf '%s %s\n' "$ADRESSE" "$(cut -d' ' -f1,2 "$DIR/cle_hote.pub")" > "$DIR/known_hosts"

# --- cloud-init (NoCloud) ----------------------------------------------------
HASH="$(printf '%s' "$E2E_SUDO_PW" | openssl passwd -6 -stdin)"
{
  echo "#cloud-config"
  echo "hostname: lab-e2e"
  echo "users:"
  echo "  - name: $UTILISATEUR"
  echo "    groups: [sudo]"
  echo "    shell: /bin/bash"
  # sudo AVEC mot de passe, comme sur un vrai serveur : install.sh le demande
  echo "    sudo: \"ALL=(ALL) ALL\""
  echo "    lock_passwd: false"
  echo "    hashed_passwd: '$HASH'"
  echo "    ssh_authorized_keys:"
  echo "      - $(cat "$HOME/.ssh/id_ed25519.pub")"
  # État « avant durcissement » : mot de passe et root autorisés en SSH, pour
  # prouver ensuite que le déploiement les refuse bien
  echo "ssh_pwauth: true"
  echo "disable_root: false"
  echo "ssh_deletekeys: true"
  echo "ssh_genkeytypes: [ed25519]"
  echo "ssh_keys:"
  echo "  ed25519_private: |"
  sed 's/^/    /' "$DIR/cle_hote"
  echo "  ed25519_public: $(cat "$DIR/cle_hote.pub")"
  echo "write_files:"
  echo "  - path: /root/.ssh/authorized_keys"
  echo "    permissions: '0600'"
  echo "    content: |"
  echo "      $(cat "$HOME/.ssh/id_ed25519.pub")"
} > "$DIR/user-data"
printf 'instance-id: lab-e2e-%s\nlocal-hostname: lab-e2e\n' "$(date +%s)" > "$DIR/meta-data"
cloud-localds "$DIR/seed.img" "$DIR/user-data" "$DIR/meta-data"
rm -f "$DIR/user-data"   # contient le hash du mot de passe et la clé d'hôte

# --- Démarrage ---------------------------------------------------------------
ACCEL="tcg"; CPU="max"
if [[ -w /dev/kvm ]]; then ACCEL="kvm"; CPU="host"; fi
echo "Démarrage de la VM $DISTRO (accélération : $ACCEL, mémoire : ${MEMOIRE} Mo)"
$SUDO qemu-system-x86_64 \
  -machine "q35,accel=$ACCEL" -cpu "$CPU" -smp 2 -m "$MEMOIRE" \
  -drive "file=$DIR/disque.qcow2,if=virtio,format=qcow2" \
  -drive "file=$DIR/seed.img,if=virtio,format=raw" \
  -netdev "user,id=n0,hostfwd=tcp:$ADRESSE:22-:22,hostfwd=tcp:$ADRESSE:53-:53,hostfwd=udp:$ADRESSE:53-:53,hostfwd=tcp:$ADRESSE:8081-:8081" \
  -device virtio-net-pci,netdev=n0 \
  -display none -serial "file:$DIR/console.log" \
  -pidfile "$DIR/qemu.pid" -daemonize

# --- Attente de SSH puis de la fin de cloud-init -----------------------------
SSH=(ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes
     -o UserKnownHostsFile="$DIR/known_hosts" "$UTILISATEUR@$ADRESSE")
LIMITE=$(( $(date +%s) + ${E2E_ATTENTE:-600} ))
until "${SSH[@]}" true 2>/dev/null; do
  if (( $(date +%s) > LIMITE )); then
    echo "La VM ne répond pas en SSH. Fin de la console :" >&2
    $SUDO tail -n 60 "$DIR/console.log" >&2 || true
    exit 1
  fi
  sleep 5
done
"${SSH[@]}" "cloud-init status --wait >/dev/null; cloud-init status --long | head -3"
echo "VM $DISTRO prête : $UTILISATEUR@$ADRESSE (empreinte attendue : $(cat "$DIR/empreinte"))"
