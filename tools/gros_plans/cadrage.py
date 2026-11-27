"""Cadrage des bustes de gros plan (calcul de CA1, planche_finale.py) -> data/gros_plans_cadrage.json.

La tête du buste prend la largeur et la place de la tête du gabarit 40 de chaque fond (CA2) :
  fond  : haut de la silhouette gy0, largeur max de la tête gw sur 300 px, centre gcx,
          ligne des yeux gey = gy0 + 0,45 x 260 ;
  buste : ligne des yeux tete_y_px du kit (<perso>_camera_<g|d>.json), largeur de peau bw et
          centre bcx sur cette ligne (buste_<côté>.png de travail de CA1).
Le jeu pose le buste à l'échelle gw / bw, (bcx, tete_y_px) sur (gcx, gey).
Usage : python3 tools/gros_plans/cadrage.py /mnt/project-files/etude-heresie [dépôt]
"""
import glob, json, os, sys
import numpy as np
from PIL import Image

E = sys.argv[1].rstrip("/") + "/"
DEPOT = sys.argv[2] if len(sys.argv) > 2 else "."
KIT = E + "chaine-images/kit-gros-plans/trois_quarts/"
TP2 = E + "chaine-images/retouche/assets/personnages/"


def ld(p):
    return np.asarray(Image.open(p).convert("RGBA")).astype(np.float32) / 255


def peau(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (r > g) & (g > b) & (r - b > 0.10) & (a[..., 3] > 0.5)


sortie = {"note": "généré par tools/gros_plans/cadrage.py (calcul de CA1) : ne pas éditer", "fonds": {}, "bustes": {}}
for dossier in sorted(glob.glob(os.path.join(DEPOT, "assets/decors/*_gros_plan"))):
    fid = os.path.basename(dossier)
    for ep in sorted(glob.glob(E + "episode-*/")):
        cal = ep + fid + "/calques/"
        if not os.path.isdir(cal):
            continue
        for cote in ("gauche", "droite"):
            p = cal + f"gabarit_40_{cote}.png"
            if not os.path.exists(p):
                continue
            g = ld(p)[..., 3] > 0.1
            rows = np.nonzero(g.any(1))[0]
            gy0 = int(rows.min())
            ghr = g[gy0:gy0 + 300]
            gw = int(ghr.sum(1).max())
            gcx = float(np.nonzero(ghr[np.argmax(ghr.sum(1))])[0].mean())
            sortie["fonds"].setdefault(fid, {})[cote] = {"x": round(gcx, 1), "y": round(gy0 + 0.45 * 260, 1), "largeur": gw}
        break
for dossier in sorted(glob.glob(os.path.join(DEPOT, "assets/personnages/*"))):
    perso = os.path.basename(dossier)
    for cote in ("gauche", "droite"):
        cam = KIT + f"{perso}_camera_{'g' if cote == 'gauche' else 'd'}.json"
        bo = TP2 + f"{perso}/buste_{cote}.png"
        if not (os.path.exists(cam) and os.path.exists(bo) and glob.glob(os.path.join(dossier, f"buste_{cote}_*.png"))):
            continue
        bey = json.load(open(cam))["tete_y_px"]
        sk = np.nonzero(peau(ld(bo))[bey])[0]
        sortie["bustes"].setdefault(perso.upper(), {})[cote] = {
            "x": round((sk.min() + sk.max()) / 2, 1), "y": bey, "largeur": int(sk.max() - sk.min())}
json.dump(sortie, open(os.path.join(DEPOT, "data/gros_plans_cadrage.json"), "w"), ensure_ascii=False, indent=1)
print(len(sortie["fonds"]), "fonds,", len(sortie["bustes"]), "bustes")
