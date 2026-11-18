#!/usr/bin/env python3
"""Placeholders de la tranche verticale d'Ullanor (formes simples, à remplacer par la chaîne d'images).

Génère :
- assets/decors/ullanor_bivouac/ : le champ après la fête (zone jouable, 3840×1080) ;
- assets/tranche_ullanor/props/ : personnages et objets détourés (Vaskar, frères, Ilse, Rhino,
  totem, poste de l'Armée, carcasse ork, poutre, civière, plaque, silhouettes lointaines,
  gros plan d'Horus).
Les vrais calques (DA, CA1, CA2, chaîne Blender du Tools) les remplacent au même nom.
Usage : python3 tools/placeholders/generer_tranche_ullanor.py
"""
import json
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DECOR = os.path.join(RACINE, "assets", "decors", "ullanor_bivouac")
PROPS = os.path.join(RACINE, "assets", "tranche_ullanor", "props")
L, H = 3840, 1080
random.seed(31)

BLANC = (226, 222, 210)
BLANC_OMBRE = (150, 140, 135)
OR = (214, 170, 80)
KAKI = (110, 100, 70)
ROUILLE = (120, 70, 40)
SOMBRE = (40, 32, 30)


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def normales(alpha: Image.Image, force=3.0) -> Image.Image:
    """Normales grossières depuis la silhouette (bords bombés), espace tangent OpenGL."""
    petit = alpha.resize((max(1, alpha.width // 4), max(1, alpha.height // 4)))
    h = petit.filter(ImageFilter.GaussianBlur(3))
    w, hh = h.size
    px = h.load()
    out = Image.new("RGB", (w, hh))
    po = out.load()
    for y in range(hh):
        for x in range(w):
            dx = (px[min(x + 1, w - 1), y] - px[max(x - 1, 0), y]) / 255.0 * force
            dy = (px[x, min(y + 1, hh - 1)] - px[x, max(y - 1, 0)]) / 255.0 * force
            n = math.sqrt(dx * dx + dy * dy + 1)
            po[x, y] = (int((-dx / n * .5 + .5) * 255), int((dy / n * .5 + .5) * 255), int((1 / n * .5 + .5) * 255))
    return out.resize(alpha.size, Image.BILINEAR)


def enregistrer(img, dossier, nom, avec_normales=False):
    img.save(os.path.join(dossier, nom + ".png"), optimize=True)
    if avec_normales:
        normales(img.getchannel("A")).save(os.path.join(dossier, nom + "_normal.png"), optimize=True)


def astartes(couleur=BLANC, hauteur=230, casque_sous_bras=False):
    """Silhouette de Space Marine en armure, casque ôté : épaulières, tête nue."""
    w = int(hauteur * 0.62)
    im = Image.new("RGBA", (w, hauteur), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = couleur + (255,)
    o = tuple(int(v * 0.7) for v in couleur) + (255,)
    cx = w // 2
    d.rounded_rectangle([cx - w * .28, hauteur * .2, cx + w * .28, hauteur * .62], 10, fill=c)       # torse
    d.ellipse([cx - w * .5, hauteur * .16, cx - w * .12, hauteur * .4], fill=c)                    # épaulières
    d.ellipse([cx + w * .12, hauteur * .16, cx + w * .5, hauteur * .4], fill=c)
    d.rectangle([cx - w * .25, hauteur * .6, cx - w * .04, hauteur], fill=o)                       # jambes
    d.rectangle([cx + w * .04, hauteur * .6, cx + w * .25, hauteur], fill=o)
    d.ellipse([cx - w * .11, hauteur * .03, cx + w * .11, hauteur * .19], fill=(205, 170, 140, 255))  # tête nue
    if casque_sous_bras:
        d.ellipse([cx + w * .2, hauteur * .4, cx + w * .45, hauteur * .55], fill=c)
    return im


def main():
    os.makedirs(DECOR, exist_ok=True)
    os.makedirs(PROPS, exist_ok=True)

    # ---------------------------------------------------------------- décor du bivouac
    ciel = Image.new("RGBA", (L, H))
    d = ImageDraw.Draw(ciel)
    haut, bas = hexrgb("#6F7FA0"), hexrgb("#F2C877")
    for y in range(H):
        k = min(1.0, y / 640)
        d.line([(0, y), (L, y)], fill=tuple(int(haut[i] + (bas[i] - haut[i]) * k) for i in range(3)) + (255,))
    ciel.save(os.path.join(DECOR, "00_ciel.png"), optimize=True)

    fond = Image.new("RGBA", (L, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(fond)
    d.polygon([(1500, 640), (1950, 330), (2400, 640)], fill=(190, 120, 70, 255))                   # la montagne
    for i, x in enumerate(range(1870, 2040, 34)):
        d.rectangle([x, 300 - (i % 3) * 25, x + 20, 340], fill=(170, 105, 60, 255))                # la citadelle
    pts = [(0, 700)] + [(x, 640 + 20 * math.sin(x / 400)) for x in range(0, L + 1, 120)] + [(L, 700)]
    d.polygon(pts + [(L, H), (0, H)], fill=(170, 110, 70, 255))
    fond.save(os.path.join(DECOR, "10_fond.png"), optimize=True)

    tentes = Image.new("RGBA", (L, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(tentes)
    for i in range(14):
        x = 120 + i * 270 + random.randint(-50, 50)
        w = random.randint(160, 260)
        d.polygon([(x, 720), (x + w // 2, 600 - random.randint(0, 30)), (x + w, 720)], fill=(150, 130, 95, 255))
    for i in range(6):                                                                             # fumées
        x = random.randint(0, L)
        d.line([(x, 700), (x + 60, 420)], fill=(90, 80, 75, 160), width=14)
    enregistrer(tentes, DECOR, "20_tentes", True)

    sol = Image.new("RGBA", (L, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(sol)
    d.rectangle([0, 700, L, H], fill=(120, 85, 55, 255))
    for i in range(160):
        x, y = random.randint(0, L), random.randint(720, H)
        r = random.randint(4, 18)
        d.ellipse([x, y, x + r * 2, y + r], fill=(95, 65, 45, 255))
    enregistrer(sol, DECOR, "30_sol", True)

    decor = {"version": 1, "taille": [L, H], "calques": [
        {"fichier": "00_ciel.png", "profondeur": 0.05, "lumiere": False},
        {"fichier": "10_fond.png", "profondeur": 0.2, "voile": ["#C99A5B", 0.45]},
        {"fichier": "20_tentes.png", "normales": "20_tentes_normal.png", "profondeur": 0.6, "voile": ["#C99A5B", 0.2]},
        {"fichier": "30_sol.png", "normales": "30_sol_normal.png", "profondeur": 1.0},
    ]}
    with open(os.path.join(DECOR, "decor.json"), "w", encoding="utf-8") as f:
        json.dump(decor, f, ensure_ascii=False, indent=2)
        f.write("\n")

    # ---------------------------------------------------------------- personnages et objets
    enregistrer(astartes(), PROPS, "vaskar", True)
    enregistrer(astartes(hauteur=220), PROPS, "frere_1", True)
    enregistrer(astartes(hauteur=225, casque_sous_bras=True), PROPS, "frere_2", True)

    im = Image.new("RGBA", (120, 130), (0, 0, 0, 0))                                               # Ilse assise
    d = ImageDraw.Draw(im)
    d.rectangle([10, 80, 110, 130], fill=(90, 75, 50, 255))                                        # la caisse
    d.rounded_rectangle([40, 30, 80, 85], 8, fill=KAKI + (255,))
    d.ellipse([47, 8, 73, 34], fill=(200, 160, 130, 255))
    d.rectangle([78, 55, 108, 75], fill=(140, 140, 150, 255))                                      # la plaque
    enregistrer(im, PROPS, "ilse", True)

    im = Image.new("RGBA", (70, 30), (0, 0, 0, 0))                                                 # Ilse coincée : une main
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 8, 50, 22], 6, fill=KAKI + (255,))
    d.ellipse([44, 4, 66, 26], fill=(200, 160, 130, 255))
    enregistrer(im, PROPS, "ilse_main")

    im = Image.new("RGBA", (420, 230), (0, 0, 0, 0))                                               # Rhino
    d = ImageDraw.Draw(im)
    d.polygon([(10, 200), (30, 60), (330, 60), (410, 130), (410, 200)], fill=BLANC + (255,))
    d.rectangle([0, 190, 420, 230], fill=SOMBRE + (255,))
    d.rectangle([150, 30, 230, 62], fill=BLANC_OMBRE + (255,))
    enregistrer(im, PROPS, "rhino", True)

    im = Image.new("RGBA", (160, 340), (0, 0, 0, 0))                                               # totem ork brûlé
    d = ImageDraw.Draw(im)
    d.line([(70, 340), (95, 20)], fill=SOMBRE + (255,), width=18)
    d.polygon([(40, 60), (150, 40), (140, 130), (50, 140)], fill=(70, 50, 35, 255))
    d.polygon([(70, 70), (120, 80), (95, 120)], fill=(30, 25, 22, 255))
    enregistrer(im, PROPS, "totem", True)

    im = Image.new("RGBA", (380, 200), (0, 0, 0, 0))                                               # poste de l'Armée
    d = ImageDraw.Draw(im)
    for r in range(3):
        for c in range(7):
            d.ellipse([c * 52 + (r % 2) * 26, 140 - r * 26, c * 52 + 60 + (r % 2) * 26, 170 - r * 26], fill=(150, 130, 90, 255))
    d.polygon([(220, 110), (300, 20), (380, 110)], fill=(120, 110, 80, 255))
    enregistrer(im, PROPS, "poste", True)

    im = Image.new("RGBA", (460, 380), (0, 0, 0, 0))                                               # carcasse ork
    d = ImageDraw.Draw(im)
    d.polygon([(20, 380), (60, 120), (200, 40), (380, 90), (440, 380)], fill=ROUILLE + (255,))
    d.rectangle([150, 110, 260, 180], fill=(70, 45, 30, 255))
    d.line([(300, 80), (420, 10)], fill=(90, 60, 40, 255), width=22)
    enregistrer(im, PROPS, "carcasse", True)

    im = Image.new("RGBA", (360, 44), (0, 0, 0, 0))                                                # poutre
    d = ImageDraw.Draw(im)
    d.rectangle([0, 6, 360, 38], fill=(80, 60, 45, 255))
    d.rectangle([0, 0, 360, 8], fill=(100, 75, 55, 255))
    enregistrer(im, PROPS, "poutre", True)

    im = Image.new("RGBA", (150, 60), (0, 0, 0, 0))                                                # civière et auxiliaires
    d = ImageDraw.Draw(im)
    d.rectangle([20, 30, 130, 38], fill=KAKI + (255,))
    for x in (5, 120):
        d.rounded_rectangle([x, 2, x + 22, 58], 6, fill=(100, 95, 70, 255))
    enregistrer(im, PROPS, "civiere")

    im = Image.new("RGBA", (40, 70), (0, 0, 0, 0))                                                 # Ilse debout, plaque levée
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([12, 22, 28, 70], 5, fill=KAKI + (255,))
    d.ellipse([13, 10, 27, 24], fill=(200, 160, 130, 255))
    d.rectangle([26, 0, 38, 12], fill=(160, 160, 170, 255))
    enregistrer(im, PROPS, "ilse_plaque")

    im = Image.new("RGBA", (16, 30), (0, 0, 0, 0))                                                 # l'Empereur, silhouette d'or
    ImageDraw.Draw(im).rounded_rectangle([3, 0, 13, 30], 4, fill=OR + (255,))
    enregistrer(im, PROPS, "empereur")
    im = Image.new("RGBA", (14, 26), (0, 0, 0, 0))                                                 # Horus, silhouette blanche
    ImageDraw.Draw(im).rounded_rectangle([2, 0, 12, 26], 4, fill=BLANC + (255,))
    enregistrer(im, PROPS, "horus_silhouette")

    im = Image.new("RGBA", (120, 160), (0, 0, 0, 0))                                               # bannière de la 27e
    d = ImageDraw.Draw(im)
    d.line([(10, 0), (10, 160)], fill=SOMBRE + (255,), width=6)
    d.polygon([(12, 6), (110, 6), (110, 90), (61, 110), (12, 90)], fill=BLANC + (255,))
    d.ellipse([45, 30, 80, 65], outline=(60, 70, 110, 255), width=6)
    enregistrer(im, PROPS, "banniere_27e")

    # Gros plan d'Horus (5b-5c) : buste en contre-plongée, plein écran.
    im = Image.new("RGBA", (1920, 1080), (0, 0, 0, 255))
    d = ImageDraw.Draw(im)
    for y in range(1080):
        k = y / 1080
        d.line([(0, y), (1920, y)], fill=(int(60 + 120 * k), int(55 + 80 * k), int(70 + 20 * k), 255))
    d.ellipse([560, 560, 1000, 900], fill=(215, 205, 185, 255))                                    # épaulières
    d.ellipse([920, 560, 1360, 900], fill=(215, 205, 185, 255))
    d.rounded_rectangle([700, 600, 1220, 1080], 40, fill=(225, 215, 195, 255))                     # plastron
    d.ellipse([920, 700, 1000, 760], outline=OR + (255,), width=10)                               # l'œil
    d.rectangle([700, 600, 1220, 640], fill=OR + (255,))
    d.ellipse([840, 250, 1080, 560], fill=(200, 160, 130, 255))                                    # tête nue
    enregistrer(im, PROPS, "horus_gros_plan")


if __name__ == "__main__":
    main()
