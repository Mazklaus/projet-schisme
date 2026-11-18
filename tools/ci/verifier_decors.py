#!/usr/bin/env python3
"""Vérifie les décors 2.5D (assets/decors/*/decor.json) selon le contrat moteur ↔ chaîne d'images.

Échoue (code 1) si un décor est invalide : version, fichiers absents, nommage <NN>_<nom>.png,
normales d'une autre taille que l'image, côté > 8192 px, calque hors du décor.
Usage : python3 tools/ci/verifier_decors.py [racine_du_depot]
"""
import json
import os
import re
import sys

from PIL import Image

VERSION = 1
COTE_MAX = 8192
CALQUES_MAX = 16
NOM = re.compile(r"^\d{2}_[a-z0-9_]+\.png$")


def verifier(dossier):
    erreurs = []
    chemin = os.path.join(dossier, "decor.json")
    try:
        with open(chemin, encoding="utf-8") as f:
            d = json.load(f)
    except (OSError, ValueError) as e:
        return [f"decor.json illisible : {e}"]
    if d.get("version") != VERSION:
        erreurs.append(f"version {d.get('version')} (attendu {VERSION})")
    taille = d.get("taille")
    if not (isinstance(taille, list) and len(taille) == 2 and all(isinstance(v, int) and v > 0 for v in taille)):
        return erreurs + ["taille absente ou invalide"]
    calques = d.get("calques") or []
    if not calques:
        erreurs.append("aucun calque")
    if len(calques) > CALQUES_MAX:
        erreurs.append(f"{len(calques)} calques (max {CALQUES_MAX})")
    for i, k in enumerate(calques):
        f = k.get("fichier", "")
        if not NOM.match(f):
            erreurs.append(f"calque {i} : nom « {f} » hors convention <NN>_<nom>.png")
        p = os.path.join(dossier, f)
        if not os.path.isfile(p):
            erreurs.append(f"{f} : introuvable")
            continue
        img = Image.open(p)
        if max(img.size) > COTE_MAX:
            erreurs.append(f"{f} : côté > {COTE_MAX} px")
        if img.mode not in ("RGBA", "RGB", "LA", "L", "P"):
            erreurs.append(f"{f} : mode {img.mode} non géré")
        x, y = k.get("position", [0, 0])
        if x < 0 or y < 0 or x + img.size[0] > taille[0] or y + img.size[1] > taille[1]:
            erreurs.append(f"{f} : sort du décor ({taille[0]}×{taille[1]})")
        prof = k.get("profondeur", 1.0)
        if not isinstance(prof, (int, float)) or not 0 <= prof <= 2:
            erreurs.append(f"{f} : profondeur hors de [0, 2]")
        n = k.get("normales")
        if n:
            pn = os.path.join(dossier, n)
            if not os.path.isfile(pn):
                erreurs.append(f"{n} : introuvable")
            elif Image.open(pn).size != img.size:
                erreurs.append(f"{n} : taille différente de {f}")
    return erreurs


def main():
    racine = sys.argv[1] if len(sys.argv) > 1 else "."
    base = os.path.join(racine, "assets", "decors")
    total = 0
    ko = 0
    for nom in sorted(os.listdir(base)) if os.path.isdir(base) else []:
        dossier = os.path.join(base, nom)
        if not os.path.isdir(dossier):
            continue
        total += 1
        for e in verifier(dossier):
            ko += 1
            print(f"::error file=assets/decors/{nom}/decor.json::{nom} : {e}")
    print(f"{total} décor(s) vérifié(s), {ko} erreur(s)")
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
