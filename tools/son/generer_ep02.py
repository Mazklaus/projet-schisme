#!/usr/bin/env python3
"""Ambiances du Vengeful Spirit, chapitres 2 et 3 : le vaisseau-cathédrale à l'état pur, et la salle
de la loge. Même méthode que generer_ullanor.py, dont on reprend les outils : tout est synthétisé, à
graine fixe, sans voix ni fichier tiers. Traçabilité : assets/audio/SOURCES.md.

Usage : python3 tools/son/generer_ep02.py <dossier_wav>   (puis encoder_ogg.py)
"""
import numpy as np

from generer_ullanor import SR, mk, nouveau_hasard, filtre, formants, bruit, place, reverb_st, boucler, sauver


def coeur_du_vaisseau(r, n, force=1.0):
    """Le grondement des moteurs et du réacteur, toujours là, très bas : des harmoniques stables
    (ordre) qui respirent lentement, périodes de 20 et 30 s pour boucler juste sur 60 s."""
    t = np.arange(n) / SR
    y = np.zeros(n)
    for f, a in ((32.0, 1.0), (48.0, 0.5), (64.0, 0.35), (96.0, 0.15), (128.0, 0.08), (192.0, 0.03)):
        y += a * np.sin(2 * np.pi * f * t + r.uniform(0, 6.3))
    y *= 0.85 + 0.15 * np.sin(2 * np.pi * t / 30.0) * np.sin(2 * np.pi * t / 20.0 + 1)
    y += bruit(r, n, lo=20, hi=90) * 0.4
    return y * 0.25 * force


def amb_vengeful_spirit():
    """Le Vengeful Spirit à l'état pur : une nef de vaisseau grande comme une cathédrale, propre,
    en ordre, fière. Le cœur du vaisseau sous le pont, l'air qui circule dans les gaines, un
    relais qui bat régulièrement au loin, le pas d'une escouade qui passe en cadence, les sas
    lourds qui se ferment loin, et des machines qui travaillent sur les ponts inférieurs. 60 s."""
    r = nouveau_hasard(5001)
    L = mk(60.0)
    n = L + mk(8)
    t = np.arange(n) / SR
    coeur = coeur_du_vaisseau(r, n)
    air = filtre(bruit(r, n), lo=250, hi=1600) * 0.035 * (0.9 + 0.1 * np.sin(2 * np.pi * t / 12.0))
    gaine = formants(r.standard_normal(n), (310.0, 620.0), (8.0, 12.0), (1.0, 0.4)) * 0.03   # sifflement tenu d'une gaine
    lointain = np.zeros(n)
    for k in range(int(60.0 / 2.5) + 2):                                               # relais : 2 clics doux toutes les 2,5 s
        for dt, g in ((0.0, 1.0), (0.18, 0.6)):
            kk = mk(0.15)
            tt = np.arange(kk) / SR
            c = np.sin(2 * np.pi * 1350 * tt) * np.exp(-tt * 70) + filtre(bruit(r, kk), lo=2000, hi=6000) * np.exp(-tt * 120) * 0.3
            place(lointain, c * 0.1 * g, k * 2.5 + dt)
    for t0 in (8.0, 38.0):                                                             # une escouade passe, en cadence
        for p in range(18):
            kk = mk(0.3)
            tt = np.arange(kk) / SR
            for homme in range(5):
                pas = np.sin(2 * np.pi * r.uniform(55, 75) * tt) * np.exp(-tt * 22)
                pas += filtre(bruit(r, kk), lo=400, hi=3000) * np.exp(-tt * 60) * 0.45
                env = np.sin(np.pi * p / 17) ** 0.7                                        # elle approche puis s'éloigne
                place(lointain, pas * 0.15 * env * r.uniform(0.7, 1), t0 + p * 0.58 + abs(r.normal(0, 0.012)))
    for t0 in (21.0, 51.5):                                                            # un sas lourd qui se ferme
        kk = mk(3.0)
        tt = np.arange(kk) / SR
        sas = filtre(bruit(r, kk), lo=60, hi=900) * np.clip(tt / 0.8, 0, 1) * (tt < 0.9) * 0.15
        coup = np.sin(2 * np.pi * 41 * tt) * np.exp(-tt * 3.5) * (tt >= 0.9) + filtre(bruit(r, kk), lo=100, hi=1200) * np.exp(-np.maximum(tt - 0.9, 0) * 12) * (tt >= 0.9) * 0.5
        place(lointain, (sas + coup) * 0.7, t0)
    for _ in range(10):                                                                # machines des ponts inférieurs
        kk = mk(r.uniform(2.0, 4.0))
        tt = np.arange(kk) / SR
        f0 = r.uniform(70, 140)
        c = np.sign(np.sin(2 * np.pi * f0 * tt)) * 0.3 + np.sin(2 * np.pi * f0 * 2 * tt)
        c = filtre(c, hi=500) * np.hanning(kk) * (0.6 + 0.4 * np.sin(2 * np.pi * r.uniform(3, 6) * tt))
        place(lointain, c * 0.1, r.uniform(0, 58.0))
    lointain = filtre(lointain, hi=2500)
    pres = coeur * 0.4 + air * 3.0 + gaine * 1.5
    st = reverb_st(pres, 3.0, 0.4, 5101, sombre=3000)[:n] + reverb_st(lointain * 2.5, 6.5, 0.85, 5103, sombre=3500)[:n]
    return boucler(st, L, 6.0)


def voix_parlee(r, dur, f0, fermee=1400.0):
    """Une voix grave qui parle derrière la table, sans un mot : des syllabes voisées (4 à 5 par
    seconde) dont la voyelle change à chaque fois, une intonation qui descend en fin de phrase, et un
    filtre qui garde le grain et efface l'articulation."""
    n = mk(dur)
    t = np.arange(n) / SR
    contour = f0 * (1 + 0.12 * np.sin(2 * np.pi * r.uniform(0.3, 0.6) * t + r.uniform(0, 6)) - 0.1 * t / dur)
    ph = np.cumsum(contour) / SR
    y = 2 * (ph % 1) - 1 + bruit(r, n) * 0.1
    sortie = np.zeros(n)
    tc = 0.0
    while tc < dur - 0.1:
        d = r.uniform(0.14, 0.3)
        k0, k1 = mk(tc), min(n, mk(tc + d))
        F = (r.uniform(300, 700), r.uniform(900, 1700), 2500.0)
        morceau = formants(y[k0:k1], F, (120, 200, 300), (1.0, 0.5, 0.15))
        sortie[k0:k1] += morceau * np.hanning(k1 - k0) ** 0.7 * r.uniform(0.5, 1)
        tc += d + (r.uniform(0.2, 0.5) if r.random() < 0.12 else 0.0)
    return filtre(sortie, hi=fermee, ordre=2) * np.clip(t / 0.05, 0, 1) * np.clip((dur - t) / 0.2, 0, 1)


def rire(r, f0):
    """Un rire bref et franc : 4 à 6 éclats sur « a », de plus en plus courts, qui descendent."""
    k = int(r.integers(4, 7))
    sortie = np.zeros(mk(2.0))
    for i in range(k):
        d = 0.13 * (1 - 0.06 * i)
        n = mk(d)
        t = np.arange(n) / SR
        ph = np.cumsum(f0 * (1.25 - 0.05 * i) * (1 - 0.15 * t / d)) / SR
        y = (2 * (ph % 1) - 1) + bruit(r, n) * 0.35                                     # souffle dans le rire
        y = formants(y, (720, 1150, 2500), (150, 200, 300), (1.0, 0.6, 0.2)) * np.hanning(n)
        place(sortie, y * (1 - 0.12 * i), i * 0.2)
    return filtre(sortie, hi=2500)


def gobelet(r):
    """Un gobelet de métal posé sur la caisse qui sert de table : le bois sourd, puis l'étain qui sonne."""
    n = mk(0.6)
    t = np.arange(n) / SR
    bois = np.sin(2 * np.pi * r.uniform(150, 220) * t) * np.exp(-t * 35) + filtre(bruit(r, n), lo=200, hi=1500) * np.exp(-t * 80) * 0.5
    f = r.uniform(1400, 2600)
    metal = sum(np.sin(2 * np.pi * f * h * t + r.uniform(0, 6)) * np.exp(-t * (12 + 6 * h)) / h for h in (1, 1.58, 2.3))
    return bois + metal * 0.25


def amb_loge():
    """La salle de la loge en veillée (réalignement du GD, 27/11, d'après la DA) : des frères autour
    d'une caisse-table, visages découverts. Des conversations graves et inintelligibles qui se
    croisent, des gobelets posés, un rire bref de temps en temps, les bougies qui grésillent, le cœur
    du vaisseau étouffé par les murs. C'est chaleureux : le malaise vient de ce que le joueur sait,
    jamais du son. 45 s."""
    r = nouveau_hasard(5002)
    L = mk(45.0)
    n = L + mk(4)
    coeur = filtre(coeur_du_vaisseau(r, n, 0.6), hi=110)
    bougies = np.zeros(n)
    for _ in range(140):                                                               # mèches qui grésillent
        kk = mk(0.03)
        place(bougies, filtre(bruit(r, kk), lo=1500, hi=6000) * np.hanning(kk) * r.uniform(0.02, 0.06), r.uniform(0, 45.0))
    paroles = np.zeros((n, 2))
    for f0, pan in ((92, 0.3), (105, 0.7), (118, 0.45), (99, 0.15), (128, 0.85)):     # cinq frères, chacun sa place
        tc = r.uniform(0, 4)
        while tc < 44.0:
            d = r.uniform(1.5, 4.0)
            v = voix_parlee(r, d, f0 * r.uniform(0.95, 1.05)) * r.uniform(0.5, 1.0)
            k0 = mk(tc)
            k1 = min(n, k0 + len(v))
            paroles[k0:k1, 0] += v[:k1 - k0] * np.sqrt(1 - pan)
            paroles[k0:k1, 1] += v[:k1 - k0] * np.sqrt(pan)
            tc += d + r.uniform(1.5, 6.0)                                               # chacun parle à son tour
    rires = np.zeros(n)
    for t0, f0, g in ((9.5, 120, 1.0), (27.0, 105, 0.7), (39.0, 135, 0.6)):
        place(rires, rire(r, f0) * g, t0)
    gestes = np.zeros(n)
    for _ in range(14):
        place(gestes, gobelet(r) * r.uniform(0.3, 0.7), r.uniform(0, 44.0))
    mono = coeur * 0.12 + bougies * 1.0 + gestes * 0.12 + rires * 0.35
    m = np.stack([mono, mono], 1) + paroles * 0.18
    st = np.stack([reverb_st(m[:, 0], 1.6, 0.3, 5102, sombre=4000)[:, 0],
                   reverb_st(m[:, 1], 1.6, 0.3, 5104, sombre=4000)[:, 1]], 1)[:n]
    return boucler(st, L, 3.0)


if __name__ == "__main__":
    sauver("amb_ep02_vengeful_spirit", amb_vengeful_spirit(), crete=0.6, rms_db=-26, finir=False)
    sauver("amb_ep02_loge", amb_loge(), crete=0.5, rms_db=-30, finir=False)
