#!/usr/bin/env python3
"""Bruitages des animations et des effets (épisode 1, puis toute la saga) : pas, gestes et servos
d'armure, tirs, fumées, bougies, vitres. Chaque famille a plusieurs variantes (_01, _02…) que
l'autoload Son tire au hasard. Tout est synthétisé, à graine fixe, sans fichier tiers.
Traçabilité : assets/audio/SOURCES.md.

Usage : python3 tools/son/generer_bruitages.py <dossier_wav>   (puis encoder_ogg.py)
"""
import numpy as np

from generer_ullanor import SR, mk, nouveau_hasard, filtre, bruit, place, reverb_st, boucler, sauver
from generer_ep01_ch3_5 import coup_de_feu


def bolter(r, force=1.0):
    """Un coup de bolter : le départ sourd, puis la détonation de l'obus 40 ms plus loin (même recette
    que generer_episode02.py, recopiée ici pour que ce générateur ne dépende pas de l'épisode 2)."""
    kk = mk(0.6)
    tt = np.arange(kk) / SR
    depart = np.sin(2 * np.pi * 70 * tt) * np.exp(-tt * 22) + filtre(bruit(r, kk), lo=200, hi=3000) * np.exp(-tt * 50) * 0.6
    det = np.zeros(kk)
    k0 = mk(0.04)
    det[k0:] = (filtre(bruit(r, kk - k0), lo=100, hi=5000) * np.exp(-tt[:kk - k0] * 30)
                + np.sin(2 * np.pi * 50 * tt[:kk - k0]) * np.exp(-tt[:kk - k0] * 12) * 0.8)
    return (depart + det * 0.9) * force


def mono(y, sec=0.4, wet=0.12, graine=0, sombre=6000):
    """Une petite pièce autour du son, pour qu'il ne sonne pas « collé » ; la scène ajoute le reste."""
    return reverb_st(y, sec, wet, graine, sombre)


def pas_armure(i):
    """Un pas d'Astartes en armure : le poids (une masse sourde), le contact de la semelle de céramite,
    le cliquetis des plaques et le servo du genou qui se tend. 0,5 s."""
    r = nouveau_hasard(8000 + i)
    n = mk(0.5)
    t = np.arange(n) / SR
    poids = np.sin(2 * np.pi * r.uniform(48, 62) * t * (1 + 0.4 * np.exp(-t * 30))) * np.exp(-t * 18)
    contact = filtre(bruit(r, n), lo=200, hi=2500) * np.exp(-t * 55) * 0.6
    plaques = np.zeros(n)
    for _ in range(3):
        kk = mk(0.06)
        tt = np.arange(kk) / SR
        place(plaques, np.sin(2 * np.pi * r.uniform(1400, 2600) * tt) * np.exp(-tt * 90) * 0.12, r.uniform(0.02, 0.09))
    f = r.uniform(900, 1300) * (1 + 0.15 * np.clip((t - 0.05) / 0.2, 0, 1))
    servo = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.clip((t - 0.04) / 0.03, 0, 1) * np.exp(-np.maximum(t - 0.04, 0) * 9) * 0.05
    y = poids + contact + plaques + filtre(servo, lo=600, hi=3000)
    return mono(y, graine=8100 + i)


def pas_civil(i):
    """Un pas de mortel (Sefa, Ilse, serfs) : semelle de cuir sur métal ou pierre, sans poids. 0,25 s."""
    r = nouveau_hasard(8010 + i)
    n = mk(0.25)
    t = np.arange(n) / SR
    talon = filtre(bruit(r, n), lo=500, hi=5000) * np.exp(-t * 80) + np.sin(2 * np.pi * r.uniform(140, 200) * t) * np.exp(-t * 50) * 0.3
    semelle = np.zeros(n)
    place(semelle, filtre(bruit(r, mk(0.08)), lo=800, hi=4000) * np.hanning(mk(0.08)) * 0.25, 0.05)
    return mono((talon + semelle) * 0.6, graine=8110 + i)


def servo(i):
    """Le servo d'un geste (bras qui se lève, tête qui tourne) : un moteur fin qui monte puis se pose,
    et le frottement d'un joint. 0,4 à 0,6 s."""
    r = nouveau_hasard(8020 + i)
    d = r.uniform(0.4, 0.6)
    n = mk(d)
    t = np.arange(n) / SR
    f0 = r.uniform(700, 1100)
    f = f0 * (1 + 0.35 * np.sin(np.pi * t / d))
    y = (np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.4 * np.sin(2 * np.pi * np.cumsum(2.01 * f) / SR)) * np.sin(np.pi * t / d) ** 0.6
    y = filtre(y, lo=500, hi=3500) * 0.12 + filtre(bruit(r, n), lo=1500, hi=6000) * np.sin(np.pi * t / d) * 0.03
    return mono(y, graine=8120 + i)


def geste_armure(i):
    """Les plaques qui bougent dans un geste : deux ou trois chocs de céramite feutrés et un frottement
    de sous-combinaison. 0,4 s."""
    r = nouveau_hasard(8030 + i)
    n = mk(0.4)
    t = np.arange(n) / SR
    y = filtre(bruit(r, n), lo=300, hi=2500) * np.sin(np.pi * t / 0.4) ** 2 * 0.08
    for _ in range(int(r.integers(2, 4))):
        kk = mk(0.08)
        tt = np.arange(kk) / SR
        c = np.sin(2 * np.pi * r.uniform(600, 1500) * tt) * np.exp(-tt * 70) + filtre(bruit(r, kk), lo=800, hi=4000) * np.exp(-tt * 90) * 0.4
        place(y, c * r.uniform(0.15, 0.3), r.uniform(0.0, 0.3))
    return mono(y, graine=8130 + i)


def tir_laser(i):
    r = nouveau_hasard(8040 + i)
    y = np.zeros(mk(0.6))
    place(y, coup_de_feu(r, 0.9, laser=True), 0.0)
    return mono(y, 0.8, 0.25, 8140 + i)


def tir_projectile(i):
    r = nouveau_hasard(8050 + i)
    y = np.zeros(mk(0.6))
    place(y, coup_de_feu(r, 1.0), 0.0)
    kk = mk(0.08)                                                                      # la culasse
    tt = np.arange(kk) / SR
    place(y, np.sin(2 * np.pi * 2200 * tt) * np.exp(-tt * 100) * 0.1, 0.12)
    return mono(y, 0.8, 0.25, 8150 + i)


def tir_bolter(i):
    r = nouveau_hasard(8060 + i)
    y = np.zeros(mk(0.9))
    place(y, bolter(r, 1.0), 0.0)
    return mono(y, 1.0, 0.25, 8160 + i)


def fumee_boucle():
    """Fumée et débris qui brûlent : souffle sourd, crépitements, petites braises. Boucle de 4 s, à
    poser sous un effet de fumée et à régler en volume avec sa densité."""
    r = nouveau_hasard(8070)
    L = mk(4.0)
    n = L + mk(0.5)
    y = filtre(bruit(r, n), lo=80, hi=600) * 0.25 + filtre(bruit(r, n), lo=1200, hi=5000) * 0.02
    for _ in range(40):
        kk = mk(0.02)
        place(y, filtre(bruit(r, kk), lo=1000, hi=6000) * np.hanning(kk) * r.uniform(0.1, 0.4), r.uniform(0, 4.4))
    return boucler(mono(y, 0.5, 0.15, 8170), L, 0.4)


def bougie_boucle():
    """Une flamme de bougie, de près : un souffle qui vacille, une mèche qui grésille. Boucle de 3 s,
    très douce : elle ne doit s'entendre que dans le silence."""
    r = nouveau_hasard(8071)
    L = mk(3.0)
    n = L + mk(0.4)
    vac = np.abs(filtre(r.standard_normal(n), hi=6)) * 6
    y = filtre(bruit(r, n), lo=150, hi=900) * vac * 0.05
    for _ in range(8):
        kk = mk(0.03)
        place(y, filtre(bruit(r, kk), lo=1500, hi=6000) * np.hanning(kk) * r.uniform(0.05, 0.15), r.uniform(0, 3.3))
    return boucler(mono(y, 0.3, 0.1, 8171), L, 0.3)


def bougie_souffle():
    """Une bougie qu'on souffle (ou qu'un courant d'air éteint) : un souffle bref, la flamme qui claque,
    puis un filet de fumée. 1 s."""
    r = nouveau_hasard(8072)
    n = mk(1.0)
    t = np.arange(n) / SR
    souffle = filtre(bruit(r, n), lo=300, hi=3000) * np.clip(t / 0.03, 0, 1) * np.exp(-t * 12) * 0.5
    claque = np.zeros(n)
    place(claque, filtre(bruit(r, mk(0.02)), lo=200, hi=1500) * np.hanning(mk(0.02)) * 0.6, 0.08)
    filet = filtre(bruit(r, n), lo=2000, hi=7000) * np.clip((t - 0.15) / 0.1, 0, 1) * np.exp(-np.maximum(t - 0.15, 0) * 4) * 0.03
    return mono(souffle + claque + filet, graine=8172)


def vitre(i):
    """Une vitre qui éclate : le choc, l'éclat principal, puis la pluie d'éclats sur le sol. 1,5 s."""
    r = nouveau_hasard(8080 + i)
    n = mk(1.5)
    t = np.arange(n) / SR
    choc = filtre(bruit(r, n), lo=500, hi=8000) * np.exp(-t * 40) + np.sin(2 * np.pi * 120 * t) * np.exp(-t * 30) * 0.3
    eclats = np.zeros(n)
    for _ in range(70):
        kk = mk(0.15)
        tt = np.arange(kk) / SR
        c = sum(np.sin(2 * np.pi * r.uniform(2500, 8000) * tt + r.uniform(0, 6)) * np.exp(-tt * r.uniform(20, 45)) for _ in range(3))
        place(eclats, c * r.uniform(0.01, 0.05), abs(r.normal(0.25, 0.25)))
    return mono(choc * 0.8 + eclats, 0.6, 0.2, 8180 + i)


def vitre_fissure():
    """Une vitre qui se fend sans tomber : un craquement sec qui court sur la surface. 0,8 s."""
    r = nouveau_hasard(8085)
    n = mk(0.8)
    y = np.zeros(n)
    tc = 0.0
    for k in range(14):
        kk = mk(0.02)
        tt = np.arange(kk) / SR
        place(y, (filtre(bruit(r, kk), lo=2000, hi=9000) + np.sin(2 * np.pi * r.uniform(3000, 6000) * tt)) * np.exp(-tt * 200) * (1 - k / 16) * 0.5, tc)
        tc += r.uniform(0.01, 0.05)
    return mono(y, 0.5, 0.2, 8185)


if __name__ == "__main__":
    for i in range(6):
        sauver(f"sfx_pas_armure_{i + 1:02d}", pas_armure(i), crete=0.7)
    for i in range(4):
        sauver(f"sfx_pas_civil_{i + 1:02d}", pas_civil(i), crete=0.5)
    for i in range(4):
        sauver(f"sfx_servo_{i + 1:02d}", servo(i), crete=0.4)
    for i in range(4):
        sauver(f"sfx_geste_armure_{i + 1:02d}", geste_armure(i), crete=0.5)
    for i in range(3):
        sauver(f"sfx_tir_laser_{i + 1:02d}", tir_laser(i), crete=0.8)
        sauver(f"sfx_tir_projectile_{i + 1:02d}", tir_projectile(i), crete=0.8)
        sauver(f"sfx_tir_bolter_{i + 1:02d}", tir_bolter(i), crete=0.89)
    sauver("sfx_fumee_boucle", fumee_boucle(), crete=0.5, finir=False)
    sauver("sfx_bougie_boucle", bougie_boucle(), crete=0.3, finir=False)
    sauver("sfx_bougie_souffle", bougie_souffle(), crete=0.5)
    for i in range(2):
        sauver(f"sfx_vitre_{i + 1:02d}", vitre(i), crete=0.8)
    sauver("sfx_vitre_fissure", vitre_fissure(), crete=0.6)
