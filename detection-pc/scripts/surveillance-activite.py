#!/usr/bin/env python3
# Alerte + verrouille si activite pendant le mode vigilance
# Delai de grace de 10 s apres l'armement (pour partir sans se faire detecter)
import time, glob, subprocess, select
from pathlib import Path
import evdev

DRAPEAU = Path.home() / ".local/state/mode-vigilance"
CONF = Path.home() / ".config/lab-dacs/detection.conf"
CAPTURE = Path.home() / ".local/bin/capture-intrus.sh"

def topic():
    try:
        for l in open(CONF):
            if l.startswith("NTFY_TOPIC="):
                return l.strip().split("=", 1)[1].strip('"')
    except Exception:
        return None

def reagir():
    subprocess.run([str(CAPTURE)],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["loginctl", "lock-session"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    t = topic()
    if not t:
        return
    quand = time.strftime("%d/%m/%Y %H:%M:%S")
    subprocess.run(["curl", "-s", "-m", "5",
        "-H", "Title: Intrusion - ecran verrouille",
        "-H", "Tags: rotating_light", "-H", "Priority: urgent",
        "-d", f"Activite detectee en mode absent. Ecran verrouille automatiquement.\nQuand : {quand}",
        f"https://ntfy.sh/{t}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# Les peripheriques ne sont lisibles qu'avec le groupe "input", actif apres
# reconnexion : on ignore ceux qu'on ne peut pas ouvrir au lieu de planter.
devices = []
for p in glob.glob("/dev/input/event*"):
    try:
        devices.append(evdev.InputDevice(p))
    except (PermissionError, OSError):
        pass
if not devices:
    print("Aucun peripherique d'entree lisible : reconnectez-vous (groupe input).")
    exit(0)
dev_map = {d.fd: d for d in devices}
dernier = 0
arme_depuis = 0
etait_arme = False

while True:
    r, _, _ = select.select(dev_map, [], [], 1)
    for fd in r:
        try:
            for _ in dev_map[fd].read():
                pass
        except OSError:
            pass

    arme = DRAPEAU.exists()
    # On note l'instant ou la vigilance vient d'etre armee
    if arme and not etait_arme:
        arme_depuis = time.time()
    etait_arme = arme

    if not arme:
        continue
    # Delai de grace : on ignore l'activite pendant 10 s apres l'armement
    if time.time() - arme_depuis < 10:
        continue

    if r:
        maintenant = time.time()
        if maintenant - dernier > 30:
            dernier = maintenant
            reagir()
