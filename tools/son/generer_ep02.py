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


def amb_loge():
    """La salle de la loge, à bord : une pièce close de pierre et de métal. Des dizaines de bougies,
    une assemblée silencieuse qui respire, un pied qui bouge, une armure qui craque, et le cœur du
    vaisseau, étouffé par les murs. Rien d'occulte : pas de nappe dissonante, pas de chuchotement.
    C'est le calme d'hommes réunis, pas une menace. 45 s."""
    r = nouveau_hasard(5002)
    L = mk(45.0)
    n = L + mk(4)
    t = np.arange(n) / SR
    coeur = filtre(coeur_du_vaisseau(r, n, 0.6), hi=110)
    bougies = np.zeros(n)
    for b in range(24):                                                                # flamme : souffle qui vacille
        vac = np.abs(filtre(r.standard_normal(n), hi=6)) * 6
        bougies += filtre(bruit(r, n), lo=150, hi=900) * vac * 0.004
    for _ in range(90):                                                                # mèche qui grésille
        kk = mk(0.03)
        place(bougies, filtre(bruit(r, kk), lo=1500, hi=6000) * np.hanning(kk) * r.uniform(0.02, 0.06), r.uniform(0, 45.0))
    souffles = np.zeros(n)
    for _ in range(40):                                                                # une assemblée qui respire, chacun à son rythme
        periode = r.uniform(4.0, 6.0)
        t0 = r.uniform(0, periode)
        while t0 < 45.0:
            kk = mk(periode * 0.8)
            tt = np.arange(kk) / SR
            ins = np.clip(tt / (periode * 0.35), 0, 1) * (tt < periode * 0.35)
            exp_ = np.clip(1 - (tt - periode * 0.35) / (periode * 0.45), 0, 1) * (tt >= periode * 0.35)
            env = np.sin(np.pi * ins / 2) * 0.5 + exp_ ** 2
            c = formants(bruit(r, kk), (500.0, 1400.0), (300.0, 500.0), (1.0, 0.4)) * env
            place(souffles, c * r.uniform(0.3, 1.0) * 0.012, t0)
            t0 += periode * r.uniform(0.9, 1.1)
    gestes = np.zeros(n)
    for _ in range(7):                                                                 # une armure qui craque, un pied qui bouge
        kk = mk(0.4)
        tt = np.arange(kk) / SR
        c = filtre(bruit(r, kk), lo=300, hi=2500) * np.exp(-tt * 18) + np.sin(2 * np.pi * r.uniform(200, 350) * tt) * np.exp(-tt * 25) * 0.3
        place(gestes, c * r.uniform(0.03, 0.07), r.uniform(0, 44.0))
    m = coeur * 0.12 + bougies * 2.5 + souffles * 4.0 + gestes * 2.0
    st = reverb_st(m, 1.8, 0.35, 5102, sombre=4000)[:n]
    return boucler(st, L, 3.0)


if __name__ == "__main__":
    sauver("amb_ep02_vengeful_spirit", amb_vengeful_spirit(), crete=0.6, rms_db=-26, finir=False)
    sauver("amb_ep02_loge", amb_loge(), crete=0.5, rms_db=-30, finir=False)
