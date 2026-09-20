#!/usr/bin/env python3
# Alerte + verrouille l'ecran si activite pendant le mode vigilance
import time, glob, subprocess, select
from pathlib import Path
import evdev

DRAPEAU = Path.home() / ".local/state/mode-vigilance"

def topic():
    try:
        for l in open("/etc/lab-alertes.conf"):
            if l.startswith("NTFY_TOPIC="):
                return l.strip().split("=", 1)[1]
    except Exception:
        return None

def reagir():
    # 1) On verrouille l'ecran tout de suite
    subprocess.run(["loginctl", "lock-session"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # 2) On alerte
    t = topic()
    if not t:
        return
    quand = time.strftime("%d/%m/%Y %H:%M:%S")
    subprocess.run(["curl", "-s", "-m", "5",
        "-H", "Title: Intrusion - ecran verrouille",
        "-H", "Tags: rotating_light", "-H", "Priority: urgent",
        "-d", f"Activite detectee en mode absent. Ecran verrouille automatiquement.\nQuand : {quand}",
        f"https://ntfy.sh/{t}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

devices = [evdev.InputDevice(p) for p in glob.glob("/dev/input/event*")]
if not devices:
    exit(0)
dev_map = {d.fd: d for d in devices}
dernier = 0

while True:
    r, _, _ = select.select(dev_map, [], [], 1)
    for fd in r:
        try:
            for _ in dev_map[fd].read():
                pass
        except OSError:
            pass
    if DRAPEAU.exists() and r:
        maintenant = time.time()
        if maintenant - dernier > 30:
            dernier = maintenant
            reagir()
