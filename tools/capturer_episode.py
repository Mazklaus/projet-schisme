#!/usr/bin/env python3
"""Captures automatiques d'un épisode : une image par scène, par état, par plan et par gros plan.

    python3 tools/capturer_episode.py ep01 [--godot ~/godot/godot] [--build NOM] [--reference NOM]

Le jeu est lancé sans fenêtre (xvfb-run, rendu opengl3) sur le banc tools/ci/capturer_episode.gd,
qui monte chaque cadre avec le moteur du jeu :
  - scènes : chaque décor de l'épisode (.dlg, fichiers jeu des chapitres, plans), dans chacun de
    ses états (jour, nuit, aube…), cadre complet, ambiance et lumières du chapitre ;
  - plans : chaque « @plan <nom> » des .dlg, caméra à la fin de sa séquence, sur son décor ;
  - gros plans : chaque scène de gros_plans.json, un cadre par personnage (fond de CA2, buste de CA1).
Sortie : qa/captures/<build>/<id>.jpg (ou .png avec --png), index.json, et une planche contact
avant/après (planche_NN.jpg, rapport.md) contre la build précédente (le dossier le plus récent de
qa/captures/, ou --reference). Les ids commencent par le nom du décor : verifier_episode.py y
trouve les captures exigées pour un décor « fini ».
"""
import argparse
import datetime
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageChops, ImageFont, ImageStat

ICI = Path(__file__).resolve().parent
RACINE = ICI.parent
BANC = "res://tools/ci/capturer_episode.gd"
VIGNETTE = (480, 270)
PAR_PLANCHE = 12
SEUIL_CHANGE = 2.0  # écart moyen (/255) au-delà duquel une capture est « changée »


def journal(msg):
    print(f"[capturer] {msg}", flush=True)


def charger(chemin):
    try:
        with open(chemin, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def res(racine, chemin):
    return Path(racine) / chemin.replace("res://", "") if chemin.startswith("res://") else Path(chemin)


def sur(nom):
    return re.sub(r"[^a-z0-9_]+", "_", str(nom).lower()).strip("_")


# ------------------------------------------------------------------ inventaire de l'épisode


def evenements_dlg(chemin):
    """(« decor » | « plan », valeur) dans l'ordre du fichier."""
    with open(chemin, encoding="utf-8") as f:
        for ligne in f:
            m = re.match(r"^\s*@(decor|plan)\s+(\S+)", ligne)
            if m:
                yield m.group(1), m.group(2)


def decors_du_jeu(d, sortie):
    """Décors cités par un fichier jeu de chapitre : valeurs « decor » et clés de « decors »."""
    if isinstance(d, dict):
        for k, v in d.items():
            if k == "decor" and isinstance(v, str):
                sortie.append(v)
            elif k == "decors" and isinstance(v, dict):
                sortie.extend(x for x in v if not x.startswith("_"))
            else:
                decors_du_jeu(v, sortie)
    elif isinstance(d, list):
        for v in d:
            decors_du_jeu(v, sortie)
    return sortie


def etats_du_decor(racine, decor):
    sys.path.insert(0, str(Path(racine) / "tools" / "ci"))
    from verifier_episode import json_du_decor
    dossier = Path(racine) / "assets" / "decors" / decor
    if not dossier.is_dir():
        return None
    _, d, _ = json_du_decor(str(dossier))
    if not isinstance(d, dict):
        return None
    if isinstance(d.get("etats"), dict):
        return [e for e in d["etats"] if not e.startswith("_")]
    # fonds de gros plan : états portés par les calques
    vus = []
    for k in d.get("calques", []):
        if isinstance(k, dict) and isinstance(k.get("etat"), str) and k["etat"] not in vus:
            vus.append(k["etat"])
    return vus


def fin_de_sequence(seq):
    """Caméra à la fin d'une séquence (dernière clé : position et zoom absolus)."""
    seq = [p for p in seq if isinstance(p, dict)]
    if not seq:
        return None
    for p in reversed(seq):
        if "position" in p:
            return {"position": p["position"], "zoom": float(p.get("zoom", 1.0))}
    return None


def inventaire(ep, racine=RACINE):
    """Liste des travaux du banc et des points non capturables (absents, bustes manquants…)."""
    racine = Path(racine)
    alias = charger(racine / "data" / "decors_alias.json") or {}

    def resoudre(nom):
        a = alias.get(nom) if isinstance(alias.get(nom), dict) else {}
        return a.get("decor", nom), a.get("etat", "")

    episode = charger(racine / "data" / "episodes" / ep / "episode.json") or {}
    plans, fichiers_plans = {}, []
    for c in episode.get("chapitres", []):
        p = c.get("plans", [])
        fichiers_plans += [p] if isinstance(p, str) else list(p)
    fichiers_plans = fichiers_plans or [str(racine / "data" / "episodes" / ep / "plans.json")]
    for f in fichiers_plans:
        d = charger(res(racine, f))
        if isinstance(d, dict):
            for k, v in d.items():
                if not k.startswith("_") and k not in plans and isinstance(v, (dict, list)):
                    plans[k] = v

    dlgs = sorted(glob.glob(str(racine / "data" / "dialogues" / ep / "*.dlg")))
    scenes, plans_vus, manques = {}, {}, []
    for chemin in dlgs:
        courant, etat_courant = None, ""
        for cmd, val in evenements_dlg(chemin):
            if cmd == "decor":
                courant, etat_courant = resoudre(val)
                scenes.setdefault(courant, set()).add(etat_courant)
            elif val in ("large", "serre") or val.startswith("serre:"):
                continue
            elif val not in plans:
                manques.append(f"plan « {val} » ({os.path.basename(chemin)}) absent des plans de l'épisode")
            elif val not in plans_vus:
                p = plans[val]
                seq = p.get("sequence", []) if isinstance(p, dict) else p
                decor, etat = resoudre(p["decor"]) if isinstance(p, dict) and p.get("decor") else (courant, etat_courant)
                if decor == courant and not etat:  # le jeu garde l'état du décor courant (alias)
                    etat = etat_courant
                if isinstance(p, dict) and p.get("etat"):  # état propre au plan (plan serré de nuit)
                    etat = p["etat"]
                if not decor:
                    manques.append(f"plan « {val} » sans décor connu ({os.path.basename(chemin)})")
                    continue
                if isinstance(p, dict) and p.get("decor"):
                    scenes.setdefault(decor, set()).add(etat)
                plans_vus[val] = {"decor": decor, "etat": etat, "camera": fin_de_sequence(seq),
                                  "textures": p.get("textures", {}) if isinstance(p, dict) else {}}
    for c in episode.get("chapitres", []):
        if c.get("jeu"):
            for nom in decors_du_jeu(charger(res(racine, c["jeu"])), []):
                d, e = resoudre(nom)
                scenes.setdefault(d, set()).add(e)

    travaux = []
    for decor in sorted(scenes):
        etats = etats_du_decor(racine, decor)
        if etats is None:
            manques.append(f"décor {decor} absent du dépôt")
            continue
        for etat in (etats or [""]):
            travaux.append({"id": sur(f"{decor}__{etat}" if etat else decor), "type": "decor",
                            "decor": decor, "etat": etat, "camera": None, "textures": {}})
    for nom, p in plans_vus.items():
        if etats_du_decor(racine, p["decor"]) is None:
            continue
        travaux.append({"id": sur(f"{p['decor']}__plan_{nom}"), "type": "decor", "plan": nom, **p})

    gp = charger(racine / "data" / "episodes" / ep / "gros_plans.json") or {}
    persos = racine / "assets" / "personnages"
    for s in gp.get("scenes", []) if isinstance(gp, dict) else []:
        fond = s.get("decor")
        if not fond:
            continue
        etats = etats_du_decor(racine, fond)
        if etats is None:
            manques.append(f"fond de gros plan {fond} absent du dépôt")
            continue
        etats = [s["etat"]] if s.get("etat") else (etats or [""])
        for perso, cote in sorted(s.get("cotes", {}).items()):
            dossier = persos / perso.lower()
            if not (list(dossier.glob(f"buste_{cote}_*.png")) or (dossier / "buste.png").is_file()):
                manques.append(f"gros plan {fond} : pas de buste {cote} pour {perso}")
                continue
            for etat in etats:
                scene = dict(s, etat=etat) if etat else dict(s)
                travaux.append({"id": sur(f"{fond}__{perso}" + (f"__{etat}" if etat and len(etats) > 1 else "")),
                                "type": "gros_plan", "fond": fond, "scene": scene, "perso": perso, "cote": cote,
                                "chapitre": s.get("chapitre", "")})
    manques = list(dict.fromkeys(manques))
    vus, uniques = set(), []
    for t in travaux:
        if t["id"] not in vus:
            vus.add(t["id"])
            uniques.append(t)
    return uniques, manques


# ------------------------------------------------------------------ rendu


def trouver_godot(choix=None):
    for c in [choix, os.environ.get("GODOT"), shutil.which("godot"), os.path.expanduser("~/godot/godot")]:
        if c and os.path.isfile(c) and os.access(c, os.X_OK):
            return c
    sys.exit("Godot introuvable : --godot <binaire> ou variable GODOT")


def rendre(travaux, dossier_png, godot, racine=RACINE):
    liste = Path(dossier_png) / "travaux.json"
    liste.write_text(json.dumps({"sortie": str(Path(dossier_png).resolve()), "travaux": travaux},
                                ensure_ascii=False, indent=1), encoding="utf-8")
    # import incrémental à chaque fois : sinon une classe ajoutée depuis le dernier import (class_name)
    # reste inconnue et le banc échoue à la compilation
    journal("import du projet")
    subprocess.run([godot, "--headless", "--path", str(racine), "--import"], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    cmd = [godot, "--rendering-driver", "opengl3", "--path", str(racine), "-s", BANC, "--", str(liste)]
    if shutil.which("xvfb-run") and not os.environ.get("DISPLAY"):
        cmd = ["xvfb-run", "-a", "-s", "-screen 0 1920x1080x24"] + cmd
    journal(f"rendu de {len(travaux)} cadres")
    p = subprocess.run(cmd, capture_output=True, text=True,
                       env=dict(os.environ, SCHISME_SANS_DEBUG=os.environ.get("SCHISME_SANS_DEBUG", "1")))
    echecs = [l for l in (p.stdout + p.stderr).splitlines() if l.startswith("ECHEC") or "SCRIPT ERROR" in l]
    return echecs


# ------------------------------------------------------------------ planche contact


def ecart(a, b):
    a = a.convert("RGB").resize(VIGNETTE)
    b = b.convert("RGB").resize(VIGNETTE)
    return sum(ImageStat.Stat(ImageChops.difference(a, b)).mean) / 3


def build_precedente(dossier_captures, build):
    autres = sorted(d.name for d in Path(dossier_captures).iterdir()
                    if d.is_dir() and d.name != build and (d / "index.json").is_file()
                    and (any(d.glob("*.jpg")) or any(d.glob("[!p]*.png")))) \
        if Path(dossier_captures).is_dir() else []
    return autres[-1] if autres else None


def image_de(dossier, ident):
    for ext in (".jpg", ".png"):
        p = Path(dossier) / (ident + ext)
        if p.is_file():
            return p
    return None


def planche(dossier, ids, reference=None):
    """Planches avant/après (12 lignes par page) et rapport ; renvoie le résumé par id."""
    statut = {}
    lignes = []
    for i in ids:
        apres = image_de(dossier, i)
        avant = image_de(reference, i) if reference else None
        if apres is None:
            continue
        if avant is None:
            statut[i] = ("nouveau", None)
        else:
            e = ecart(Image.open(avant), Image.open(apres))
            statut[i] = ("changé" if e > SEUIL_CHANGE else "identique", round(e, 1))
        lignes.append((i, avant, apres))
    disparus = sorted(Path(p).stem for p in glob.glob(str(Path(reference) / "*.*"))
                      if Path(p).suffix in (".jpg", ".png") and not Path(p).stem.startswith("planche")
                      and Path(p).stem not in statut) if reference else []
    # changés et nouveaux d'abord : c'est ce que la DA doit regarder
    ordre = {"changé": 0, "nouveau": 1, "identique": 2}
    lignes.sort(key=lambda x: (ordre[statut[x[0]][0]], x[0]))
    w, h = VIGNETTE
    marge, titre = 16, 34
    try:
        police = ImageFont.load_default(size=18)
    except TypeError:  # Pillow < 10.1
        police = ImageFont.load_default()
    for n in range(0, len(lignes), PAR_PLANCHE):
        lot = lignes[n:n + PAR_PLANCHE]
        img = Image.new("RGB", (2 * w + 3 * marge, len(lot) * (h + titre + marge) + marge), (18, 17, 20))
        dr = ImageDraw.Draw(img)
        for k, (i, avant, apres) in enumerate(lot):
            y = marge + k * (h + titre + marge)
            s, e = statut[i]
            couleur = {"changé": (230, 170, 60), "nouveau": (120, 200, 120)}.get(s, (160, 160, 160))
            dr.text((marge, y + 8), f"{i} : {s}" + (f" (écart {e})" if e is not None else ""), fill=couleur, font=police)
            if avant:
                img.paste(Image.open(avant).convert("RGB").resize(VIGNETTE), (marge, y + titre))
            else:
                dr.rectangle([marge, y + titre, marge + w, y + titre + h], outline=(70, 70, 70))
                dr.text((marge + 12, y + titre + 12), "absent de la build précédente", fill=(110, 110, 110), font=police)
            img.paste(Image.open(apres).convert("RGB").resize(VIGNETTE), (2 * marge + w, y + titre))
        img.save(Path(dossier) / f"planche_{n // PAR_PLANCHE + 1:02d}.jpg", quality=85)
    return statut, disparus


def rapport(dossier, build, reference, travaux, statut, disparus, echecs, manques):
    compte = {k: sum(1 for s, _ in statut.values() if s == k) for k in ("changé", "nouveau", "identique")}
    L = [f"# Captures {build}", "",
         f"Référence : {reference or 'aucune (première build)'} · {len(statut)} captures · "
         f"{compte['changé']} changées · {compte['nouveau']} nouvelles · {compte['identique']} identiques · "
         f"{len(disparus)} disparues", "",
         "Planches : " + ", ".join(sorted(p.name for p in Path(dossier).glob("planche_*.jpg"))), ""]
    if echecs:
        L += ["## Échecs du rendu", ""] + [f"- {e}" for e in echecs] + [""]
    if manques:
        L += ["## Non capturables", ""] + [f"- {m}" for m in manques] + [""]
    if disparus:
        L += ["## Disparues depuis la build précédente", ""] + [f"- {d}" for d in disparus] + [""]
    L += ["## Captures", "", "| id | type | décor / fond | état | écart |", "|---|---|---|---|---|"]
    for t in travaux:
        if t["id"] in statut:
            s, e = statut[t["id"]]
            genre = "gros plan" if t["type"] == "gros_plan" else ("plan " + t["plan"] if t.get("plan") else "scène")
            L.append(f"| {t['id']} | {genre} | {t.get('decor') or t.get('fond')} | "
                     f"{t.get('etat') or t.get('scene', {}).get('etat', '')} | {s}" + (f" ({e})" if e is not None else "") + " |")
    (Path(dossier) / "rapport.md").write_text("\n".join(L) + "\n", encoding="utf-8")


# ------------------------------------------------------------------ commande


def garder(captures, build, ids):
    build = build or build_precedente(captures, "")
    if not build:
        sys.exit("aucune build de captures dans " + str(captures))
    code = 0
    for i in ids:
        src = image_de(captures / build, i)
        if src is None:
            print(f"absente de {build} : {i}")
            code = 1
            continue
        shutil.copy2(src, captures / src.name)
        print(f"gardée : qa/captures/{src.name} (build {build})")
    return code


def nom_build(racine):
    sha = subprocess.run(["git", "-C", str(racine), "rev-parse", "--short", "HEAD"],
                         capture_output=True, text=True).stdout.strip() or "local"
    return datetime.datetime.now().strftime("%Y%m%d-%H%M") + "_" + sha


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("episode")
    ap.add_argument("--racine", default=str(RACINE))
    ap.add_argument("--godot")
    ap.add_argument("--build", help="nom du dossier de captures (défaut : date_sha)")
    ap.add_argument("--reference", help="build de comparaison (défaut : la plus récente)")
    ap.add_argument("--png", action="store_true", help="garder les PNG (défaut : JPEG qualité 90, plus léger)")
    ap.add_argument("--seulement", help="motif d'ids à capturer (ex. orvane_*)")
    ap.add_argument("--liste", action="store_true", help="affiche les travaux sans rien rendre")
    ap.add_argument("--garder", nargs="+", metavar="ID",
                    help="DA : copie ces captures validées de --build (défaut : la plus récente) dans qa/captures/, "
                         "seul endroit versionné, où verifier_episode.py les trouve")
    a = ap.parse_args(argv)
    racine = Path(a.racine).resolve()
    if a.garder:
        return garder(racine / "qa" / "captures", a.build, a.garder)
    travaux, manques = inventaire(a.episode, racine)
    if a.seulement:
        import fnmatch
        travaux = [t for t in travaux if fnmatch.fnmatch(t["id"], a.seulement)]
    if a.liste:
        for t in travaux:
            print(t["id"])
        for m in manques:
            print("non capturable :", m)
        return 0
    build = a.build or nom_build(racine)
    captures = racine / "qa" / "captures"
    dossier = captures / build
    dossier.mkdir(parents=True, exist_ok=True)
    reference = a.reference or build_precedente(captures, build)
    with tempfile.TemporaryDirectory() as tmp:
        echecs = rendre(travaux, tmp, trouver_godot(a.godot), racine)
        for t in travaux:
            png = Path(tmp) / (t["id"] + ".png")
            if not png.is_file():
                continue
            if a.png:
                shutil.copy2(png, dossier / png.name)
            else:
                Image.open(png).convert("RGB").save(dossier / (t["id"] + ".jpg"), quality=90)
    ids = [t["id"] for t in travaux]
    statut, disparus = planche(dossier, ids, captures / reference if reference else None)
    (dossier / "index.json").write_text(json.dumps(
        {"build": build, "episode": a.episode, "reference": reference, "date": datetime.datetime.now().isoformat(timespec="seconds"),
         "captures": [dict(t, statut=statut.get(t["id"], ("échec", None))[0]) for t in travaux],
         "echecs": echecs, "non_capturables": manques}, ensure_ascii=False, indent=1), encoding="utf-8")
    rapport(dossier, build, reference, travaux, statut, disparus, echecs, manques)
    journal(f"{len(statut)}/{len(travaux)} captures dans {dossier.relative_to(racine)} "
            f"(référence : {reference or 'aucune'}) ; {len(echecs)} échecs, {len(manques)} non capturables")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
