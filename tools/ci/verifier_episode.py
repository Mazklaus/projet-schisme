#!/usr/bin/env python3
"""Suivi de production d'un épisode : ce qui manque pour que ses chapitres tournent avec les vrais assets.

Croise les .dlg de l'épisode, son séquencier (facultatif), les dossiers de décors, les ambiances son
et les bustes de gros plan, puis écrit un rapport Markdown (liste de travail de CA1, CA2, du Lead
et du Sound Designer) :
  1. décors référencés mais absents, ou incomplets au contrat des calques (guide de style §6) :
     JSON absent ou illisible, calque listé introuvable (ou seulement en gabarit), _normal ou _ombre
     annoncé mais absent, aucun _normal ou aucune couche _ombre dans tout le décor ;
     un décor livré hors du dépôt (dossier passé avec --decors) est signalé « à importer » ;
  2. décors sans ambiance son (aucun @ambiance dans les nœuds qui posent ce décor) et ambiances
     dont le fichier assets/audio/amb_<nom>.ogg manque ;
  3. personnages en gros plan (côtés de data/episodes/<ep>/gros_plans.json et « @plan serre:<perso> »)
     sans buste dans assets/personnages/<perso>/ ;
  4. bustes asymétriques sans les deux côtés : un seul côté livré, ou un buste.png unique pour un
     personnage dont l'armure n'est pas symétrique (Astartes : marques d'épaulière, pas de miroir).
  5. finition visuelle (plan du GD, finition-visuelle-ep01.md) : décor « maquette » (aucun calque
     retouché, c'est-à-dire sans <calque>.retouche.json qui donne sa sortie, ni passe peindre_plan,
     <calque>.peint.json), calques en aplats (part de pixels sans texture), moins de 4 calques, et
     tableau d'avancement par scène (pourcentage peint, pondéré par la surface des calques) ;
     personnages en plan large sans sprite animé (provisoire, image fixe ou rig).
Erreurs bloquantes en CI (code 1, même sans --strict) :
  - un calque 4k plus ancien que sa retouche (calques/4k/<calque>.png daté avant le .retouche.json), ou qui,
    réduit en 1080, ne ressemble pas au calque retouché (écart moyen > 14/255 : 4k resté en maquette) ;
  - un décor marqué « fini » (champ statut du JSON) sans capture en jeu (qa/captures/<décor>*.png ou
    capture_jeu*.png dans le dossier du décor).
Le séquencier sert à vérifier que chaque chapitre a ses répliques.

Usage :
  python3 tools/ci/verifier_episode.py ep01 [--racine .] [--dlg DOSSIER] [--sequencier FICHIER.md]
      [--decors DOSSIER ...] [--sortie rapport.md] [--historique qa/historique_<ep>.csv] [--strict]
Par défaut, les .dlg sont lus dans data/dialogues/<ep>/ et les décors dans assets/decors/.
--historique ajoute une ligne datée (% peint, % animé, % fini) au CSV et met la courbe dans le rapport.
Code de sortie 0 (le rapport est une liste de travail), sauf avec --strict s'il reste un point ouvert.
"""
import argparse
import datetime
import fnmatch
import glob
import json
import os
import re
import sys

PERSOS_SYMETRIQUES_AFFILIATIONS = ("civil", "remembrancer", "armée impériale", "imperial")
SANS_NORMAL = ("ciel", "particules", "brume", "lumens", "lisere", "liseré", "fumee", "fumée", "voile",
               "halo", "feux", "pluie", "neige", "cendres", "gabarit", "personnages", "reflet", "rayons")

# ------------------------------------------------------------------ lecture des .dlg


def lire_dlg(chemins):
    """Nœuds des .dlg : [{fichier, noeud, decors, ambiances, plans, locuteurs}] dans l'ordre."""
    noeuds = []
    for chemin in chemins:
        courant = None
        with open(chemin, encoding="utf-8") as f:
            for n, ligne in enumerate(f, 1):
                l = ligne.strip()
                if l.startswith("//") or not l:
                    continue
                m = re.match(r"^===\s*(\S+)", l)
                if m:
                    courant = {"fichier": chemin, "ligne": n, "noeud": m.group(1), "decors": [],
                               "ambiances": [], "plans": [], "locuteurs": set()}
                    noeuds.append(courant)
                    continue
                if courant is None:
                    continue
                m = re.match(r"^@(\w+)\s*(.*)$", l)
                if m:
                    cmd, arg = m.group(1), m.group(2).split()
                    if cmd == "decor" and arg:
                        courant["decors"].append(arg[0])
                    elif cmd == "ambiance" and arg:
                        courant["ambiances"].append(arg[0])
                    elif cmd == "plan" and arg:
                        courant["plans"].append(arg[0])
                    continue
                m = re.match(r"^([A-ZÀ-Ý][A-ZÀ-Ý0-9' ]*?)\s*(\([^)]*\))?\s*:", l)
                if m:
                    courant["locuteurs"].add(m.group(1).strip())
    return noeuds


def chapitre_du_fichier(chemin):
    m = re.search(r"ch(\d+)", os.path.basename(chemin))
    return f"c{int(m.group(1)):02d}" if m else os.path.splitext(os.path.basename(chemin))[0]


# ------------------------------------------------------------------ décors (contrat §6)


def charger_json(chemin):
    try:
        with open(chemin, encoding="utf-8") as f:
            return json.load(f), None
    except (OSError, ValueError) as e:
        return None, str(e)


def json_du_decor(dossier):
    """(chemin, contenu, erreur) du JSON qui décrit le décor : decor.json, sinon <plan>.json avec calques."""
    p = os.path.join(dossier, "decor.json")
    if os.path.isfile(p):
        d, e = charger_json(p)
        return p, d, e
    erreur = None
    for f in sorted(os.listdir(dossier)):
        if not f.endswith(".json") or f.endswith(".retouche.json") or f.endswith(".eclairage.json"):
            continue
        d, e = charger_json(os.path.join(dossier, f))
        if e:
            erreur = f"{f} illisible ({e})"
            continue
        if isinstance(d, dict) and "calques" in d:
            return os.path.join(dossier, f), d, None
    return None, None, erreur


def calques_declares(d):
    """[(nom_de_fichier_relatif, attend_normal, attend_ombre)] quel que soit le format du JSON."""
    brut = d.get("calques") or []
    if isinstance(brut, dict):                     # {calque: {...}} ou {variante: [calques]}
        plat = []
        for k, v in brut.items():
            if isinstance(v, list):
                plat += v
            elif isinstance(v, dict):
                plat.append(dict(v, fichier=v.get("fichier", k)))
            else:
                plat.append(k)
        brut = plat
    sortie = []
    for k in brut:
        if isinstance(k, dict):
            f = k.get("fichier") or k.get("nom") or ""
            normal = bool(k.get("normal") or k.get("normales"))
            ombre = bool(k.get("ombre"))
        elif isinstance(k, str):
            f = k.split("(")[0].strip().split()[0] if k.strip() else ""
            drapeaux = k[len(f):].lower()
            normal, ombre = "+normal" in drapeaux, "+ombre" in drapeaux
        else:
            continue
        if not f:
            continue
        if not f.startswith("calques/"):
            f = "calques/" + f
        if not f.endswith(".png"):
            f += ".png"
        sortie.append((f, normal, ombre))
    return sortie


def verifier_decor(dossier):
    """Points ouverts d'un dossier de décor au contrat §6 (liste de chaînes, vide si complet)."""
    pts = []
    chemin, d, err = json_du_decor(dossier)
    if chemin is None:
        return [err or "aucun JSON de décor (decor.json ou <plan>.json avec « calques »)"]
    if not isinstance(d, dict):
        return [f"{os.path.basename(chemin)} : contenu invalide"]
    calques = calques_declares(d)
    if not calques:
        pts.append("aucun calque listé dans le JSON")
    gros_plan = os.path.basename(dossier.rstrip("/")).endswith("_gros_plan")
    if "decor.json" not in chemin and not (d.get("cadre_px") or d.get("resolution") or d.get("taille")):
        pts.append("cadre_px absent du JSON")
    presents = 0
    for f, normal, ombre in calques:
        p = os.path.join(dossier, f)
        base = os.path.basename(f)
        if base.startswith("gabarit_"):            # emplacement des personnages ou de leur liseré (CA1)
            continue
        if not os.path.isfile(p):
            gabarit = os.path.join(os.path.dirname(p), "gabarit_" + base)
            if os.path.isfile(gabarit):
                if not any(s in base for s in ("lisere", "liseré", "personnages")):   # emplacements CA1
                    pts.append(f"{base} : seulement le gabarit")
            else:
                pts.append(f"{base} : introuvable")
            continue
        presents += 1
        if normal and not os.path.isfile(p[:-4] + "_normal.png"):
            pts.append(f"{base} : _normal annoncé mais absent")
        if ombre and not os.path.isfile(p[:-4] + "_ombre.png"):
            pts.append(f"{base} : _ombre annoncée mais absente")
    dossier_calques = os.path.join(dossier, "calques")
    pngs = glob.glob(os.path.join(dossier_calques, "*.png"))
    if presents and not gros_plan:
        if not any(x.endswith("_normal.png") for x in pngs):
            eclaires = [f for f, _, _ in calques
                        if not any(s in os.path.basename(f) for s in SANS_NORMAL)]
            if eclaires:
                pts.append("aucun _normal dans le décor (calques éclairés : "
                           + ", ".join(os.path.basename(f)[:-4] for f in eclaires[:4]) + ")")
        if not any(x.endswith("_ombre.png") for x in pngs) and not d.get("sans_ombre"):
            pts.append("aucune couche _ombre")
    return pts



AUTO_LISSE = ("ciel", "flou", "lumiere", "lumière", "brume", "voile", "halo", "rayons", "particules", "fumee",
              "fumée", "lumens", "lisere", "liseré")
SEUIL_APLAT = 0.45


def part_aplat(chemin):
    """(part de pixels opaques sans texture, surface opaque relative) ; None si le calque est presque vide.
    Calibré sur les décors du dépôt : peint ou retouché 0,1 à 0,3 ; maquette en aplats 0,5 à 0,95."""
    try:
        import numpy as np
        from PIL import Image
    except ImportError:
        return None
    im = Image.open(chemin).convert("RGBA")
    im.thumbnail((640, 640))
    a = np.asarray(im).astype(np.float32)
    m = a[..., 3] > 200
    if m.sum() < 500:
        return None
    g = a[..., :3].mean(-1)
    gr = np.zeros_like(g)
    gr[:, :-1] = np.abs(np.diff(g, axis=1))
    gr[:-1] = np.maximum(gr[:-1], np.abs(np.diff(g, axis=0)))
    return float((gr[m] < 1.0).mean()), float(m.mean())


def date_iso(s):
    try:
        return datetime.datetime.fromisoformat(str(s)).timestamp()
    except ValueError:
        return None


def ecart_4k(p4k, p):
    """Écart moyen (0..255) entre le calque 4k réduit et le calque 1080 : un 4k resté en maquette alors que
    le 1080 est retouché ne lui ressemble plus. Indépendant des dates (une copie superficielle de git les perd)."""
    import numpy as np
    from PIL import Image
    a = Image.open(p).convert("RGBA")
    b = Image.open(p4k).convert("RGBA").resize(a.size, Image.LANCZOS)
    a, b = (np.asarray(x).astype(np.float32) for x in (a, b))
    m = (a[..., 3] > 128) & (b[..., 3] > 128)
    return float(np.abs(a[..., :3] - b[..., :3])[m].mean()) if m.sum() > 100 else 0.0


SEUIL_4K = 14.0


def date_fichier(chemin, racine):
    """Date de dernière modification : commit git qui a touché le fichier si l'historique est complet,
    sinon mtime (dans une copie superficielle, tous les fichiers portent la date du dernier commit)."""
    import subprocess
    try:
        s = subprocess.run(["git", "-C", racine, "rev-parse", "--is-shallow-repository"],
                           capture_output=True, text=True, timeout=20)
        if s.returncode != 0 or s.stdout.strip() != "false":
            return os.path.getmtime(chemin)
        r = subprocess.run(["git", "-C", racine, "log", "-1", "--format=%ct", "--", os.path.relpath(chemin, racine)],
                           capture_output=True, text=True, timeout=20)
        if r.returncode == 0 and r.stdout.strip():
            return float(r.stdout.strip())
    except (OSError, ValueError, subprocess.SubprocessError):
        pass
    return os.path.getmtime(chemin)


def finition_decor(dossier, racine):
    """Avancement visuel d'un dossier de décor : calques peints, aplats, maquette, erreurs 4k et « fini »."""
    chemin, d, _ = json_du_decor(dossier)
    calques = calques_declares(d) if isinstance(d, dict) else []
    if not calques:
        calques = [(os.path.relpath(p, dossier), False, False)
                   for p in sorted(glob.glob(os.path.join(dossier, "calques", "[0-9][0-9]_*.png")))
                   if not p.endswith(("_normal.png", "_ombre.png", "_plat.png"))]
    nom = os.path.basename(dossier.rstrip("/"))
    r = {"decor": nom, "calques": 0, "peints": [], "aplats": [], "surface": 0.0, "surface_peinte": 0.0,
         "erreurs": [], "statut": (d or {}).get("statut", "") if isinstance(d, dict) else ""}
    for f, _, _ in calques:
        p = os.path.join(dossier, f)
        if not os.path.isfile(p) or os.path.basename(f).startswith("gabarit_"):
            continue
        r["calques"] += 1
        base = p[:-4]
        retouche, _ = charger_json(base + ".retouche.json") if os.path.isfile(base + ".retouche.json") else (None, None)
        peint = os.path.isfile(base + ".peint.json") or (isinstance(retouche, dict) and bool(retouche.get("sortie")))
        mesure = part_aplat(p)
        surf = mesure[1] if mesure else 0.0
        r["surface"] += surf
        if peint:
            r["peints"].append(os.path.basename(f)[:-4])
            r["surface_peinte"] += surf
        elif mesure and mesure[0] > SEUIL_APLAT and not any(s in os.path.basename(f) for s in AUTO_LISSE):
            r["aplats"].append(f"{os.path.basename(f)[:-4]} ({mesure[0]:.0%})")
        if isinstance(retouche, dict):
            q = os.path.join(os.path.dirname(p), "4k", os.path.basename(p))
            t_ret = date_iso(retouche.get("date")) or os.path.getmtime(base + ".retouche.json")
            if os.path.isfile(q):
                if date_fichier(q, racine) < t_ret:
                    r["erreurs"].append(f"calques/4k/{os.path.basename(p)} plus ancien que sa retouche "
                                        f"({retouche.get('date', '?')}) : maquette d'avant la retouche")
                else:
                    e = ecart_4k(q, p)
                    if e > SEUIL_4K:
                        r["erreurs"].append(f"calques/4k/{os.path.basename(p)} ne correspond pas au calque retouché "
                                            f"(écart moyen {e:.0f}/255) : 4k d'avant la retouche ?")
    if "fini" in str(r["statut"]).lower():
        captures = glob.glob(os.path.join(racine, "qa", "captures", nom + "*.png")) + \
            glob.glob(os.path.join(dossier, "capture_jeu*.png"))
        if not captures:
            r["erreurs"].append(f"statut « {r['statut']} » sans capture en jeu (qa/captures/{nom}*.png)")
    r["maquette"] = not r["peints"]
    r["pct"] = round(100 * r["surface_peinte"] / r["surface"]) if r["surface"] else 0
    return r


def sprites(racine, nom):
    """État du sprite d'un personnage en plan large : 'animé' (rig), 'fixe' (image) ou 'provisoire'."""
    for motif in (f"assets/personnages/{nom}/*.tscn", f"assets/personnages/{nom}/pieces/*.png",
                  f"assets/personnages/{nom}/rig*", f"assets/tranche_ullanor/props/{nom}.tscn",
                  f"assets/personnages/{nom}/sprite*.tres"):
        if glob.glob(os.path.join(racine, motif)):
            return "animé"
    if os.path.isfile(os.path.join(racine, "assets", "tranche_ullanor", "props", nom + ".png")):
        return "fixe"
    return "provisoire"


# ------------------------------------------------------------------ bustes


def bustes(dossier_persos, perso):
    """{'gauche': bool, 'droite': bool, 'unique': bool} des bustes livrés pour un personnage."""
    d = os.path.join(dossier_persos, perso)
    fichiers = os.listdir(d) if os.path.isdir(d) else []
    pngs = [f for f in fichiers if f.endswith(".png") and not f.endswith("_normal.png")]
    return {
        "gauche": any(fnmatch.fnmatch(f, "buste_gauche*.png") for f in pngs),
        "droite": any(fnmatch.fnmatch(f, "buste_droite*.png") for f in pngs),
        "unique": any(f == "buste.png" or fnmatch.fnmatch(f, "buste_neutre*.png") for f in pngs),
    }


def symetrique(registre, perso):
    """Un personnage peut être miroité s'il est civil ou déclaré « symetrique » dans le registre."""
    p = registre.get(perso, {})
    if "symetrique" in p:
        return bool(p["symetrique"])
    aff = str(p.get("affiliation", "")).lower()
    return any(a in aff for a in PERSOS_SYMETRIQUES_AFFILIATIONS)


# ------------------------------------------------------------------ séquencier


def chapitres_sequencier(chemin):
    """Numéros des chapitres d'un séquencier (« ## Chapitre N ») ; un séquencier d'un seul chapitre → [1]."""
    with open(chemin, encoding="utf-8") as f:
        texte = f.read()
    nums = [int(n) for n in re.findall(r"^#+\s*Chapitre\s+(\d+)", texte, re.M | re.I)]
    return sorted(set(nums)) or [1]


# ------------------------------------------------------------------ rapport


def analyser(ep, racine, dossier_dlg=None, sequencier=None, decors_ext=()):
    dossier_dlg = dossier_dlg or os.path.join(racine, "data", "dialogues", ep)
    dlg = sorted(glob.glob(os.path.join(dossier_dlg, "*.dlg")))
    noeuds = lire_dlg(dlg)
    alias, _ = charger_json(os.path.join(racine, "data", "decors_alias.json"))
    alias = alias if isinstance(alias, dict) else {}
    reg, _ = charger_json(os.path.join(racine, "data", "personnages.json"))
    registre = (reg or {}).get("personnages", {}) if isinstance(reg, dict) else {}
    base_decors = os.path.join(racine, "assets", "decors")
    audio = os.path.join(racine, "assets", "audio")
    persos_dir = os.path.join(racine, "assets", "personnages")
    dossier_ep = os.path.join(racine, "data", "episodes", ep)

    # plans caméra : un plan peut poser un autre décor
    plans = {}
    for p in glob.glob(os.path.join(dossier_ep, "plans.json")):
        d, _ = charger_json(p)
        if isinstance(d, dict):
            plans.update({k: v for k, v in d.items() if isinstance(v, dict)})

    # décors référencés : nom du .dlg → [(fichier, nœud)]
    refs, ambiance_par_decor = {}, {}
    for n in noeuds:
        noms = list(n["decors"]) + [plans[p]["decor"] for p in n["plans"] if p in plans and plans[p].get("decor")]
        for nom in noms:
            refs.setdefault(nom, []).append((os.path.basename(n["fichier"]), n["noeud"]))
        for nom in n["decors"]:
            ambiance_par_decor.setdefault(nom, False)
            if n["ambiances"]:
                ambiance_par_decor[nom] = True
    gp, _ = charger_json(os.path.join(dossier_ep, "gros_plans.json"))
    scenes_gp = (gp or {}).get("scenes", []) if isinstance(gp, dict) else []
    for s in scenes_gp:
        if s.get("decor"):
            refs.setdefault(s["decor"], []).append(("gros_plans.json", s.get("chapitre", "?")))

    resultat = {"ep": ep, "dlg": [os.path.relpath(f, racine) if f.startswith(racine) else f for f in dlg],
                "absents": [], "incomplets": [], "a_importer": [], "complets": [],
                "sans_ambiance": [], "ambiances_absentes": [], "sans_buste": [], "un_seul_cote": [],
                "chapitres_sans_dlg": []}
    existants = sorted(os.listdir(base_decors)) if os.path.isdir(base_decors) else []
    vus_dossiers = set()
    for nom in sorted(refs):
        a = alias.get(nom) if isinstance(alias.get(nom), dict) else {}
        reel = a.get("decor", nom)
        dossier = os.path.join(base_decors, reel)
        ligne = {"nom": nom, "dossier": reel, "refs": refs[nom][:4], "nb_refs": len(refs[nom])}
        if os.path.isdir(dossier):
            if reel in vus_dossiers:
                continue
            vus_dossiers.add(reel)
            pts = verifier_decor(dossier)
            (resultat["incomplets"] if pts else resultat["complets"]).append(dict(ligne, points=pts))
            continue
        ext = next((os.path.join(e, reel) for e in decors_ext if os.path.isdir(os.path.join(e, reel))), None)
        if ext:
            resultat["a_importer"].append(dict(ligne, source=ext, points=verifier_decor(ext)))
            continue
        voisin = next((e for e in existants if reel.startswith(e + "_")), None)
        voisin = voisin or next((os.path.basename(x) for e in decors_ext for x in glob.glob(os.path.join(e, "*"))
                                 if os.path.isdir(x) and reel.startswith(os.path.basename(x) + "_")), None)
        resultat["absents"].append(dict(ligne, voisin=voisin))

    for nom, ok in sorted(ambiance_par_decor.items()):
        if not ok:
            resultat["sans_ambiance"].append({"nom": nom, "refs": refs.get(nom, [])[:4]})
    vues = set()
    for n in noeuds:
        for amb in n["ambiances"]:
            if amb in vues:
                continue
            vues.add(amb)
            if not os.path.isfile(os.path.join(audio, f"amb_{amb}.ogg")):
                resultat["ambiances_absentes"].append({"nom": amb, "fichier": f"assets/audio/amb_{amb}.ogg",
                                                       "ref": (os.path.basename(n["fichier"]), n["noeud"])})

    # personnages en gros plan
    gros = {}
    for s in scenes_gp:
        for p in (s.get("cotes") or {}):
            gros.setdefault(p.lower(), []).append(f"gros_plans.json ({s.get('chapitre', '?')}, {s.get('decor', '?')})")
    for n in noeuds:
        for p in n["plans"]:
            if p.startswith("serre:"):
                gros.setdefault(p.split(":", 1)[1].lower(), []).append(
                    f"{os.path.basename(n['fichier'])} › {n['noeud']}")
    for perso in sorted(gros):
        b = bustes(persos_dir, perso)
        ligne = {"perso": perso, "ou": gros[perso][:3], "nb": len(gros[perso]),
                 "registre": perso in registre, "symetrique": symetrique(registre, perso)}
        if not (b["gauche"] or b["droite"] or b["unique"]):
            resultat["sans_buste"].append(ligne)
        elif b["gauche"] != b["droite"]:
            resultat["un_seul_cote"].append(dict(ligne, livre="gauche" if b["gauche"] else "droite"))
        elif not (b["gauche"] and b["droite"]) and not ligne["symetrique"]:
            resultat["un_seul_cote"].append(dict(ligne, livre="buste unique (miroir interdit)"))

    # finition visuelle : une ligne par scène (nœud qui pose un décor), dans l'ordre des .dlg
    cache, scenes = {}, []
    for n in noeuds:
        noms = list(n["decors"]) or [plans[p]["decor"] for p in n["plans"] if p in plans and plans[p].get("decor")][:1]
        for nom in dict.fromkeys(noms):
            a = alias.get(nom) if isinstance(alias.get(nom), dict) else {}
            reel = a.get("decor", nom)
            if reel not in cache:
                dossier = os.path.join(base_decors, reel)
                if not os.path.isdir(dossier):
                    dossier = next((os.path.join(e, reel) for e in decors_ext if os.path.isdir(os.path.join(e, reel))), None)
                cache[reel] = finition_decor(dossier, racine) if dossier else None
                if cache[reel] and not dossier.startswith(base_decors):
                    cache[reel]["hors_depot"] = True
            scenes.append({"chapitre": chapitre_du_fichier(n["fichier"]), "noeud": n["noeud"], "decor": reel,
                           "f": cache[reel]})
    resultat["scenes"] = scenes
    resultat["finition"] = [v for v in cache.values() if v]
    resultat["erreurs"] = [f"{v['decor']} : {e}" for v in cache.values() if v for e in v["erreurs"]]
    # personnages en plan large : joueur et figurants des fichiers « jeu », locuteurs du registre
    epj, _ = charger_json(os.path.join(dossier_ep, "episode.json"))
    jeux = []
    for c in (epj or {}).get("chapitres", []) if isinstance(epj, dict) else []:
        j = c.get("jeu")
        if j:
            jd, _ = charger_json(os.path.join(racine, j.replace("res://", "")))
            if isinstance(jd, dict):
                jeux.append((c.get("id", "?"), jd))
    larges = {"vaskar": {c for c, _ in jeux}} if jeux else {}                 # le joueur par défaut
    for cid, jd in jeux:
        for zone in jd.values():
            if not isinstance(zone, dict):
                continue
            if zone.get("personnage"):
                larges.setdefault(zone["personnage"], set()).add(cid)
            for f in (zone.get("figurants") or {}).values():
                larges.setdefault(f, set()).add(cid)
    for n in noeuds:
        for loc in n["locuteurs"]:
            if loc.lower() in registre:
                larges.setdefault(loc.lower(), set()).add(chapitre_du_fichier(n["fichier"]))
    resultat["sprites"] = [{"nom": k, "etat": sprites(racine, k), "chapitres": sorted(v)} for k, v in sorted(larges.items())]

    if sequencier and os.path.isfile(sequencier):
        nums = chapitres_sequencier(sequencier)
        presents = {chapitre_du_fichier(f) for f in dlg}
        for k in nums:
            if f"c{k:02d}" not in presents:
                resultat["chapitres_sans_dlg"].append(k)
        resultat["sequencier"] = sequencier
    return resultat


def indicateurs(r):
    """% peint (moyenne des scènes), % de personnages en plan large animés, % de décors au statut « fini »."""
    ns = len(r.get("scenes", []))
    peint = round(sum((s["f"] or {}).get("pct", 0) for s in r["scenes"]) / ns) if ns else 0
    sp = r.get("sprites", [])
    anime = round(100 * sum(1 for x in sp if x["etat"] == "animé") / len(sp)) if sp else 0
    fin = r.get("finition", [])
    fini = round(100 * sum(1 for x in fin if "fini" in str(x["statut"]).lower()) / len(fin)) if fin else 0
    return {"peint": peint, "anime": anime, "fini": fini, "scenes": ns, "points": points_ouverts(r)}


def historique(chemin, r, racine):
    """Ajoute la ligne du jour (une par commit et par jour) et rend toutes les lignes."""
    import csv
    import subprocess
    try:
        commit = subprocess.run(["git", "-C", racine, "rev-parse", "--short", "HEAD"], capture_output=True,
                                text=True, timeout=20).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        commit = ""
    i = indicateurs(r)
    ligne = {"date": datetime.datetime.now().strftime("%Y-%m-%d %H:%M"), "commit": commit, "peint": i["peint"],
             "anime": i["anime"], "fini": i["fini"], "scenes": i["scenes"], "points_ouverts": i["points"]}
    lignes = []
    if os.path.isfile(chemin):
        with open(chemin, encoding="utf-8") as f:
            lignes = list(csv.DictReader(f))
    if lignes and lignes[-1].get("commit") == commit and lignes[-1]["date"][:10] == ligne["date"][:10]:
        lignes[-1] = {k: str(v) for k, v in ligne.items()}                       # même build : on remplace
    else:
        lignes.append({k: str(v) for k, v in ligne.items()})
    os.makedirs(os.path.dirname(os.path.abspath(chemin)), exist_ok=True)
    with open(chemin, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(ligne))
        w.writeheader()
        w.writerows(lignes)
    return lignes


def points_ouverts(r):
    return sum(len(r[k]) for k in ("absents", "incomplets", "a_importer", "sans_ambiance", "ambiances_absentes",
                                   "sans_buste", "un_seul_cote", "chapitres_sans_dlg"))


def fmt_refs(refs, nb):
    s = ", ".join(f"{f} › {n}" for f, n in refs)
    return s + (f" (+{nb - len(refs)})" if nb > len(refs) else "")


def rapport_md(r):
    L = [f"# Suivi de production : {r['ep']}", "",
         f"*Généré par `tools/ci/verifier_episode.py` le {datetime.date.today().isoformat()}. "
         f"Sources : {len(r['dlg'])} fichier(s) .dlg"
         + (f", séquencier `{os.path.basename(r['sequencier'])}`" if r.get("sequencier") else "") + ".*", "",
         f"**{points_ouverts(r)} point(s) ouvert(s)** : {len(r['absents'])} décor(s) absent(s), "
         f"{len(r['a_importer'])} à importer, {len(r['incomplets'])} incomplet(s), "
         f"{len(r['sans_ambiance'])} sans ambiance son, {len(r['ambiances_absentes'])} ambiance(s) sans fichier, "
         f"{len(r['sans_buste'])} personnage(s) en gros plan sans buste, "
         f"{len(r['un_seul_cote'])} buste(s) sans les deux côtés. {len(r['complets'])} décor(s) complet(s).", ""]
    i = indicateurs(r)
    L += [f"**Thermomètre** : {i['peint']} % peint, {i['anime']} % des personnages en plan large animés, "
          f"{i['fini']} % des décors finis.", ""]
    if r.get("historique"):
        L += ["| Date | Commit | Peint | Animé | Fini | Points ouverts |", "|---|---|---|---|---|---|"]
        for h in r["historique"][-15:]:
            L.append(f"| {h['date']} | {h['commit']} | {h['peint']} % | {h['anime']} % | {h['fini']} % | {h['points_ouverts']} |")
        L.append("")
    if r["chapitres_sans_dlg"]:
        L += ["## Chapitres du séquencier sans répliques (Narrative Designer)", "",
              "Chapitre(s) " + ", ".join(str(k) for k in r["chapitres_sans_dlg"]) + " : aucun .dlg trouvé.", ""]
    L += ["## 1. Décors (CA2, import par le Lead)", ""]
    if r["absents"]:
        L += ["### Absents : référencés mais introuvables", "", "| Décor | Référencé dans | Note |", "|---|---|---|"]
        for x in r["absents"]:
            note = f"état de `{x['voisin']}` ? (ajouter un alias dans data/decors_alias.json)" if x.get("voisin") else "à produire"
            if x["dossier"] != x["nom"]:
                note = f"alias vers `{x['dossier']}`, dossier absent"
            L.append(f"| `{x['nom']}` | {fmt_refs(x['refs'], x['nb_refs'])} | {note} |")
        L.append("")
    if r["a_importer"]:
        L += ["### Livrés hors du dépôt : à importer dans assets/decors/", "",
              "| Décor | Source | Contrat §6 |", "|---|---|---|"]
        for x in r["a_importer"]:
            etat = "complet" if not x["points"] else "<br>".join(x["points"])
            src = x["source"].split("etude-heresie/")[-1]
            L.append(f"| `{x['nom']}` | `{src}` | {etat} |")
        L.append("")
    if r["incomplets"]:
        L += ["### Incomplets au contrat §6", "", "| Décor | Points ouverts |", "|---|---|"]
        for x in r["incomplets"]:
            L.append(f"| `{x['dossier']}` | " + "<br>".join(x["points"]) + " |")
        L.append("")
    if r["complets"]:
        L += ["Complets : " + ", ".join(f"`{x['dossier']}`" for x in r["complets"]) + ".", ""]
    L += ["## 2. Ambiances son (Sound Designer, pose des @ambiance par le Narrative Designer)", ""]
    if r["sans_ambiance"]:
        L += ["### Décors sans ambiance", "", "Aucun nœud qui pose ce décor n'a de `@ambiance`.", "",
              "| Décor | Posé dans |", "|---|---|"]
        for x in r["sans_ambiance"]:
            L.append(f"| `{x['nom']}` | {fmt_refs(x['refs'], len(x['refs']))} |")
        L.append("")
    if r["ambiances_absentes"]:
        L += ["### Ambiances sans fichier", "", "| Ambiance | Fichier attendu | Première référence |", "|---|---|---|"]
        for x in r["ambiances_absentes"]:
            L.append(f"| `{x['nom']}` | `{x['fichier']}` | {x['ref'][0]} › {x['ref'][1]} |")
        L.append("")
    if not (r["sans_ambiance"] or r["ambiances_absentes"]):
        L += ["Rien à signaler.", ""]
    L += ["## 3. Bustes de gros plan (CA1)", ""]
    if r["sans_buste"]:
        L += ["### Personnages en gros plan sans buste", "", "| Personnage | Gros plans |", "|---|---|"]
        for x in r["sans_buste"]:
            reg = "" if x["registre"] else " (absent de data/personnages.json)"
            L.append(f"| `{x['perso']}`{reg} | {'; '.join(x['ou'])}" + (f" (+{x['nb'] - len(x['ou'])})" if x['nb'] > len(x['ou']) else "") + " |")
        L.append("")
    if r["un_seul_cote"]:
        L += ["### Bustes asymétriques sans les deux côtés", "",
              "Les marques d'épaulière restent à leur place réelle : pas de miroir pour une armure asymétrique.", "",
              "| Personnage | Livré | Manque |", "|---|---|---|"]
        for x in r["un_seul_cote"]:
            manque = {"gauche": "buste_droite_*", "droite": "buste_gauche_*"}.get(x["livre"], "buste_gauche_* et buste_droite_*")
            L.append(f"| `{x['perso']}` | {x['livre']} | {manque} |")
        L.append("")
    if not (r["sans_buste"] or r["un_seul_cote"]):
        L += ["Rien à signaler.", ""]
    L += ["## 4. Finition visuelle (CA2, TP2 ; suivi GD et QA à chaque build)", ""]
    if r.get("erreurs"):
        L += ["### Erreurs (bloquantes en CI)", ""] + [f"- {e}" for e in r["erreurs"]] + [""]
    fin = r.get("finition", [])
    if fin:
        moy = round(sum(x["pct"] for x in fin) / len(fin))
        maq = [x for x in fin if x["maquette"]]
        ns = len(r["scenes"])
        moy_sc = round(sum((s["f"] or {}).get("pct", 0) for s in r["scenes"]) / ns) if ns else 0
        L += [f"**{moy_sc} % peint sur les {ns} scènes** ({moy} % en moyenne sur {len(fin)} décor(s) trouvé(s) ; "
              f"{len(maq)} en maquette : aucun calque retouché ni peint).", "",
              "### Avancement par scène", "", "| Chapitre | Scène | Décor | Peint | État |", "|---|---|---|---|---|"]
        for s in r["scenes"]:
            f = s["f"]
            if f is None:
                L.append(f"| {s['chapitre']} | {s['noeud']} | `{s['decor']}` | 0 % | absent (décor provisoire) |")
                continue
            etat = []
            if f["maquette"]:
                etat.append("maquette")
            if f["calques"] < 4:
                etat.append(f"{f['calques']} calque(s)")
            if f["aplats"]:
                etat.append("aplats : " + ", ".join(f["aplats"][:3]) + (" …" if len(f["aplats"]) > 3 else ""))
            if f["erreurs"]:
                etat.append("**erreur**")
            if f.get("hors_depot"):
                etat.append("hors dépôt")
            L.append(f"| {s['chapitre']} | {s['noeud']} | `{s['decor']}` | {f['pct']} % | {'; '.join(etat) or 'peint'} |")
        L.append("")
    sp = r.get("sprites", [])
    if sp:
        L += ["### Personnages en plan large", "", "| Personnage | Sprite | Chapitres |", "|---|---|---|"]
        for x in sp:
            L.append(f"| `{x['nom']}` | {x['etat']} | {', '.join(x['chapitres'])} |")
        anim = sum(1 for x in sp if x["etat"] == "animé")
        L += ["", f"{anim} sur {len(sp)} animé(s). « provisoire » : silhouette grise du moteur ; « fixe » : image sans rig.", ""]
    return "\n".join(L)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("episode")
    ap.add_argument("--racine", default=".")
    ap.add_argument("--dlg", help="dossier des .dlg (défaut : data/dialogues/<ep>)")
    ap.add_argument("--sequencier", help="séquencier Markdown de l'épisode")
    ap.add_argument("--decors", nargs="*", default=[], help="dossiers de décors livrés hors du dépôt")
    ap.add_argument("--sortie", help="écrire le rapport dans ce fichier (sinon sortie standard)")
    ap.add_argument("--historique", help="CSV d'historique : ajoute la ligne du jour, courbe dans le rapport")
    ap.add_argument("--strict", action="store_true", help="code 1 s'il reste un point ouvert")
    a = ap.parse_args(argv)
    racine = os.path.abspath(a.racine)
    r = analyser(a.episode, racine, a.dlg and os.path.abspath(a.dlg), a.sequencier,
                 [os.path.abspath(d) for d in a.decors])
    if a.historique:
        r["historique"] = historique(a.historique, r, racine)
    md = rapport_md(r)
    if a.sortie:
        os.makedirs(os.path.dirname(os.path.abspath(a.sortie)), exist_ok=True)
        with open(a.sortie, "w", encoding="utf-8") as f:
            f.write(md + "\n")
        print(f"{a.episode} : {points_ouverts(r)} point(s) ouvert(s) → {a.sortie}")
    else:
        print(md)
    if not r["dlg"]:
        print(f"::warning::{a.episode} : aucun .dlg trouvé", file=sys.stderr)
    for e in r.get("erreurs", []):
        print(f"::error::{a.episode} : {e}", file=sys.stderr)
    if r.get("erreurs"):
        return 1
    return 1 if a.strict and points_ouverts(r) else 0


if __name__ == "__main__":
    sys.exit(main())
