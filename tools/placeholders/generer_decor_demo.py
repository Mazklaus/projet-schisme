#!/usr/bin/env python3
"""Génère le décor placeholder assets/decors/demo/ (calques, normales, decor.json).

Formes géométriques seulement : sert à tester le moteur (parallaxe, lumières, normales)
avant les vrais calques de la chaîne d'images. Usage : python3 tools/placeholders/generer_decor_demo.py
"""
import json
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SORTIE = os.path.join(RACINE, "assets", "decors", "demo")
L, H = 2560, 1080
random.seed(40000)


def normales(hauteur: Image.Image, force: float = 4.0) -> Image.Image:
    """Carte de normales (espace tangent OpenGL, Y vers le haut) depuis une carte de hauteur."""
    h = hauteur.convert("L").filter(ImageFilter.GaussianBlur(2))
    w, hh = h.size
    px = h.load()
    out = Image.new("RGB", (w, hh))
    po = out.load()
    for y in range(hh):
        for x in range(w):
            dx = (px[min(x + 1, w - 1), y] - px[max(x - 1, 0), y]) / 255.0 * force
            dy = (px[x, min(y + 1, hh - 1)] - px[x, max(y - 1, 0)]) / 255.0 * force
            nx, ny, nz = -dx, dy, 1.0  # Y image vers le bas -> Y normale vers le haut
            n = math.sqrt(nx * nx + ny * ny + nz * nz)
            po[x, y] = (int((nx / n * 0.5 + 0.5) * 255), int((ny / n * 0.5 + 0.5) * 255), int((nz / n * 0.5 + 0.5) * 255))
    return out


def calque(nom, taille, dessin, couleur, avec_normales=True):
    masque = Image.new("L", taille, 0)
    dessin(ImageDraw.Draw(masque))
    img = Image.new("RGBA", taille, couleur + (0,))
    img.putalpha(masque)
    img.save(os.path.join(SORTIE, nom + ".png"), optimize=True)
    if avec_normales:
        # Petite échelle pour garder le script rapide, puis agrandissement.
        petit = masque.resize((taille[0] // 4, taille[1] // 4))
        normales(petit).resize(taille, Image.BILINEAR).save(os.path.join(SORTIE, nom + "_n.png"), optimize=True)


def main():
    os.makedirs(SORTIE, exist_ok=True)
    # Ciel : dégradé ocre, non éclairé par les lumières 2D.
    ciel = Image.new("RGBA", (L, H))
    d = ImageDraw.Draw(ciel)
    for y in range(H):
        k = y / H
        d.line([(0, y), (L, y)], fill=(int(60 + 140 * k), int(40 + 90 * k), int(30 + 40 * k), 255))
    ciel.save(os.path.join(SORTIE, "00_ciel.png"), optimize=True)

    def collines(dr):
        pts = [(0, H)]
        for x in range(0, L + 1, 80):
            pts.append((x, 620 + 60 * math.sin(x / 300) + random.randint(-20, 20)))
        pts.append((L, H))
        dr.polygon(pts, fill=255)

    def ruines(dr):
        for i in range(9):
            x = 120 + i * 280 + random.randint(-40, 40)
            w = random.randint(60, 140)
            h = random.randint(220, 480)
            dr.rectangle([x, H - 180 - h, x + w, H - 180], fill=255)
            dr.polygon([(x, H - 180 - h), (x + w, H - 180 - h), (x + w // 2, H - 220 - h)], fill=200)

    def sol(dr):
        dr.rectangle([0, H - 200, L, H], fill=255)
        for i in range(40):
            x = random.randint(0, L)
            y = H - 190 + random.randint(0, 150)
            dr.ellipse([x, y, x + 60, y + 20], fill=170)

    def colonne(dr):
        dr.rectangle([60, 40, 240, 700], fill=255)
        dr.rectangle([20, 0, 280, 60], fill=230)
        for y in range(100, 680, 60):
            dr.line([(60, y), (240, y)], fill=150, width=6)

    calque("10_collines", (L, H), collines, (70, 50, 40))
    calque("20_ruines", (L, H), ruines, (95, 80, 70))
    calque("30_sol", (L, H), sol, (80, 65, 50))
    calque("40_colonne", (300, 700), colonne, (40, 34, 30))

    decor = {
        "version": 1,
        "taille": [L, H],
        "calques": [
            {"fichier": "00_ciel.png", "profondeur": 0.05, "lumiere": False},
            {"fichier": "10_collines.png", "normales": "10_collines_n.png", "profondeur": 0.3},
            {"fichier": "20_ruines.png", "normales": "20_ruines_n.png", "profondeur": 0.6},
            {"fichier": "30_sol.png", "normales": "30_sol_n.png", "profondeur": 1.0},
            {"fichier": "40_colonne.png", "normales": "40_colonne_n.png", "profondeur": 1.3, "position": [1700, 380]},
        ],
    }
    with open(os.path.join(SORTIE, "decor.json"), "w", encoding="utf-8") as f:
        json.dump(decor, f, ensure_ascii=False, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
