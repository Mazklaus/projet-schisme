"""Cadrage des bustes de gros plan (calcul de CA1, planche_finale.py) -> data/gros_plans_cadrage.json.

La tête du buste prend la largeur et la place de la tête du gabarit 40 de chaque fond (CA2) :
  fond  : haut de la silhouette gy0, largeur max de la tête gw sur 300 px, centre gcx,
          ligne des yeux gey = gy0 + 0,45 x 260 ;
  buste : sur le buste final neutre, silhouette de la tête : haut du crâne, largeur maximale
          et axe, jusqu'aux épaules.
Le jeu garde l'axe du gabarit (gcx) et resserre (DA 27/11) : crâne à 15 %, menton à 45 %, la
hauteur de tête étant estimée à 1,08 largeur de silhouette (RAPPORT_TETE du jeu).
Usage : python3 tools/gros_plans/cadrage.py /mnt/project-files/etude-heresie [dépôt]
"""
import glob, json, os, sys
import numpy as np
from PIL import Image

E = sys.argv[1].rstrip("/") + "/"
DEPOT = sys.argv[2] if len(sys.argv) > 2 else "."


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
        fin = os.path.join(dossier, f"buste_{cote}_neutre.png")
        if not os.path.exists(fin):
            continue
        al = ld(fin)[..., 3] > 0.5
        w = al.shape[1]
        # Silhouette de la tête (comme le gabarit, qui est une silhouette) : depuis le point le
        # plus haut du tiers central, la plage opaque continue qui le contient, ligne à ligne,
        # jusqu'aux épaules (largeur > 1,6 fois la médiane).
        centre = al[:, int(0.3 * w):int(0.7 * w)]
        crane = int(np.nonzero(centre.any(1))[0].min())
        cx = int(0.3 * w) + int(np.nonzero(centre[crane])[0].mean())
        larg, milieux = [], []
        for y in range(crane, crane + 500):
            if not al[y, cx]:
                break
            g = cx
            while g > 0 and al[y, g - 1]:
                g -= 1
            d = cx
            while d < w - 1 and al[y, d + 1]:
                d += 1
            if len(larg) > 20 and d - g > 1.6 * float(np.median(larg)):
                break
            larg.append(d - g)
            milieux.append((g + d) / 2)
            cx = int(round((g + d) / 2))
        largeur = int(max(larg))
        x = float(np.mean(milieux[len(milieux) // 4:]))
        sortie["bustes"].setdefault(perso.upper(), {})[cote] = {
            "x": round(x, 1), "crane": crane, "largeur": largeur}
json.dump(sortie, open(os.path.join(DEPOT, "data/gros_plans_cadrage.json"), "w"), ensure_ascii=False, indent=1)
print(len(sortie["fonds"]), "fonds,", len(sortie["bustes"]), "bustes")
