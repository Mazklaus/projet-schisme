#!/usr/bin/env python3
"""Ambiances de l'épisode 1, chapitres 3 à 5 : la barge de bataille (décors barge_*) et Orvane
(décors orvane_*). Même méthode que generer_ullanor.py : tout est synthétisé, à graine fixe, sans
voix ni fichier tiers, et chaque fichier est tracé dans assets/audio/SOURCES.md.

Usage : python3 tools/son/generer_ep01_ch3_5.py <dossier_wav>   (puis encoder_ogg.py)
"""
import numpy as np

from generer_ullanor import SR, mk, nouveau_hasard, filtre, formants, bruit, place, reverb_st, boucler, sauver, foule
from generer_ep02 import coeur_du_vaisseau, voix_parlee, rire, gobelet


def st_de(mono, sec, wet, graine, sombre, n):
    return reverb_st(mono, sec, wet, graine, sombre)[:n]


def coup_de_feu(r, force=1.0, laser=False):
    """Un tir : le claquement, et pour un fusil laser le « zip » qui descend."""
    kk = mk(0.3)
    tt = np.arange(kk) / SR
    y = filtre(bruit(r, kk), lo=400, hi=6000) * np.exp(-tt * 70) + np.sin(2 * np.pi * 85 * tt) * np.exp(-tt * 28) * 0.5
    if laser:
        f = 3200 * np.exp(-tt * 40) + 700
        y += np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 35) * 0.5
    return y * force


def sirene(r, n, periode, f_bas, f_haut, force):
    t = np.arange(n) / SR
    f = f_bas + (f_haut - f_bas) * (0.5 - 0.5 * np.cos(2 * np.pi * t / periode))
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.3 * np.sin(2 * np.pi * np.cumsum(2 * f) / SR)
    return filtre(y, hi=1500) * force


def oiseaux(r, n, nombre, t_max):
    y = np.zeros(n)
    for _ in range(nombre):
        t0 = r.uniform(0, t_max)
        f0 = r.uniform(2500, 4200)
        for k in range(int(r.integers(2, 5))):
            kk = mk(0.08)
            tt = np.arange(kk) / SR
            f = f0 * (1 + 0.25 * np.sin(np.pi * tt / 0.08)) * r.uniform(0.95, 1.05)
            place(y, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.hanning(kk) * 0.03, t0 + k * 0.13)
    return y


# ============================================================================ la barge

def amb_barge_pont():
    """Le pont d'embarquement de la barge (ch. 3, l'arrivée des remembrancers) : un hangar immense,
    une navette dont les turbines retombent, l'hydraulique qui souffle, le métal chaud qui cliquette,
    les serfs qui s'affairent au loin, une grue qui passe. 50 s, réverbération de 5 s."""
    r = nouveau_hasard(6001)
    L = mk(50.0)
    n = L + mk(6)
    t = np.arange(n) / SR
    fond = coeur_du_vaisseau(r, n, 0.5) + filtre(bruit(r, n), lo=200, hi=1500) * 0.03
    turbine = np.zeros(n)                                                              # deux navettes : 0 s et 25 s
    for t0 in (0.0, 25.0):
        kk = mk(18.0)
        tt = np.arange(kk) / SR
        f = 900 * np.exp(-tt / 6) + 180
        c = (np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.5 + filtre(bruit(r, kk), lo=300, hi=3000) * 0.8) * np.exp(-tt / 7)
        place(turbine, c * np.clip(tt / 0.5, 0, 1) * 0.12, t0)
    actif = np.zeros(n)
    for _ in range(12):                                                                # hydraulique
        kk = mk(r.uniform(0.6, 1.5))
        tt = np.arange(kk) / SR
        place(actif, filtre(bruit(r, kk), lo=1500, hi=8000) * np.exp(-tt * 3) * np.clip(tt / 0.03, 0, 1) * 0.06,
              r.uniform(0, 48.0))
    for _ in range(60):                                                                # le métal chaud qui cliquette
        kk = mk(0.05)
        tt = np.arange(kk) / SR
        place(actif, np.sin(2 * np.pi * r.uniform(2000, 4500) * tt) * np.exp(-tt * 120) * 0.03, r.uniform(0, 50.0))
    for t0 in (12.0, 37.0):                                                            # une grue qui passe
        kk = mk(6.0)
        tt = np.arange(kk) / SR
        c = filtre(np.sign(np.sin(2 * np.pi * 70 * tt)) + bruit(r, kk) * 0.3, lo=60, hi=900) * np.sin(np.pi * tt / 6) ** 2
        place(actif, c * 0.04, t0)
    serfs = np.zeros(n)
    for f0 in (98, 104, 112, 120, 126, 132, 140, 108):
        tc = r.uniform(0, 5)
        while tc < 48.0:
            d = r.uniform(1.0, 3.0)
            place(serfs, voix_parlee(r, d, f0, fermee=900.0) * r.uniform(0.3, 0.7), tc)
            tc += d + r.uniform(1.0, 5.0)
    m = fond + turbine
    st = st_de(m, 3.0, 0.4, 6101, 3000, n) + st_de(actif + serfs * 0.25, 5.0, 0.8, 6103, 3500, n)
    return boucler(st, L, 5.0)


def amb_barge():
    """L'intérieur de la barge (quartiers de la 27e, galerie, salle de briefing) : un vaisseau plus petit
    et plus nerveux que le Vengeful Spirit. Les moteurs plus proches, la ventilation plus forte, un
    relais plus rapide, des tuyaux qui travaillent, des pas dans une coursive voisine. 50 s."""
    r = nouveau_hasard(6002)
    L = mk(50.0)
    n = L + mk(5)
    t = np.arange(n) / SR
    moteur = np.zeros(n)
    for f, a in ((40.0, 1.0), (60.0, 0.6), (80.0, 0.4), (120.0, 0.2), (200.0, 0.06)):
        moteur += a * np.sin(2 * np.pi * f * t + r.uniform(0, 6.3))
    moteur = moteur * 0.06 * (0.9 + 0.1 * np.sin(2 * np.pi * t / 25.0)) + bruit(r, n, lo=25, hi=120) * 0.1
    ventil = filtre(bruit(r, n), lo=300, hi=2500) * 0.05 + formants(r.standard_normal(n), (420.0,), (10.0,), (1.0,)) * 0.02
    detail = np.zeros(n)
    for k in range(int(50 / 1.25) + 2):                                                # relais : 1 clic toutes les 1,25 s
        kk = mk(0.08)
        tt = np.arange(kk) / SR
        place(detail, np.sin(2 * np.pi * 1700 * tt) * np.exp(-tt * 90) * 0.05, k * 1.25)
    for _ in range(14):                                                                # tuyaux qui travaillent
        kk = mk(0.8)
        tt = np.arange(kk) / SR
        f0 = r.uniform(250, 600)
        c = sum(np.sin(2 * np.pi * f0 * h * tt) * np.exp(-tt * (5 + 2 * h)) / h for h in (1, 2.4, 4.1))
        place(detail, c * r.uniform(0.02, 0.05), r.uniform(0, 49.0))
    for t0 in (9.0, 33.0):                                                             # des pas dans une coursive voisine
        for p in range(10):
            kk = mk(0.25)
            tt = np.arange(kk) / SR
            pas = np.sin(2 * np.pi * 65 * tt) * np.exp(-tt * 25) + filtre(bruit(r, kk), lo=400, hi=2500) * np.exp(-tt * 60) * 0.4
            place(detail, pas * 0.12 * np.sin(np.pi * (p + 0.5) / 10), t0 + p * 0.6)
    st = st_de(moteur + ventil, 2.0, 0.35, 6105, 3000, n) + st_de(filtre(detail, hi=3000), 3.0, 0.7, 6107, 3500, n)
    return boucler(st, L, 4.0)


def amb_quartiers_civils():
    """Les quartiers des remembrancers (ch. 3) : une lumière civile et chaude. Des conversations à voix
    d'hommes et de femmes, plus vives que chez les frères, une plume qui gratte, du papier, une tasse
    posée, un rire de temps en temps, et la barge assourdie derrière les cloisons. 45 s."""
    r = nouveau_hasard(6003)
    L = mk(45.0)
    n = L + mk(4)
    fond = filtre(coeur_du_vaisseau(r, n, 0.5), hi=120) * 0.25 + filtre(bruit(r, n), lo=200, hi=1200) * 0.01
    paroles = np.zeros((n, 2))
    for f0, pan in ((115, 0.25), (205, 0.6), (132, 0.8), (225, 0.4), (122, 0.1)):
        tc = r.uniform(0, 3)
        while tc < 44.0:
            d = r.uniform(1.2, 3.5)
            v = voix_parlee(r, d, f0 * r.uniform(0.95, 1.05), fermee=1700.0) * r.uniform(0.5, 1.0)
            k0 = mk(tc)
            k1 = min(n, k0 + len(v))
            paroles[k0:k1, 0] += v[:k1 - k0] * np.sqrt(1 - pan)
            paroles[k0:k1, 1] += v[:k1 - k0] * np.sqrt(pan)
            tc += d + r.uniform(1.0, 4.0)
    gestes = np.zeros(n)
    for t0 in (5.0, 18.0, 30.0, 40.0):                                                 # une plume qui gratte
        kk = mk(2.0)
        tt = np.arange(kk) / SR
        traits = (np.sin(2 * np.pi * r.uniform(4, 7) * tt) > 0.2) * np.hanning(kk)
        place(gestes, filtre(bruit(r, kk), lo=2500, hi=8000) * traits * 0.025, t0)
    for _ in range(6):                                                                 # une tasse posée
        place(gestes, gobelet(r) * 0.12, r.uniform(0, 44.0))
    for t0 in (12.0, 26.5):                                                            # une page
        kk = mk(0.6)
        tt = np.arange(kk) / SR
        place(gestes, filtre(bruit(r, kk), lo=1500, hi=7000) * np.sin(np.pi * tt / 0.6) ** 2 * 0.04, t0)
    rires = np.zeros(n)
    for t0, f0, g in ((15.0, 210, 0.5), (34.0, 125, 0.6)):
        place(rires, rire(r, f0) * g, t0)
    mono = fond + gestes + rires * 0.3
    m = np.stack([mono, mono], 1) + paroles * 0.2
    st = np.stack([reverb_st(m[:, 0], 1.2, 0.25, 6109, 4500)[:n, 0], reverb_st(m[:, 1], 1.2, 0.25, 6111, 4500)[:n, 1]], 1)
    return boucler(st, L, 3.0)


def amb_cabine():
    """Une cabine de la barge, la nuit (Sefa qui écrit, les quartiers du codicier) : la barge étouffée,
    une bouche d'aération, et c'est tout. Rien d'étrange : le frisson du codicier passe par ses yeux,
    jamais par le son (règle du GD). 40 s."""
    r = nouveau_hasard(6004)
    L = mk(40.0)
    n = L + mk(3)
    fond = filtre(coeur_du_vaisseau(r, n, 0.6), hi=100) * 0.4 + filtre(bruit(r, n), lo=150, hi=900) * 0.02
    aeration = filtre(bruit(r, n), lo=600, hi=3000) * 0.012
    gestes = np.zeros(n)
    for t0 in (11.0, 29.0):                                                            # un meuble, un vêtement
        kk = mk(0.4)
        tt = np.arange(kk) / SR
        place(gestes, filtre(bruit(r, kk), lo=300, hi=2000) * np.exp(-tt * 15) * 0.03, t0)
    st = st_de(fond + aeration + gestes, 0.7, 0.25, 6113, 3500, n)
    return boucler(st, L, 2.0)


# ============================================================================ Orvane

def amb_orvane_nuit():
    """Orvane la nuit (ch. 4, l'approche et l'émissaire) : une cité-ruche humaine, vivante. Le
    grondement lointain de la ville, une sirène d'alerte qui monte et descend très loin, le vent sur
    les toits, un générateur, un coup sourd de temps en temps. Ce n'est pas un monde d'aliens. 50 s."""
    r = nouveau_hasard(6005)
    L = mk(50.0)
    n = L + mk(5)
    t = np.arange(n) / SR
    ville = bruit(r, n, lo=30, hi=400) * 0.3 * (0.9 + 0.1 * np.sin(2 * np.pi * t / 25.0))
    vent = filtre(bruit(r, n), lo=200, hi=2000) * (0.6 + 0.4 * np.sin(2 * np.pi * t / 12.5)) * 0.06
    gen = filtre(np.sign(np.sin(2 * np.pi * 50 * t)), lo=80, hi=600) * 0.006
    loin = sirene(r, n, 10.0, 420, 640, 0.05)
    for t0 in (17.0, 41.0):
        kk = mk(2.5)
        tt = np.arange(kk) / SR
        place(loin, filtre(bruit(r, kk), lo=30, hi=400) * np.exp(-tt * 2.5) * 0.5, t0)
    st = st_de(ville + vent + gen, 1.5, 0.3, 6115, 3000, n) + st_de(filtre(loin, hi=1500), 4.0, 0.8, 6117, 2500, n)
    return boucler(st, L, 4.0)


def amb_orvane_rues():
    """L'assaut dans les rues et aux barricades (ch. 4) : des tirs à moyenne distance, fusils laser et
    armes à projectiles des insurgés, des ricochets, une sirène plus proche, du feu, des gravats qui
    tombent, et la rumeur paniquée d'une foule qui fuit loin derrière les immeubles. 50 s."""
    r = nouveau_hasard(6006)
    L = mk(50.0)
    n = L + mk(5)
    t = np.arange(n) / SR
    feu = filtre(bruit(r, n), lo=60, hi=500) * 0.12
    for _ in range(400):
        kk = mk(0.02)
        place(feu, filtre(bruit(r, kk), lo=900, hi=6000) * np.hanning(kk) * r.uniform(0.03, 0.1), r.uniform(0, 50.0))
    tirs = np.zeros(n)
    tc = 0.5
    while tc < 49.0:
        laser = r.random() < 0.5
        if r.random() < 0.4:
            for k in range(int(r.integers(3, 8))):
                place(tirs, coup_de_feu(r, r.uniform(0.3, 0.6), laser), tc + k * (0.18 if laser else 0.08))
        else:
            place(tirs, coup_de_feu(r, r.uniform(0.4, 0.9), laser), tc)
        if r.random() < 0.15:                                                          # ricochet
            kk = mk(0.25)
            tt = np.arange(kk) / SR
            f = 2600 * np.exp(-tt * 4)
            place(tirs, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 8) * 0.12, tc + 0.05)
        tc += r.uniform(0.4, 2.2)
    gravats = np.zeros(n)
    for t0 in (8.0, 23.0, 39.0):
        kk = mk(2.0)
        tt = np.arange(kk) / SR
        place(gravats, filtre(bruit(r, kk), lo=100, hi=3000) * np.exp(-tt * 2.5) * (0.6 + 0.4 * np.sin(2 * np.pi * 13 * tt)) * 0.3, t0)
    fuite = foule(r, 50.0 + 5.0, (150, 330), 10, "a")[:n] * 0.5 * (0.6 + 0.4 * np.sin(2 * np.pi * t / 12.5))
    alerte = sirene(r, n, 6.25, 500, 820, 0.05)
    loin = filtre(fuite, lo=200, hi=1200) + alerte
    st = (st_de(feu, 1.2, 0.3, 6119, 4000, n) + st_de(filtre(tirs, hi=5000) + gravats, 2.5, 0.6, 6121, 3500, n)
          + st_de(loin, 3.5, 0.8, 6123, 2500, n) * 0.6)
    return boucler(st, L, 4.0)


def amb_orvane_bloc():
    """Le bloc d'habitation, à l'aube naissante (ch. 4, la crise du choix C7) : des tirs isolés depuis
    les fenêtres, qui claquent et reviennent entre les murs, des voix étouffées à l'intérieur (des
    civils, sans un mot intelligible), du verre qui tombe, le vent. Les premiers oiseaux, malgré tout.
    Tendu, jamais mélodramatique. 45 s."""
    r = nouveau_hasard(6007)
    L = mk(45.0)
    n = L + mk(5)
    t = np.arange(n) / SR
    vent = filtre(bruit(r, n), lo=150, hi=1500) * (0.7 + 0.3 * np.sin(2 * np.pi * t / 15.0)) * 0.06 + bruit(r, n, lo=30, hi=200) * 0.12
    tirs = np.zeros(n)
    for t0 in (2.0, 6.5, 7.1, 14.0, 21.5, 22.0, 22.4, 30.0, 37.5, 41.0):
        place(tirs, coup_de_feu(r, r.uniform(0.6, 1.0)), t0)
    for _ in range(5):                                                                 # du verre qui tombe
        kk = mk(0.8)
        tt = np.arange(kk) / SR
        c = sum(np.sin(2 * np.pi * r.uniform(3000, 6500) * tt + r.uniform(0, 6)) * np.exp(-tt * r.uniform(15, 30)) for _ in range(6))
        place(tirs, c * 0.02, r.uniform(0, 44.0))
    dedans = np.zeros(n)
    for f0 in (110, 130, 200, 220, 180, 120):
        tc = r.uniform(0, 4)
        while tc < 44.0:
            d = r.uniform(1.0, 2.5)
            place(dedans, voix_parlee(r, d, f0, fermee=600.0) * r.uniform(0.4, 0.8), tc)
            tc += d + r.uniform(1.0, 4.0)
    st = (st_de(vent + oiseaux(r, n, 6, 44.0), 1.0, 0.2, 6125, 5000, n)
          + st_de(tirs, 3.0, 0.7, 6127, 4000, n) * 0.8 + st_de(dedans * 0.3, 0.8, 0.4, 6129, 2000, n))
    return boucler(st, L, 4.0)


def amb_orvane_matin():
    """Orvane au matin (ch. 4, la retombée) : la ville après. Des feux qui finissent de brûler, de l'eau
    qui goutte d'une conduite crevée, une sirène qui s'éloigne, un véhicule loin, le vent qui porte
    la cendre, quelques oiseaux. Rien ne dit qui a eu raison : le son reste le même pour toutes les
    branches. 45 s."""
    r = nouveau_hasard(6008)
    L = mk(45.0)
    n = L + mk(4)
    t = np.arange(n) / SR
    vent = filtre(bruit(r, n), lo=150, hi=1800) * (0.7 + 0.3 * np.sin(2 * np.pi * t / 15.0)) * 0.07 + bruit(r, n, lo=30, hi=150) * 0.08
    feu = filtre(bruit(r, n), lo=80, hi=500) * 0.04
    for _ in range(150):
        kk = mk(0.02)
        place(feu, filtre(bruit(r, kk), lo=900, hi=5000) * np.hanning(kk) * r.uniform(0.02, 0.06), r.uniform(0, 45.0))
    gouttes = np.zeros(n)
    for k in range(int(45 / 1.8)):
        kk = mk(0.1)
        tt = np.arange(kk) / SR
        place(gouttes, np.sin(2 * np.pi * 1300 * tt * (1 + 0.5 * np.exp(-tt * 60))) * np.exp(-tt * 50) * 0.08, k * 1.8 + 0.3)
    loin = sirene(r, n, 15.0, 380, 560, 0.025)
    st = st_de(vent + feu + gouttes + oiseaux(r, n, 10, 44.0), 1.2, 0.25, 6131, 4500, n) + st_de(loin, 4.0, 0.85, 6133, 2500, n)
    return boucler(st, L, 4.0)


def amb_orvane_soir():
    """Orvane le soir (ch. 5, les Luna Wolves gravent leurs morts) : le calme après. Le vent, un
    brasero, un générateur lointain, les insectes du soir, et, loin le long du mur, des ciseaux qui
    frappent la pierre à intervalles réguliers : on grave des noms. 45 s."""
    r = nouveau_hasard(6009)
    L = mk(45.0)
    n = L + mk(4)
    t = np.arange(n) / SR
    vent = filtre(bruit(r, n), lo=150, hi=1500) * (0.7 + 0.3 * np.sin(2 * np.pi * t / 15.0)) * 0.05 + bruit(r, n, lo=30, hi=150) * 0.06
    brasero = filtre(bruit(r, n), lo=80, hi=600) * 0.05
    for _ in range(120):
        kk = mk(0.02)
        place(brasero, filtre(bruit(r, kk), lo=900, hi=5000) * np.hanning(kk) * r.uniform(0.02, 0.05), r.uniform(0, 45.0))
    insectes = np.zeros(n)
    for f0, per in ((4300, 0.9), (5100, 1.3)):
        stri = (np.sin(2 * np.pi * t / per) > 0.3) * (0.5 + 0.5 * np.sin(2 * np.pi * 30 * t))
        insectes += np.sin(2 * np.pi * f0 * t) * stri * 0.006
    graver = np.zeros(n)
    for depart in (1.0, 2.7):                                                          # deux frères qui gravent, chacun son rythme
        tc = depart
        while tc < 44.5:
            kk = mk(0.12)
            tt = np.arange(kk) / SR
            c = filtre(bruit(r, kk), lo=1500, hi=7000) * np.exp(-tt * 60) + np.sin(2 * np.pi * r.uniform(1800, 2400) * tt) * np.exp(-tt * 50) * 0.4
            place(graver, c * 0.12, tc)
            tc += r.uniform(0.55, 0.75) if r.random() < 0.85 else r.uniform(2.0, 4.0)
    gen = filtre(np.sign(np.sin(2 * np.pi * 50 * t)), lo=80, hi=500) * 0.004
    st = st_de(vent + brasero + insectes + gen, 1.0, 0.2, 6135, 5000, n) + st_de(filtre(graver, hi=4000), 2.5, 0.75, 6137, 3500, n)
    return boucler(st, L, 4.0)


if __name__ == "__main__":
    sauver("amb_ep03_barge_pont", amb_barge_pont(), crete=0.6, rms_db=-25, finir=False)
    sauver("amb_ep03_barge", amb_barge(), crete=0.6, rms_db=-27, finir=False)
    sauver("amb_ep03_quartiers_civils", amb_quartiers_civils(), crete=0.5, rms_db=-29, finir=False)
    sauver("amb_ep03_cabine", amb_cabine(), crete=0.4, rms_db=-34, finir=False)
    sauver("amb_ep04_orvane_nuit", amb_orvane_nuit(), crete=0.6, rms_db=-27, finir=False)
    sauver("amb_ep04_orvane_rues", amb_orvane_rues(), crete=0.85, rms_db=-22, finir=False)
    sauver("amb_ep04_orvane_bloc", amb_orvane_bloc(), crete=0.8, rms_db=-26, finir=False)
    sauver("amb_ep04_orvane_matin", amb_orvane_matin(), crete=0.6, rms_db=-28, finir=False)
    sauver("amb_ep05_orvane_soir", amb_orvane_soir(), crete=0.6, rms_db=-29, finir=False)
