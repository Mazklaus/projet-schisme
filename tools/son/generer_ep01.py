#!/usr/bin/env python3
"""Palette sonore de l'épisode 1 : thème des Luna Wolves, motif d'Horus, tunnels de Cthonia.

Même méthode que generer_ullanor.py, dont on reprend les instruments et les outils : tout est
synthétisé, à graine fixe, sans voix ni fichier tiers. Traçabilité : assets/audio/SOURCES.md.

Usage : python3 tools/son/generer_ep01.py <dossier_wav>   (puis encoder_ogg.py)
"""
import numpy as np

from generer_ullanor import (SR, mk, nouveau_hasard, filtre, formants, bruit, place, reverb, reverb_st,
                             boucler, sauver, orgue, choeur, cuivre, timbale, tambour_guerre)

G2 = 98.0    # sol grave : la tonalité des Luna Wolves
D3 = 146.83  # ré : la note d'Horus, déjà tenue sur son gros plan à Ullanor


def ton(demi, base):
    return base * 2 ** (demi / 12)


# ============================================================================ musique

def mus_luna_wolves():
    """Le thème des Luna Wolves : fierté et fraternité, ouvert. Sol mixolydien (le fa naturel ouvre au
    lieu de conclure), deux cors à l'unisson comme des frères qui chantent ensemble, quintes à vide,
    pas de marche lourde. La ligne finit sur la quinte : la phrase reste ouverte et relance la boucle.
    8 mesures à 66 à la noire, jouées deux fois (la seconde à l'octave, avec le chœur et le tambour)."""
    r = nouveau_hasard(4001)
    noire = 60 / 66
    mesure = 4 * noire
    # (basse depuis sol 2, accord depuis sol 3)
    grille = [(0, (0, 4, 7)), (0, (-2, 2, 5)), (0, (0, 5, 9)), (0, (0, 4, 7)),
              (-3, (-3, 0, 4)), (-7, (0, 5, 9)), (-5, (2, 7, 11)), (0, (0, 7, 12))]
    chant = [[(0, 2), (7, 2)], [(5, 2), (2, 2)], [(9, 3), (12, 1)], [(7, 4)],
             [(12, 2), (9, 2)], [(7, 2), (9, 2)], [(12, 2), (11, 2)], [(7, 4)]]       # demi-tons depuis sol 3
    L = mk(mesure * 16)
    m = np.zeros(L + mk(8))
    for tour in range(2):
        for i, (basse, acc) in enumerate(grille):
            t0 = (tour * 8 + i) * mesure
            place(m, orgue(r, ton(basse, G2), mesure + 0.2, 0.4), t0)
            place(m, orgue(r, ton(basse + 7, G2), mesure + 0.2, 0.25), t0)          # la quinte à vide
            for d in acc:
                place(m, orgue(r, ton(d, G2 * 2), mesure + 0.2, 0.18), t0)
                if tour == 1:
                    place(m, choeur(r, ton(d, G2 * 2), mesure + 0.6, "o", force=0.55, attaque=0.6), t0)
            tc = t0
            for d, temps in chant[i]:
                dur = temps * noire
                for frere in range(2):                                              # deux cors à l'unisson
                    place(m, cuivre(r, ton(d, G2 * 2) * (1 + 0.002 * frere), dur * 0.96, 0.45,
                                    attaque=min(0.25, dur * 0.3)), tc + 0.012 * frere)
                if tour == 1:
                    place(m, cuivre(r, ton(d, G2 * 4), dur * 0.96, 0.25, attaque=min(0.25, dur * 0.3)), tc)
                    place(m, choeur(r, ton(d, G2), dur + 0.3, "o", force=0.4, attaque=0.3), tc)
                tc += dur
            if i in (0, 4):
                place(m, timbale(r, G2, 0.7), t0)
            if i == 7:
                place(m, timbale(r, ton(-5, G2), 0.55), t0 + 2 * noire)
            if tour == 1:
                for k in (0, 2):                                                    # le pas des frères, discret
                    place(m, tambour_guerre(r, 0.35 if k == 0 else 0.22), t0 + k * noire)
    st = reverb_st(m, 3.5, 0.38, 4101, sombre=8000)
    return boucler(st, L, 3.5)


def mus_horus_motif():
    """Le motif d'Horus : noble, avec une seule note qui doute. Ré – la – ré – do# – ré, au cor grave
    et au chœur, sur un ré majeur d'orgue. À la reprise, la sensible do# ne monte pas : elle glisse
    d'un demi-ton sur do naturel et y reste, sous un accord qui, lui, n'a pas bougé. 4 mesures à 50."""
    r = nouveau_hasard(4002)
    noire = 60 / 50
    mesure = 4 * noire
    phrase = [[(0, 1), (7, 1), (12, 1.5), (11, 0.5)], [(12, 4)],
              [(0, 1), (7, 1), (12, 1.5), (11, 0.5)], [(10, 4)]]                      # demi-tons depuis ré 3
    L = mk(mesure * 4)
    m = np.zeros(L + mk(8))
    for i in range(4):
        t0 = i * mesure
        place(m, orgue(r, D3 / 2, mesure + 0.2, 0.45), t0)
        for d in (0, 4, 7):
            place(m, orgue(r, ton(d, D3), mesure + 0.2, 0.22), t0)
        tc = t0
        for d, temps in phrase[i]:
            dur = temps * noire
            doute = i == 3
            place(m, cuivre(r, ton(d, D3), dur * 0.97, 0.55 if not doute else 0.4,
                            attaque=min(0.3, dur * 0.3) if not doute else 1.2), tc)
            place(m, choeur(r, ton(d, D3 / 2), dur + 0.4, "o" if not doute else "u", force=0.45,
                            attaque=0.35), tc)
            tc += dur
        if i == 0:
            place(m, timbale(r, D3 / 2, 0.6), t0)
    st = reverb_st(m, 4.5, 0.42, 4102, sombre=6500)
    return boucler(st, L, 4.0)


# ============================================================================ ambiance

def amb_cthonia():
    """Les tunnels de Cthonia, pour les flash-backs : la roche qui pèse, l'eau qui goutte, la vapeur
    dans les conduites, un pilon de mine qui bat au loin, du métal qui travaille, et parfois un coup
    sourd qui roule dans les galeries. Espace étroit, réverbération courte et sombre. 45 s."""
    r = nouveau_hasard(4003)
    L = mk(45.0)
    n = L + mk(5)
    t = np.arange(n) / SR
    roche = bruit(r, n, lo=20, hi=120) * 0.45 + filtre(bruit(r, n), lo=150, hi=600) * 0.03
    pilon = np.zeros(n)                                                                # 1 coup toutes les 1,5 s : 30 par boucle
    for k in range(32):
        kk = mk(0.5)
        tt = np.arange(kk) / SR
        c = np.sin(2 * np.pi * 44 * tt * (1 + 0.3 * np.exp(-tt * 25))) * np.exp(-tt * 9)
        c += filtre(bruit(r, kk), lo=200, hi=1500) * np.exp(-tt * 40) * 0.3
        place(pilon, c * (0.8 if k % 2 == 0 else 0.6), k * 1.5)
    pilon = filtre(pilon, hi=700) * 0.5
    gouttes = np.zeros(n)
    for _ in range(70):
        kk = mk(0.12)
        tt = np.arange(kk) / SR
        f0 = r.uniform(900, 2400)
        c = np.sin(2 * np.pi * f0 * tt * (1 + 0.6 * np.exp(-tt * 60))) * np.exp(-tt * 45)
        place(gouttes, c * r.uniform(0.1, 0.35), r.uniform(0, 45.0))
    vapeur = np.zeros(n)
    for t0 in r.uniform(0, 42.0, 5):
        kk = mk(r.uniform(1.5, 3.0))
        tt = np.arange(kk) / SR
        c = filtre(bruit(r, kk), lo=2500, hi=9000) * np.clip(tt / 0.05, 0, 1) * np.exp(-tt * 1.5)
        place(vapeur, c * 0.12, t0)
    metal = np.zeros(n)                                                                # étais et conduites qui travaillent
    for _ in range(9):
        kk = mk(1.2)
        tt = np.arange(kk) / SR
        f0 = r.uniform(180, 420)
        c = sum(np.sin(2 * np.pi * f0 * h * tt + r.uniform(0, 6)) * np.exp(-tt * (3 + h)) / h for h in (1, 2.76, 5.4))
        c *= np.clip(tt / 0.15, 0, 1)
        place(metal, c * r.uniform(0.04, 0.09), r.uniform(0, 44.0))
    loin = np.zeros(n)                                                                 # un coup sourd dans une galerie voisine
    for t0 in (12.0, 33.5):
        kk = mk(2.0)
        tt = np.arange(kk) / SR
        loin_c = np.sin(2 * np.pi * 52 * tt) * np.exp(-tt * 4) + filtre(bruit(r, kk), lo=80, hi=500) * np.exp(-tt * 10) * 0.5
        place(loin, loin_c * 0.6, t0)
    pres = roche + pilon + gouttes + vapeur + metal
    st = reverb_st(pres, 1.6, 0.45, 4103, sombre=3000)[:n] + reverb_st(filtre(loin, hi=900), 4.0, 0.85, 4105, sombre=1500)[:n]
    return boucler(st, L, 4.0)


if __name__ == "__main__":
    sauver("mus_ep01_luna_wolves", mus_luna_wolves(), crete=0.7, rms_db=-19, finir=False)
    sauver("mus_ep01_horus", mus_horus_motif(), crete=0.7, rms_db=-20, finir=False)
    sauver("amb_ep01_cthonia", amb_cthonia(), crete=0.6, rms_db=-25, finir=False)
