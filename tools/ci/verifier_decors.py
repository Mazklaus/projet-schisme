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


def verifier_guide(dossier, chemin, g):
    """<plan>.json du guide de style de la DA (§6) : fichiers, _normal et _ombre à la bonne taille."""
    erreurs = []
    # Guide de style (cadre_px) ou planche de CA2 (resolution).
    cadre = g.get("cadre_px", g.get("resolution"))
    if not (isinstance(cadre, list) and len(cadre) == 2):
        return ["cadre_px absent ou invalide"]
    for k in g.get("calques") or []:
        f = k.get("fichier", "")
        p = os.path.join(dossier, f)
        gabarit = os.path.join(dossier, os.path.dirname(f), "gabarit_" + os.path.basename(f))
        if not os.path.isfile(p) and os.path.isfile(gabarit):
            p = gabarit
        if not os.path.isfile(p):
            print(f"::warning file={chemin}::{f} absent (calque ignoré par le moteur)")
            continue
        taille = Image.open(p).size
        if list(taille) != list(cadre):
            erreurs.append(f"{f} : {taille[0]}×{taille[1]} au lieu du cadre {cadre[0]}×{cadre[1]}")
        t = k.get("tete")
        if isinstance(t, dict):
            if "pivot_px" not in t:
                erreurs.append(f"{f} : bloc tete sans pivot_px")
            for cle in ("corps", "fichier", "avant"):
                if cle in t:
                    q = os.path.join(dossier, t[cle])
                    if not os.path.isfile(q):
                        erreurs.append(f"{f} : tete.{cle} introuvable ({t[cle]})")
                    elif Image.open(q).size != taille:
                        erreurs.append(f"{t[cle]} : taille différente de {f}")
        for suffixe in ("_normal.png", "_ombre.png", "_plat.png", "_plat_normal.png"):
            q = p[:-4] + suffixe
            if os.path.isfile(q) and Image.open(q).size != taille:
                erreurs.append(f"{os.path.basename(q)} : taille différente de {f}")
    return erreurs


def verifier(dossier):
    erreurs = []
    chemin = os.path.join(dossier, "decor.json")
    if not os.path.isfile(chemin):
        for f in sorted(os.listdir(dossier)):
            if f.endswith(".json"):
                with open(os.path.join(dossier, f), encoding="utf-8") as fic:
                    try:
                        g = json.load(fic)
                    except ValueError as e:
                        return [f"{f} illisible : {e}"]
                if "cadre_px" in g or ("resolution" in g and "calques" in g):
                    return verifier_guide(dossier, os.path.join(dossier, f), g)
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
