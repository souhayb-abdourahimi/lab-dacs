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
    if CAPTURE.exists():   # la capture webcam est optionnelle
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
# Hotplug : la liste /dev/input/event* est relue toutes les RESCAN secondes,
# pour surveiller aussi un clavier ou une souris branche apres le demarrage ;
# un peripherique debranche (lecture en erreur) est retire de la surveillance.
RESCAN = 2
ouverts = {}   # chemin -> InputDevice
ignores = set()  # chemins illisibles (droits), retentes seulement s'ils reapparaissent


def fermer(chemin):
    dev = ouverts.pop(chemin, None)
    if dev is not None:
        try:
            dev.close()
        except OSError:
            pass


def rescanner():
    presents = set(glob.glob("/dev/input/event*"))
    for chemin in list(ouverts):
        if chemin not in presents:
            fermer(chemin)
    ignores.intersection_update(presents)
    for chemin in presents - set(ouverts) - ignores:
        try:
            ouverts[chemin] = evdev.InputDevice(chemin)
        except (PermissionError, OSError):
            ignores.add(chemin)


rescanner()
if not ouverts:
    print("Aucun peripherique d'entree lisible pour l'instant : reconnectez-vous (groupe input)."
          " En attente d'un peripherique...", flush=True)
dernier = 0
arme_depuis = 0
etait_arme = False
dernier_scan = time.monotonic()

while True:
    if time.monotonic() - dernier_scan >= RESCAN:
        rescanner()
        dernier_scan = time.monotonic()

    par_fd = {d.fd: (chemin, d) for chemin, d in ouverts.items()}
    if par_fd:
        try:
            r, _, _ = select.select(list(par_fd), [], [], 1)
        except (OSError, ValueError):
            # Un descripteur est devenu invalide (debranchement) : on repart d'un scan propre
            rescanner()
            dernier_scan = time.monotonic()
            continue
    else:
        time.sleep(1)
        r = []

    for fd in r:
        chemin, dev = par_fd[fd]
        try:
            for _ in dev.read():
                pass
        except BlockingIOError:
            pass
        except OSError:
            # Peripherique debranche (ENODEV) : il sera re-ouvert s'il revient
            fermer(chemin)

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
