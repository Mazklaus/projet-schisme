#!/usr/bin/env python3
"""Sprite en pied d'un personnage, du kit Blender aux pièces du rig, en une commande.

    python3 tools/sprites/preparer_sprite.py vaskar --type astartes --travail ~/sprites/vaskar
    python3 tools/sprites/preparer_sprite.py ilse --type humain --travail ~/sprites/ilse \\
        --couleurs-de /mnt/project-files/etude-heresie/cA1/pied/ilse/pied        # couleurs peintes gardées

Étapes (contrat rig v1, Gameplay ; chaîne de CA1 réutilisée telle quelle) :
  1. rendu Blender par groupe avec le script de CA1 (astartes_pied.py, soldat_pied.py), plus deux
     passes au même cadrage (passes_blender.py) : albédo × occlusion et normale monde ;
  2. découpe par decouper_pied.py de CA1 (échelle ×2, rognage à 4 px, pivots, yeux fermés…), la
     couleur prise sur l'albédo (seules les Light2D éclairent) ou sur une passe peinte (--peint) ;
  3. normales rendues par Blender, converties en espace caméra OpenGL Y+, à la place des normales
     dérivées de la profondeur ;
  4. couleurs gardées d'une livraison peinte (--couleurs-de) quand la pièce a le même cadrage ;
  5. ombre de contact au sol (ombre_contact.png, multiplication) et champs « ombre », « source »
     de rig.json ;
  6. fiche de retouche commune pour TP2 (retouche_commune.json + retoucher_pieces.sh) : toutes les
     pièces avec la même graine, les mêmes réglages et le même éclairage (albédo).
Sortie : <travail>/pied/ (pièces, normales, rig.json, assemble.png, planche_normales.png).
"""
import argparse
import datetime
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ICI = Path(__file__).resolve().parent
CA1 = Path(os.environ.get("CA1_PIED", "/mnt/project-files/etude-heresie/cA1/pied"))
RETOUCHER = os.environ.get("RETOUCHER", "/mnt/project-files/etude-heresie/chaine-images/retouche/retoucher.py")
SCRIPTS = {"astartes": ("astartes_pied.py", ["260", "{spp}", "{perso}"]),
           "humain": ("soldat_pied.py", ["400", "{spp}"])}
HAUTEURS = {"astartes": 460, "humain": 340}
# groupes de rendu (CA1) -> pièces du contrat (decouper_pied.NOMS)
GROUPE_DE = {"bassin": "bassin", "torse": "torse", "tete": "tete", "tete_face": "tete_face",
             "bras_avant": "bras_d", "bras_arriere": "bras_g", "avant_bras_avant": "avant_bras_d",
             "avant_bras_arriere": "avant_bras_g", "main_avant": "main_d", "main_arriere": "main_g",
             "cuisse_avant": "cuisse_d", "cuisse_arriere": "cuisse_g", "jambe_avant": "tibia_d",
             "jambe_arriere": "tibia_g", "pied_avant": "pied_d", "pied_arriere": "pied_g",
             "epauliere_avant": "epauliere_d", "epauliere_arriere": "epauliere_g", "tete_casque": "tete_casque",
             "arme_fourreau": "arme_fourreau", "casque_main": "casque_main", "main_avant_pommeau": "main_avant_pommeau",
             "bras_tendu": "bras_tendu", "bras_tendu_arriere": "bras_tendu_arriere", "arme_dos": "arme_dos"}
# pièces sans rendu propre : normale de leur pièce de base, au même cadrage
NORMALE_DE = {"main_avant_pointe": "main_avant", "main_avant_poing": "main_avant"}
PRESETS = {
    "astartes": "oil painting, flat even diffuse lighting, Space Marine power armour Mark II, worn ceramite plates, "
                "riveted edges, chipped paint, leather straps",
    "humain": "oil painting, flat even diffuse lighting, civilian clothes, worn wool and leather, folds, stitched seams",
}
NEGATIF = "rim light, dramatic lighting, strong shadows, glow, text, letters, glowing eyes, glowing lenses"


def journal(msg):
    print(f"[sprite] {msg}", flush=True)


def lancer(cmd, env=None, cwd=None):
    journal("$ " + " ".join(str(c) for c in cmd))
    p = subprocess.run([str(c) for c in cmd], env=env, cwd=cwd)
    if p.returncode:
        raise SystemExit(f"échec ({p.returncode}) : {cmd[1] if len(cmd) > 1 else cmd[0]}")


def charger(chemin, mode="RGBA"):
    im = Image.open(chemin)
    a = np.asarray(im)
    if a.dtype == np.uint16:
        return a.astype(np.float32) / 65535
    return np.asarray(im.convert(mode)).astype(np.float32) / 255


def charger16(chemin):
    """Normale rendue par Blender (PNG 16 bits) : PIL la lit en 8 bits, ce qui suffit à une carte de
    normales 8 bits ; imageio, s'il est installé, garde les 16 bits avant la réduction."""
    try:
        import imageio.v3 as iio
        a = iio.imread(chemin)
        return a.astype(np.float32) / (65535 if a.dtype == np.uint16 else 255)
    except ImportError:
        return np.asarray(Image.open(chemin).convert("RGBA")).astype(np.float32) / 255


# ------------------------------------------------------------------ normales


def normale_camera(nmonde_rgb):
    """Normale monde (n·0,5+0,5) -> normale caméra OpenGL Y+ : caméra orthographique de CA1 tournée
    de 90° autour de X (regarde +Y monde) : x écran = x monde, y écran = z monde, vers l'œil = -y monde."""
    n = nmonde_rgb[..., :3] * 2 - 1
    c = np.stack([n[..., 0], n[..., 2], -n[..., 1]], -1)
    c /= np.maximum(np.linalg.norm(c, axis=-1, keepdims=True), 1e-6)
    return c


def reduire_normale(c, alpha, taille):
    """Réduction pondérée par l'alpha (pas de fuite du fond aux bords), puis renormalisation."""
    W1, H1 = taille
    out = []
    for i in range(3):
        v = Image.fromarray((c[..., i] * alpha).astype(np.float32), "F").resize((W1, H1), Image.BILINEAR)
        out.append(np.asarray(v))
    a1 = np.asarray(Image.fromarray(alpha.astype(np.float32), "F").resize((W1, H1), Image.BILINEAR))
    n = np.stack(out, -1) / np.maximum(a1[..., None], 1e-4)
    vide = a1 < 1e-3
    n[vide] = (0, 0, 1)
    n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
    return n


def echelle(rendu, hauteur):
    comp = charger(rendu / "complet_rgb.png")
    ys = np.nonzero(comp[..., 3].max(1) > 0.5)[0]
    k = hauteur / (ys.max() - ys.min() + 1)
    H0, W0 = comp.shape[:2]
    return k, (int(round(W0 * k)), int(round(H0 * k)))


def bbox(a, m=4):
    ys, xs = np.nonzero(a > 0.02)
    return max(xs.min() - m, 0), max(ys.min() - m, 0), min(xs.max() + m + 1, a.shape[1]), min(ys.max() + m + 1, a.shape[0])


def remplacer_normales(rendu, pied, hauteur):
    """Normales Blender pour chaque pièce rendue, au cadrage exact de decouper_pied (même échelle,
    même rognage)."""
    k, taille = echelle(rendu, hauteur)
    rig = json.loads((pied / "rig.json").read_text(encoding="utf-8"))
    faites, gardees = [], []
    for nom, e in rig["pieces"].items():
        g = GROUPE_DE.get(NORMALE_DE.get(nom, nom))
        f_rgb, f_n = rendu / f"{g}_rgb.png", rendu / f"{g}_nmonde.png"
        if not g or not f_n.is_file():
            gardees.append(nom)
            continue
        # même chaîne que decouper_pied (ld puis red « RGBA ») : rognage identique au pixel
        rgb8 = np.asarray(Image.open(f_rgb).convert("RGBA"))
        a = rgb8[..., 3].astype(np.float32) / 255
        a1 = np.asarray(Image.fromarray(rgb8).resize(taille, Image.LANCZOS))[..., 3].astype(np.float32) / 255
        x0, y0, x1, y1 = bbox(a1)
        piece = Image.open(pied / e["fichier"]).convert("RGBA")
        if piece.size != (x1 - x0, y1 - y0):
            journal(f"{nom} : cadrage différent ({piece.size} ≠ {(x1 - x0, y1 - y0)}), normale gardée")
            gardees.append(nom)
            continue
        n = reduire_normale(normale_camera(charger16(f_n)), a, taille)[y0:y1, x0:x1]
        pa = np.asarray(piece)[..., 3]
        out = np.dstack([((n * 0.5 + 0.5) * 255).round().clip(0, 255).astype(np.uint8), pa])
        Image.fromarray(out, "RGBA").save(pied / (Path(e["fichier"]).stem + "_normal.png"))
        faites.append(nom)
    return faites, gardees, k


# ------------------------------------------------------------------ couleurs gardées


ECART_TOLERE_PX = 2


def garder_couleurs(pied, source):
    """Couleur d'une livraison peinte (CA1) pour chaque pièce de même taille ; l'alpha reste celui
    de la découpe, identique quand le cadrage l'est."""
    gardees, autres = [], []
    for f in sorted(pied.glob("*.png")):
        if f.stem.endswith("_normal") or f.name in ("assemble.png", "planche_pieces.png", "ombre_contact.png") \
                or f.name.startswith("planche"):
            continue
        s = Path(source) / f.name
        taille = Image.open(f).size
        ts = Image.open(s).size if s.is_file() else None
        if ts == taille:
            shutil.copy2(s, f)
            gardees.append(f.stem)
        elif ts and max(abs(ts[0] - taille[0]), abs(ts[1] - taille[1])) <= ECART_TOLERE_PX:
            # Un pixel d'écart vient de l'arrondi du cadrage : on recale la peinture sur la pièce.
            Image.open(s).convert("RGBA").resize(taille, Image.LANCZOS).save(f)
            gardees.append(f.stem)
        else:
            autres.append(f.stem)
    return gardees, autres


# ------------------------------------------------------------------ ombre de contact


def ombre_contact(pied, rig):
    """Tache douce sous les pieds : ellipse large et légère, plus deux cœurs sous les semelles.
    RGB = teinte de l'ombre, alpha = force (shader d'ombre des décors, en multiplication)."""
    px, py = rig["pieds"]
    xs = []
    for nom in ("pied_avant", "pied_arriere"):
        e = rig["pieces"].get(nom)
        if e:
            w = Image.open(pied / e["fichier"]).size[0]
            xs.append((e["pose"][0] + 4, e["pose"][0] + w - 4))
    x0 = min(x[0] for x in xs) if xs else px - 40
    x1 = max(x[1] for x in xs) if xs else px + 40
    largeur = int((x1 - x0) * 1.6) + 24
    hauteur = max(int(largeur * 0.26), 14)
    yy, xx = np.mgrid[0:hauteur, 0:largeur].astype(np.float32)
    cx, cy = largeur / 2, hauteur / 2
    a = np.exp(-(((xx - cx) / (largeur * 0.36)) ** 2 + ((yy - cy) / (hauteur * 0.30)) ** 2) * 1.6) * 0.45
    for (u0, u1) in xs:
        c = (u0 + u1) / 2 - (x0 + x1) / 2 + cx
        a += np.exp(-(((xx - c) / max((u1 - u0) * 0.55, 6)) ** 2 + ((yy - cy) / (hauteur * 0.16)) ** 2) * 2.0) * 0.35
    a = np.clip(a, 0, 0.75)
    img = np.zeros((hauteur, largeur, 4), np.uint8)
    img[..., :3] = (30, 27, 32)
    img[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(pied / "ombre_contact.png")
    return {"fichier": "ombre_contact.png", "pose": [int((x0 + x1) / 2 - cx), int(py - cy * 0.9)]}


# ------------------------------------------------------------------ fiche commune (TP2)


def pieces_perdues(rig_installe, rig):
    """Pièces du rig déjà en place (livraison de CA1 : bras_croises, mains_graver…) absentes de la sortie."""
    if not Path(rig_installe).is_file():
        return []
    avant = json.loads(Path(rig_installe).read_text(encoding="utf-8")).get("pieces", {})
    return sorted(set(avant) - set(rig.get("pieces", {})))


def fiche_commune(travail, rendu, typ, perso, graine):
    peint = travail / "peint"
    groupes = sorted(p.name[:-len("_albedo.png")] for p in rendu.glob("*_albedo.png") if not p.name.startswith("complet"))
    # Défauts de la série Ilse v3 de TP2, vue et acceptée par la DA (27/11).
    reglages = {"modele": "xl", "preset": PRESETS[typ], "force": 0.55, "controle": 0.6, "largeur": 1024,
                "lumiere": 10.0, "couleur": 0.6, "fond": "8A6A48", "negatif": NEGATIF, "graines": str(graine)}
    fiche = {"_doc": "Retouche commune des pièces d'un sprite en pied (Tools, preparer_sprite.py) : même graine, "
                     "mêmes réglages et même éclairage (albédo × occlusion, sans lampe) pour toutes les pièces, "
                     "profondeur du kit en contrôle. Sorties dans peint/<groupe>_rgb.png, puis relancer "
                     "preparer_sprite.py avec --peint <travail>/peint.",
             "perso": perso, "type": typ, "reglages": reglages,
             "pieces": [{"groupe": g, "entree": str(rendu / f"{g}_albedo.png"), "sortie": str(peint / f"{g}_rgb.png"),
                         "profondeur": str(rendu / f"{g}_prof.png")} for g in groupes]}
    (travail / "retouche_commune.json").write_text(json.dumps(fiche, ensure_ascii=False, indent=1), encoding="utf-8")
    L = ["#!/bin/bash", "# Retouche commune des pièces (une à la fois : jamais deux retoucher.py en même temps).",
         "set -eu", f'PY=${{RETOUCHE_PY:-python3}}', f'R=${{RETOUCHER:-{RETOUCHER}}}', f"mkdir -p {peint}"]
    for p in fiche["pieces"]:
        L.append(f'$PY $R "{p["entree"]}" "{p["sortie"]}" --profondeur "{p["profondeur"]}" '
                 f'--preset "{reglages["preset"]}" --negatif "{NEGATIF}" --force {reglages["force"]} '
                 f'--controle {reglages["controle"]} --largeur {reglages["largeur"]} --lumiere {reglages["lumiere"]} '
                 f'--couleur {reglages["couleur"]} --fond {reglages["fond"]} --graines {graine}')
    sh = travail / "retoucher_pieces.sh"
    sh.write_text("\n".join(L) + "\n", encoding="utf-8")
    sh.chmod(0o755)
    return len(groupes)


# ------------------------------------------------------------------ planche de contrôle


def planche_normales(pied, rig):
    """Assemblage couleur | normales | couleur éclairée par une lumière rasante (contrôle à l'œil)."""
    W, H = rig["planche"]
    coul = Image.new("RGBA", (W, H))
    norm = Image.new("RGBA", (W, H))
    # ordre z du contrat (RigPersonnage.ORDRE), puis les autres pièces
    ordre = ["bras_arriere", "avant_bras_arriere", "main_arriere", "epauliere_arriere", "cuisse_arriere", "jambe_arriere",
             "pied_arriere", "cape", "bassin", "arme_fourreau", "torse", "tete", "cuisse_avant", "jambe_avant",
             "pied_avant", "bras_avant", "avant_bras_avant", "main_avant", "arme_main", "epauliere_avant"]
    noms = [n for n in ordre if n in rig["pieces"]] + [n for n in rig["pieces"] if n not in ordre]
    for nom in noms:
        e = rig["pieces"][nom]
        if e.get("provisoire") or nom.startswith(("yeux", "bras_tendu", "bras_croises", "casque_main", "tete_casque", "tete_face")):
            continue
        coul.alpha_composite(Image.open(pied / e["fichier"]).convert("RGBA"), tuple(e["pose"]))
        fn = pied / (Path(e["fichier"]).stem + "_normal.png")
        if fn.is_file():
            norm.alpha_composite(Image.open(fn).convert("RGBA"), tuple(e["pose"]))
    c = np.asarray(coul).astype(np.float32) / 255
    n = np.asarray(norm).astype(np.float32)[..., :3] / 127.5 - 1
    lum = np.clip((n @ np.array([-0.6, 0.5, 0.62])), 0, 1) * 1.3 + 0.12
    ecl = c.copy()
    ecl[..., :3] = np.clip(c[..., :3] * lum[..., None], 0, 1)
    out = Image.new("RGBA", (W * 3 + 32, H + 16), (40, 38, 44, 255))
    for i, im in enumerate([coul, norm, Image.fromarray((ecl * 255).astype(np.uint8), "RGBA")]):
        out.alpha_composite(im, (8 + i * (W + 8), 8))
    out.save(pied / "planche_normales.png")


# ------------------------------------------------------------------ commande


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("perso")
    ap.add_argument("--type", choices=sorted(SCRIPTS), required=True)
    ap.add_argument("--travail", required=True, help="dossier de travail (rendu/, pied/, peint/)")
    ap.add_argument("--script", help="script de rendu de CA1 (défaut : selon le type)")
    ap.add_argument("--args", nargs="*", help="arguments du script de rendu après le dossier (défaut : selon le type)")
    ap.add_argument("--spp", type=int, default=32)
    ap.add_argument("--hauteur", type=int, help="hauteur source ×2 (défaut : 460 Astartes, 340 humain)")
    ap.add_argument("--bpy", default=os.environ.get("BPY_PY", "python3"), help="python qui a bpy")
    ap.add_argument("--sans-rendu", action="store_true", help="réutiliser <travail>/rendu/")
    ap.add_argument("--peint", help="passes peintes par groupe (<groupe>_rgb.png, sortie de la retouche commune)")
    ap.add_argument("--couleurs-de", help="livraison peinte dont garder les couleurs (même cadrage)")
    ap.add_argument("--graine", type=int, default=32, help="graine commune de la retouche")
    ap.add_argument("--installer", help="dossier du jeu où copier pied/ (ex. <dépôt>/assets/personnages/vaskar/pied)")
    ap.add_argument("--forcer", action="store_true", help="installe même si le rig en place a des pièces en plus")
    a = ap.parse_args(argv)
    travail = Path(a.travail).expanduser().resolve()
    rendu, pied = travail / "rendu", travail / "pied"
    hauteur = a.hauteur or HAUTEURS[a.type]
    script, defaut = SCRIPTS[a.type]
    script = Path(a.script) if a.script else CA1 / script
    if not a.sans_rendu:
        rendu.mkdir(parents=True, exist_ok=True)
        args = a.args if a.args is not None else [x.format(spp=a.spp, perso=a.perso) for x in defaut]
        lancer([a.bpy, ICI / "passes_blender.py", script, travail] + args)
    # couleur de la découpe : passe peinte, sinon albédo (PEINT_DIR de decouper_pied)
    env = dict(os.environ)
    if a.peint:
        env["PEINT_DIR"] = str(Path(a.peint).resolve())
    else:
        alb = travail / "albedo"
        alb.mkdir(exist_ok=True)
        for f in rendu.glob("*_albedo.png"):
            shutil.copy2(f, alb / f.name.replace("_albedo.png", "_rgb.png"))
        env["PEINT_DIR"] = str(alb)
    if pied.exists():
        shutil.rmtree(pied)
    lancer([sys.executable, CA1 / "decouper_pied.py", travail, a.perso, hauteur, a.type], env=env)
    faites, sans, k = remplacer_normales(rendu, pied, hauteur)
    journal(f"normales Blender : {len(faites)} pièces ; gardées de la découpe : {', '.join(sans) or 'aucune'}")
    couleurs = None
    if a.couleurs_de:
        g, autres = garder_couleurs(pied, a.couleurs_de)
        couleurs = {"de": a.couleurs_de, "gardees": g, "autres": autres}
        journal(f"couleurs gardées de {a.couleurs_de} : {len(g)} pièces ; autres : {', '.join(autres) or 'aucune'}")
    rig = json.loads((pied / "rig.json").read_text(encoding="utf-8"))
    rig["ombre"] = ombre_contact(pied, rig)
    rig["source"] = {"outil": "tools/sprites/preparer_sprite.py", "script": script.name, "date": datetime.date.today().isoformat(),
                     "couleur": "peinte (" + a.peint + ")" if a.peint else ("gardée" if couleurs else "albédo × occlusion"),
                     "normales": "Blender (espace caméra, OpenGL Y+)", "graine_retouche": a.graine}
    rig["_doc"] = (rig.get("_doc", "") + " Normales rendues par Blender et ombre de contact : tools/sprites/preparer_sprite.py.").strip()
    (pied / "rig.json").write_text(json.dumps(rig, ensure_ascii=False, indent=1), encoding="utf-8")
    n = fiche_commune(travail, rendu, a.type, a.perso, a.graine)
    planche_normales(pied, rig)
    journal(f"fiche de retouche commune : {n} pièces, graine {a.graine} -> {travail / 'retouche_commune.json'}")
    if a.installer:
        cible = Path(a.installer)
        manquantes = pieces_perdues(cible / "rig.json", rig)
        if manquantes and not a.forcer:
            journal(f"installation refusée : {cible} a des pièces que cette sortie n'a pas ({', '.join(manquantes)}) ; "
                    "--forcer pour écraser quand même")
            return 1
        cible.mkdir(parents=True, exist_ok=True)
        for f in pied.iterdir():
            if f.suffix in (".png", ".json") and not f.name.startswith(("planche", "assemble")):
                shutil.copy2(f, cible / f.name)
        journal(f"installé dans {cible}")
    journal(f"fini : {pied}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
