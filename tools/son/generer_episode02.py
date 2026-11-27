#!/usr/bin/env python3
"""Son de l'épisode 2 (préfixe e2_, pour ne pas confondre avec les amb_ep0N_ de l'épisode 1, qui
désignaient des chapitres). Chapitres 1 et 2 : 63-19 et les Whisperheads. Même méthode que
generer_ullanor.py : tout est synthétisé, à graine fixe, sans voix ni fichier tiers.
Traçabilité : assets/audio/SOURCES.md.

Usage : python3 tools/son/generer_episode02.py <dossier_wav>   (puis encoder_ogg.py)
"""
import numpy as np

from generer_ullanor import (SR, mk, nouveau_hasard, filtre, formants, bruit, place, reverb_st, boucler, sauver,
                             foule, cuivre)
from generer_ep02 import coeur_du_vaisseau, voix_parlee
from generer_ep01_ch3_5 import st_de, coup_de_feu, oiseaux


def bolter(r, force=1.0):
    """Un coup de bolter : le départ sourd, puis la détonation de l'obus 40 ms plus loin."""
    kk = mk(0.6)
    tt = np.arange(kk) / SR
    depart = np.sin(2 * np.pi * 70 * tt) * np.exp(-tt * 22) + filtre(bruit(r, kk), lo=200, hi=3000) * np.exp(-tt * 50) * 0.6
    det = np.zeros(kk)
    k0 = mk(0.04)
    det[k0:] = (filtre(bruit(r, kk - k0), lo=100, hi=5000) * np.exp(-tt[:kk - k0] * 30)
                + np.sin(2 * np.pi * 50 * tt[:kk - k0]) * np.exp(-tt[:kk - k0] * 12) * 0.8)
    return (depart + det * 0.9) * force


def fanfare(r, transpo=0.0):
    """La fanfare de la cour : deux trompettes claires, un peu fausses l'une contre l'autre, un air
    pompeux et court en si bémol. Une majesté de pacotille, mais jouée sincèrement. 5 s."""
    air = [(0, 0.5), (4, 0.25), (7, 0.25), (12, 1.0), (9, 0.5), (7, 0.5), (5, 0.5), (4, 0.5), (7, 1.0)]
    base = 233.08 * 2 ** (transpo / 12)
    y = np.zeros(mk(6.0))
    tc = 0.0
    for d, temps in air:
        dur = temps * 0.55
        for voix, desacc in ((0, 1.0), (1, 2 ** (22 / 1200))):                       # la seconde trompette, 22 cents trop haut
            note = cuivre(r, base * 2 ** (d / 12) * desacc, dur * 0.95, 0.5, attaque=0.04)
            place(y, filtre(note, lo=300, hi=4500), tc + 0.01 * voix)
        tc += dur
    return y


# ============================================================================ chapitre 1 : 63-19

def amb_cour_or():
    """La cour d'or du palais de 63-19, avant l'assaut : un faste creux. Un dallage immense, des
    bannières dans le vent, les pas d'une garde d'apparat qui change de poste, une fontaine, et de
    loin en loin une fanfare de deux trompettes qui sonne sous les colonnades. 40 s."""
    r = nouveau_hasard(7001)
    L = mk(40.0)
    n = L + mk(5)
    t = np.arange(n) / SR
    vent = filtre(bruit(r, n), lo=200, hi=1800) * (0.7 + 0.3 * np.sin(2 * np.pi * t / 20.0)) * 0.05 + bruit(r, n, lo=30, hi=150) * 0.06
    bannieres = filtre(bruit(r, n), lo=600, hi=3000) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 10.0)) ** 3 * 0.025
    fontaine = filtre(bruit(r, n), lo=900, hi=6000) * 0.012 + filtre(bruit(r, n), lo=200, hi=800) * 0.01
    loin = np.zeros(n)
    for t0 in (2.0, 22.0):                                                             # une fanfare toutes les 20 s
        place(loin, fanfare(r) * 0.25, t0)
    for t0 in (11.0, 31.0):                                                            # la garde d'apparat change de poste
        for p in range(12):
            kk = mk(0.2)
            tt = np.arange(kk) / SR
            pas = filtre(bruit(r, kk), lo=800, hi=5000) * np.exp(-tt * 70) + np.sin(2 * np.pi * 150 * tt) * np.exp(-tt * 40) * 0.3
            place(loin, pas * 0.08 * np.sin(np.pi * (p + 0.5) / 12), t0 + p * 0.5)
    st = st_de(vent + bannieres + fontaine, 1.0, 0.25, 7101, 5000, n) + st_de(loin, 4.5, 0.75, 7103, 5000, n)
    return boucler(st, L, 4.0)


def amb_cour_or_assaut():
    """La même cour sous l'assaut (la 27e tient un flanc) : les bolters de la Légion, lourds et
    proches, contre les fusils laser des gardes d'apparat ; le marbre qui éclate, une corne d'alarme
    du palais, archaïque, qui sonne encore. La fanfare s'est tue. 45 s."""
    r = nouveau_hasard(7002)
    L = mk(45.0)
    n = L + mk(5)
    t = np.arange(n) / SR
    fond = bruit(r, n, lo=30, hi=200) * 0.15 + filtre(bruit(r, n), lo=200, hi=1500) * 0.04
    tirs = np.zeros(n)
    tc = 0.3
    while tc < 44.0:
        if r.random() < 0.5:                                                           # rafale de bolter
            for k in range(int(r.integers(2, 5))):
                place(tirs, bolter(r, r.uniform(0.5, 0.9)), tc + k * 0.16)
        else:                                                                          # les gardes répondent
            for k in range(int(r.integers(2, 6))):
                place(tirs, coup_de_feu(r, r.uniform(0.2, 0.4), laser=True), tc + k * 0.22)
        tc += r.uniform(0.6, 2.4)
    marbre = np.zeros(n)
    for _ in range(9):                                                                 # le marbre qui éclate
        kk = mk(1.0)
        tt = np.arange(kk) / SR
        c = filtre(bruit(r, kk), lo=600, hi=7000) * np.exp(-tt * 9) + sum(
            np.sin(2 * np.pi * r.uniform(900, 2500) * tt) * np.exp(-tt * 25) for _ in range(3)) * 0.1
        place(marbre, c * 0.3, r.uniform(0, 44.0))
    corne = np.zeros(n)
    for t0 in (5.0, 27.5):                                                             # corne d'alarme, deux notes
        for k, (f, d) in enumerate(((196.0, 1.6), (174.6, 2.4))):
            place(corne, cuivre(r, f, d, 0.6, attaque=0.2), t0 + k * 1.7)
    st = (st_de(fond, 1.0, 0.2, 7105, 3000, n) + st_de(tirs + marbre, 2.5, 0.55, 7107, 4500, n)
          + st_de(filtre(corne, hi=2500) * 0.25, 4.5, 0.85, 7109, 3500, n))
    return boucler(st, L, 4.0)


def amb_tour():
    """Le flanc, au moment où Horus monte à la tour : la bataille se tait par vagues, quelques tirs
    loin dans la ville, le vent en hauteur, la fumée. C'est l'attente : le tir unique et l'éclair de
    téléportation sont des bruitages à part (sfx_e2_teleport, sfx_e2_tir_unique). 40 s."""
    r = nouveau_hasard(7003)
    L = mk(40.0)
    n = L + mk(5)
    t = np.arange(n) / SR
    vent = filtre(bruit(r, n), lo=150, hi=2000) * (0.6 + 0.4 * np.sin(2 * np.pi * t / 13.333)) * 0.08 + bruit(r, n, lo=30, hi=200) * 0.1
    loin = np.zeros(n)
    for _ in range(14):
        place(loin, bolter(r, r.uniform(0.2, 0.5)) if r.random() < 0.5 else coup_de_feu(r, 0.3, True), r.uniform(0, 39.0))
    feu = np.zeros(n)
    for _ in range(200):
        kk = mk(0.02)
        place(feu, filtre(bruit(r, kk), lo=900, hi=5000) * np.hanning(kk) * r.uniform(0.01, 0.04), r.uniform(0, 40.0))
    st = st_de(vent + feu, 1.0, 0.2, 7111, 4000, n) + st_de(filtre(loin, hi=1500), 5.0, 0.9, 7113, 2500, n) * 0.7
    return boucler(st, L, 4.0)


def sfx_teleport():
    """L'éclair de téléportation au sommet de la tour, entendu de loin : l'air qui se charge, puis
    l'implosion et son tonnerre qui roule. 4 s."""
    r = nouveau_hasard(7004)
    n = mk(4.0)
    t = np.arange(n) / SR
    charge = filtre(bruit(r, n), lo=2000, hi=8000) * np.clip(t / 0.6, 0, 1) ** 2 * (t < 0.6) * 0.3
    k0 = mk(0.6)
    tt = t[:n - k0]
    eclat = np.zeros(n)
    eclat[k0:] = (filtre(bruit(r, n - k0), lo=40, hi=3000) * np.exp(-tt * 3) + np.sin(2 * np.pi * 45 * tt) * np.exp(-tt * 2.5) * 0.8)
    y = charge + filtre(eclat, hi=2500)
    return reverb_st(y, 4.0, 0.6, 7115, 3000)


def sfx_tir_unique():
    """Le tir unique d'Horus, entendu depuis le flanc : un seul coup, très loin, qui revient trois fois
    sur les façades. Rien d'autre. 5 s."""
    r = nouveau_hasard(7005)
    n = mk(5.0)
    y = np.zeros(n)
    place(y, filtre(bolter(r, 1.0), hi=2200), 0.0)
    for k, (dt, g) in enumerate(((0.42, 0.45), (0.9, 0.3), (1.55, 0.18))):             # les échos sur les façades
        place(y, filtre(bolter(r, g), hi=1500 - 300 * k), dt)
    return reverb_st(y, 4.5, 0.6, 7117, 2500)


def amb_palais_soir():
    """Le palais pris, le soir : une salle du trône immense et vide. Le vent par les vitres brisées,
    des feux dans la ville, une fontaine qui coule encore, un frère qui marche loin dans une galerie.
    Le silence d'après. 45 s."""
    r = nouveau_hasard(7006)
    L = mk(45.0)
    n = L + mk(5)
    t = np.arange(n) / SR
    salle = bruit(r, n, lo=30, hi=200) * 0.08 + filtre(bruit(r, n), lo=200, hi=1200) * 0.01
    vent = formants(r.standard_normal(n), (520.0, 1240.0), (25.0, 40.0), (1.0, 0.5)) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 15.0)) ** 2 * 0.02
    gouttes = np.zeros(n)
    for k in range(int(45 / 2.25)):
        kk = mk(0.1)
        tt = np.arange(kk) / SR
        place(gouttes, np.sin(2 * np.pi * 1150 * tt * (1 + 0.4 * np.exp(-tt * 60))) * np.exp(-tt * 40) * 0.05, k * 2.25 + 0.4)
    loin = np.zeros(n)
    for t0 in (14.0, 35.0):
        for p in range(8):
            kk = mk(0.25)
            tt = np.arange(kk) / SR
            pas = np.sin(2 * np.pi * 65 * tt) * np.exp(-tt * 25) + filtre(bruit(r, kk), lo=400, hi=2500) * np.exp(-tt * 60) * 0.4
            place(loin, pas * 0.1, t0 + p * 0.65)
    feux = filtre(bruit(r, n), lo=60, hi=400) * 0.03
    st = st_de(salle + vent + feux, 1.0, 0.2, 7119, 3500, n) + st_de(gouttes + loin, 5.5, 0.85, 7121, 3500, n)
    return boucler(st, L, 5.0)


def sfx_couronne():
    """La couronne que Dremm jette : l'or creux qui frappe le marbre, rebondit, roule et tourne sur
    elle-même avant de se poser. 3 s."""
    r = nouveau_hasard(7007)
    n = mk(3.0)
    y = np.zeros(n)

    def choc(force, f0):
        kk = mk(0.5)
        tt = np.arange(kk) / SR
        return (sum(np.sin(2 * np.pi * f0 * h * tt + r.uniform(0, 6)) * np.exp(-tt * (8 + 4 * h)) / h for h in (1, 2.31, 3.9, 5.6))
                + filtre(bruit(r, kk), lo=1500, hi=8000) * np.exp(-tt * 80) * 0.5) * force

    for dt, g in ((0.0, 1.0), (0.28, 0.6), (0.48, 0.4), (0.62, 0.25)):
        place(y, choc(g, 980), dt)
    kk = mk(1.6)                                                                       # elle tourne sur la tranche, de plus en plus vite
    tt = np.arange(kk) / SR
    vit = 6 + 30 * (tt / 1.6) ** 2
    roul = filtre(bruit(r, kk), lo=1500, hi=6000) * (0.5 + 0.5 * np.sin(2 * np.pi * np.cumsum(vit) / SR)) * np.exp(-tt * 1.2) * 0.25
    place(y, roul, 0.75)
    place(y, choc(0.3, 980), 2.35)
    return reverb_st(y, 3.5, 0.45, 7123, 6000)


# ============================================================================ chapitre 2 : les Whisperheads

def amb_navettes():
    """Le grand hangar du Vengeful Spirit, trois mois plus tard : les navettes des civils arrivent.
    Les turbines qui se posent, une foule de civils qui parle (voix d'hommes et de femmes, sans mots),
    des malles qu'on roule, un signal de bord à deux tons, sans annonce parlée. 50 s."""
    r = nouveau_hasard(7008)
    L = mk(50.0)
    n = L + mk(6)
    t = np.arange(n) / SR
    fond = coeur_du_vaisseau(r, n, 0.45)
    turbine = np.zeros(n)
    for t0 in (0.0, 20.0, 36.0):
        kk = mk(14.0)
        tt = np.arange(kk) / SR
        f = 800 * np.exp(-tt / 5) + 200
        c = (np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.4 + filtre(bruit(r, kk), lo=300, hi=3500)) * np.exp(-tt / 6) * np.clip(tt / 1.0, 0, 1)
        place(turbine, c * 0.1, t0)
    civils = np.zeros(n)
    for f0 in (110, 125, 140, 190, 205, 220, 118, 230, 132, 200):
        tc = r.uniform(0, 4)
        while tc < 49.0:
            d = r.uniform(1.0, 3.0)
            place(civils, voix_parlee(r, d, f0, fermee=1300.0) * r.uniform(0.4, 0.9), tc)
            tc += d + r.uniform(0.5, 3.0)
    malles = np.zeros(n)
    for _ in range(8):
        kk = mk(r.uniform(1.0, 2.5))
        tt = np.arange(kk) / SR
        roul = filtre(bruit(r, kk), lo=150, hi=1200) * (0.6 + 0.4 * np.sin(2 * np.pi * r.uniform(8, 14) * tt)) * np.hanning(kk)
        place(malles, roul * 0.05, r.uniform(0, 48.0))
    signal = np.zeros(n)
    for t0 in (8.0, 33.0):                                                             # signal de bord à deux tons
        for k, f in enumerate((660.0, 495.0)):
            kk = mk(0.45)
            tt = np.arange(kk) / SR
            place(signal, np.sin(2 * np.pi * f * tt) * np.exp(-tt * 3) * np.clip(tt / 0.01, 0, 1) * 0.06, t0 + k * 0.5)
    st = st_de(fond + turbine, 3.0, 0.4, 7125, 3000, n) + st_de(civils * 0.25 + malles + signal, 5.0, 0.7, 7127, 4000, n)
    return boucler(st, L, 5.0)


def amb_whisperheads():
    """Les Whisperheads : une crête de montagne dans le brouillard et la pluie, la nuit. Le vent froid
    qui siffle sur la roche, la pluie fine, des pierres qui roulent, et l'assaut de la 10e sur la
    forteresse voisine, étouffé par le brouillard : des éclairs de bruit sans forme. 50 s."""
    r = nouveau_hasard(7009)
    L = mk(50.0)
    n = L + mk(6)
    t = np.arange(n) / SR
    rafales = 0.5 + 0.5 * np.sin(2 * np.pi * t / 12.5) * np.sin(2 * np.pi * t / 25.0 + 1)
    vent = filtre(bruit(r, n), lo=200, hi=2500) * rafales * 0.12 + bruit(r, n, lo=30, hi=150) * 0.15
    sifflet = formants(r.standard_normal(n), (740.0,), (10.0,), (1.0,)) * rafales ** 3 * 0.12
    pluie = filtre(bruit(r, n), lo=2000, hi=10000) * 0.03
    for _ in range(900):
        kk = mk(0.01)
        place(pluie, filtre(bruit(r, kk), lo=2500, hi=9000) * np.hanning(kk) * r.uniform(0.01, 0.05), r.uniform(0, 50.0))
    pierres = np.zeros(n)
    for _ in range(5):
        for k in range(int(r.integers(3, 7))):
            kk = mk(0.1)
            tt = np.arange(kk) / SR
            place(pierres, np.sin(2 * np.pi * r.uniform(400, 900) * tt) * np.exp(-tt * 50) * 0.06, r.uniform(0, 49.0) + k * 0.12)
    assaut = np.zeros(n)
    for _ in range(30):
        place(assaut, bolter(r, r.uniform(0.3, 0.8)), r.uniform(0, 49.0))
    assaut = filtre(assaut, hi=500)                                                    # le brouillard mange tout l'aigu
    st = (st_de(vent + sifflet + pluie, 1.2, 0.2, 7129, 6000, n) + st_de(pierres, 2.0, 0.5, 7131, 4000, n)
          + st_de(assaut, 6.0, 0.95, 7133, 1200, n) * 0.6)
    return boucler(st, L, 5.0)


def vox_canal(r, n):
    """Le canal vox de l'escouade : souffle de porteuse en bande étroite, crépitements, clics."""
    t = np.arange(n) / SR
    y = filtre(bruit(r, n), lo=500, hi=3200) * 0.08
    for _ in range(int(n / SR * 6)):
        kk = mk(0.01)
        place(y, filtre(bruit(r, kk), lo=1500, hi=5000) * np.hanning(kk) * r.uniform(0.1, 0.4), r.uniform(0, n / SR))
    return y


def amb_vox_escouade():
    """Le vox de l'escouade sur la crête : la porteuse, les crépitements, des appels brefs entre
    frères (syllabes voisées passées dans la bande du vox, sans un mot), les clics de micro. À jouer
    sur le canal d'ambiance, par-dessus amb_e2_whisperheads, ou en bruitage. 30 s."""
    r = nouveau_hasard(7010)
    L = mk(30.0)
    n = L + mk(1)
    y = vox_canal(r, n)
    tc = 1.0
    while tc < 28.5:                                                                   # un frère appelle, un autre répond
        d = r.uniform(0.8, 1.8)
        place(y, filtre(bruit(r, mk(0.03)), lo=1000, hi=4000) * 0.4, tc - 0.05)       # clic de micro
        v = voix_parlee(r, d, r.choice([95, 105, 112, 120]), fermee=3000.0)
        v = np.tanh(filtre(v, lo=450, hi=2800) * 3.0) * 0.25                            # bande du vox, saturée
        place(y, v, tc)
        place(y, filtre(bruit(r, mk(0.03)), lo=1000, hi=4000) * 0.3, tc + d + 0.02)
        tc += d + r.uniform(1.5, 5.0)
    y = np.stack([y, y], 1)
    return boucler(y, L, 0.5)


def sfx_vox_anomalie():
    """La « voix » dans le vox (décision du GD : sans mots, par une anomalie du signal). Dans le souffle
    de la porteuse, une respiration régulière qui ne vient d'aucun casque ; puis le bruit lui-même se
    met à battre en deux temps, toujours les deux mêmes, comme un nom qu'on ne distingue pas ; une
    modulation lente descend sous le souffle, là où aucun signal ne devrait exister. Le texte à
    l'écran porte le nom. Ambigu : on peut toujours croire à une panne. 9 s."""
    r = nouveau_hasard(7011)
    D = 9.0
    n = mk(D)
    t = np.arange(n) / SR
    canal = vox_canal(r, n)
    souffle = np.zeros(n)
    for t0 in (0.6, 2.9, 5.2):                                                         # une respiration, période 2,3 s, trop régulière
        kk = mk(1.8)
        tt = np.arange(kk) / SR
        env = np.sin(np.pi * np.clip(tt / 0.8, 0, 1)) * (tt < 0.8) + np.sin(np.pi * np.clip((tt - 0.9) / 0.9, 0, 1)) * (tt >= 0.9) * 0.7
        place(souffle, formants(bruit(r, kk), (600.0, 1500.0), (250.0, 400.0), (1.0, 0.5)) * env * 0.25, t0)
    # Le bruit bat en deux temps (long-court), trois fois, à partir de 4 s : aucun mot, une forme.
    battement = np.ones(n)
    for k in range(3):
        t0 = 4.0 + k * 1.4
        for dt, d, g in ((0.0, 0.32, 2.2), (0.42, 0.2, 1.8)):
            m = (t >= t0 + dt) & (t < t0 + dt + d)
            battement[m] = g * np.sin(np.pi * (t[m] - t0 - dt) / d) + 1
    canal = canal * battement
    f = 180 * np.exp(-np.clip(t - 3.5, 0, None) / 4.0) + 60                            # la modulation qui descend sous le souffle
    sous = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.clip((t - 3.5) / 1.5, 0, 1) * np.clip((D - t) / 1.0, 0, 1) * 0.05
    y = canal + souffle + filtre(sous * (1 + 0.5 * np.sin(2 * np.pi * 7 * t)), lo=50, hi=800)
    y[mk(8.6):] *= np.linspace(1, 0, n - mk(8.6))                                      # coupure franche du canal
    return np.stack([y, y], 1)


def sfx_vox_cris():
    """L'incident de Jubal, ailleurs dans la forteresse, tel que le vox le rapporte : des tirs, des cris
    de gorge sans mots (voyelles brèves, saturées), puis le canal qui coupe. 6 s."""
    r = nouveau_hasard(7012)
    n = mk(6.0)
    y = vox_canal(r, n)
    for _ in range(10):
        place(y, filtre(bolter(r, r.uniform(0.3, 0.7)), lo=400, hi=3000), r.uniform(0.2, 5.0))
    for t0 in (0.8, 1.9, 3.1, 4.2):
        c = foule(r, 0.6, (140, 260), 3, "a")
        c = np.tanh(filtre(c, lo=450, hi=2800) * 40) * 0.3 * np.hanning(len(c))
        place(y, c, t0)
    y[mk(5.6):] = 0
    return np.stack([y, y], 1)


if __name__ == "__main__":
    sauver("amb_e2_cour_or", amb_cour_or(), crete=0.6, rms_db=-27, finir=False)
    sauver("amb_e2_cour_or_assaut", amb_cour_or_assaut(), crete=0.85, rms_db=-22, finir=False)
    sauver("amb_e2_tour", amb_tour(), crete=0.6, rms_db=-27, finir=False)
    sauver("sfx_e2_teleport", sfx_teleport(), crete=0.85)
    sauver("sfx_e2_tir_unique", sfx_tir_unique(), crete=0.85)
    sauver("amb_e2_palais_soir", amb_palais_soir(), crete=0.5, rms_db=-31, finir=False)
    sauver("sfx_e2_couronne", sfx_couronne(), crete=0.7)
    sauver("amb_e2_navettes", amb_navettes(), crete=0.6, rms_db=-26, finir=False)
    sauver("amb_e2_whisperheads", amb_whisperheads(), crete=0.7, rms_db=-24, finir=False)
    sauver("amb_e2_vox_escouade", amb_vox_escouade(), crete=0.5, rms_db=-30, finir=False)
    sauver("sfx_e2_vox_anomalie", sfx_vox_anomalie(), crete=0.6)
    sauver("sfx_e2_vox_cris", sfx_vox_cris(), crete=0.6)
