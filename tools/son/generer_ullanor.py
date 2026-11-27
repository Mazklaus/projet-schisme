#!/usr/bin/env python3
"""Son de la tranche verticale d'Ullanor : ambiances, musique et bruitages, tout en synthèse.

Aucun fichier tiers, aucune voix : chaque son est calculé ici, à graine fixe (même entrée, même
sortie). Ton (brief du GD, 18/11) : grandeur impériale, orgue, chœurs graves, cuivres lourds,
jamais héroïque-pop. Traçabilité : assets/audio/SOURCES.md.

Usage : python3 tools/son/generer_ullanor.py <dossier_wav>   (puis encoder_ogg.py)
"""
import os
import sys

import numpy as np
import scipy.io.wavfile as wf

SR = 44100
OUT = sys.argv[1] if len(sys.argv) > 1 else "wav"
os.makedirs(OUT, exist_ok=True)
D2 = 73.42  # ré grave : la tonalité de la tranche (ré mineur, couleur modale)


def mk(s):
    return int(round(s * SR))


def nouveau_hasard(graine):
    return np.random.default_rng(graine)


def filtre(x, lo=None, hi=None, ordre=2):
    """Passe-bande doux dans le domaine fréquentiel (pente en 6·ordre dB/oct)."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    g = np.ones_like(f)
    if hi:
        g /= np.sqrt(1 + (f / hi) ** (2 * ordre))
    if lo:
        g /= np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** (2 * ordre))
    return np.fft.irfft(X * g, len(x))


def formants(x, F, largeurs, gains):
    """Filtre de formants (bosses gaussiennes) : voyelles des chœurs et de la foule, sans mots."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    g = np.zeros_like(f)
    for fc, bw, a in zip(F, largeurs, gains):
        g += a * np.exp(-((f - fc) / bw) ** 2)
    return np.fft.irfft(X * g, len(x))


VOYELLES = {  # formants (Hz), voix d'hommes graves
    "o": ((400, 750, 2400), (140, 180, 300), (1.0, 0.6, 0.25)),
    "u": ((320, 650, 2300), (120, 160, 300), (1.0, 0.45, 0.18)),
    "a": ((650, 1080, 2500), (160, 190, 320), (1.0, 0.7, 0.3)),
    "e": ((480, 1650, 2500), (140, 220, 320), (1.0, 0.5, 0.3)),
}


def bruit(r, n, lo=None, hi=None):
    return filtre(r.standard_normal(n), lo=lo, hi=hi)


def env_ar(n, a, rel):
    e = np.ones(n)
    a = max(1, min(n, mk(a)))
    rel = max(1, min(n, mk(rel)))
    e[:a] = np.linspace(0, 1, a)
    e[-rel:] *= np.linspace(1, 0, rel)
    return e


def place(buf, ev, t):
    p = mk(t)
    if p < 0:
        ev = ev[-p:]
        p = 0
    n = min(len(ev), len(buf) - p)
    if n > 0:
        buf[p:p + n] += ev[:n]


def reverb(x, sec, wet, graine, sombre=4000):
    r = nouveau_hasard(graine)
    n = mk(sec)
    L = len(x) + n
    ir = r.standard_normal(n) * np.exp(-6.9 * np.arange(n) / n)
    ir = filtre(np.pad(ir, (0, L - n)), hi=sombre)
    y = np.fft.irfft(np.fft.rfft(np.pad(x, (0, n))) * np.fft.rfft(ir), L)
    y *= np.std(x) / (np.std(y) + 1e-12)
    return (1 - wet) * np.pad(x, (0, n)) + wet * y


def reverb_st(x, sec, wet, graine, sombre=4000):
    return np.stack([reverb(x, sec, wet, graine, sombre), reverb(x, sec, wet, graine + 1, sombre)], 1)


def boucler(x, n, fondu):
    """Rend une boucle sans couture : la queue (au-delà de n) est fondue dans la tête."""
    y = x[:n].copy()
    q = x[n:n + mk(fondu)]
    k = len(q)
    if k:
        w = np.linspace(1, 0, k)
        w = w[:, None] if y.ndim == 2 else w
        y[:k] = y[:k] * (1 - w) + q * w
    return y


def normaliser(x, crete=None, rms_db=None):
    if rms_db is not None:
        x = x * (10 ** (rms_db / 20) / (np.sqrt(np.mean(x ** 2)) + 1e-12))
    if crete is not None:
        m = np.abs(x).max() + 1e-12
        if m > crete or rms_db is None:
            x = x * (crete / m)
    return x


def sauver(nom, x, crete=None, rms_db=None, finir=True):
    x = normaliser(np.asarray(x, dtype=float), crete, rms_db)
    if finir:
        f = mk(0.01)
        x[-f:] *= np.linspace(1, 0, f)[:, None] if x.ndim == 2 else np.linspace(1, 0, f)
    wf.write(os.path.join(OUT, nom + ".wav"), SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
    print(nom, f"{len(x) / SR:.1f} s")


# ============================================================================ instruments

def orgue(r, f, dur, force=1.0, jeux=((0.5, 0.5), (1, 1.0), (2, 0.5), (3, 0.25), (4, 0.3), (6, 0.1), (8, 0.12))):
    """Grand orgue : jeux de fonds (16', 8', 4'…), deux rangs un peu désaccordés, souffle d'attaque."""
    n = mk(dur)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for mult, a in jeux:
        for det in (1.0, 1.0012):
            y += a * np.sin(2 * np.pi * f * mult * det * t + r.uniform(0, 6.3))
    k = mk(0.06)
    y[:k] += bruit(r, k, lo=f * 2, hi=f * 12) * np.linspace(1, 0, k) * 0.6  # le « chiff » du tuyau
    y *= 0.35 / (np.sqrt(np.mean(y ** 2)) + 1e-12)                                    # niveaux comparables d'un instrument à l'autre
    return y * env_ar(n, 0.09, 0.35) * force


def choeur(r, f, dur, voyelle="o", voix=6, force=1.0, attaque=0.7):
    """Chœur grave bouche ouverte (voyelle tenue, aucun mot) : dents de scie détimbrées par formants."""
    n = mk(dur)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for _ in range(voix):
        det = 2 ** (r.uniform(-9, 9) / 1200)
        vib = 1 + 0.005 * np.sin(2 * np.pi * r.uniform(4.6, 5.6) * t + r.uniform(0, 6.3)) * np.clip(t / 0.8, 0, 1)
        ph = np.cumsum(f * det * vib) / SR + r.uniform(0, 1)
        y += 2 * (ph % 1) - 1
    F, B, G = VOYELLES[voyelle]
    y = formants(y + bruit(r, n) * 0.05, F, B, G)
    y *= 0.35 / (np.sqrt(np.mean(y ** 2)) + 1e-12)
    return y * env_ar(n, attaque, 1.0) * force


def cuivre(r, f, dur, force=1.0, attaque=0.35):
    """Cuivres lourds (trombones, tubas) : le timbre s'ouvre avec le souffle (sombre → cuivré)."""
    n = mk(dur)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for det in (1.0, 1.003, 0.997):
        ph = np.cumsum(f * det * (1 + 0.002 * np.sin(2 * np.pi * 5 * t))) / SR + r.uniform(0, 1)
        y += 2 * (ph % 1) - 1
    e = env_ar(n, attaque, 0.5)
    sombre = filtre(y, hi=f * 2.5, ordre=2)
    clair = filtre(y, hi=f * 9, ordre=2)
    ouverture = np.clip(e * 1.15, 0, 1) ** 1.5
    y = sombre * (1 - ouverture) + clair * ouverture
    y *= 0.35 / (np.sqrt(np.mean(y ** 2)) + 1e-12)
    return y * e * force


def timbale(r, f, force=1.0):
    n = mk(2.5)
    t = np.arange(n) / SR
    y = np.sin(2 * np.pi * f * t * (1 + 0.08 * np.exp(-t * 20))) * np.exp(-t * 1.8)
    y += np.sin(2 * np.pi * f * 1.5 * t) * np.exp(-t * 3) * 0.3
    y += bruit(r, n, lo=80, hi=1500) * np.exp(-t * 40) * 0.5
    return y * force


def tambour_guerre(r, force=1.0):
    """Gros tambour de défilé : peau grave qui descend, coup de mailloche."""
    n = mk(1.6)
    t = np.arange(n) / SR
    f = 55 * (1 + 0.5 * np.exp(-t * 18))
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 4)
    y += bruit(r, n, lo=60, hi=900) * np.exp(-t * 30) * 0.6
    return y * force


ACCORDS = {  # demi-tons depuis ré
    "Dm": (0, 3, 7), "Bb": (-4, 0, 5), "F": (3, 7, 10), "C": (-2, 2, 5), "Gm": (-7, -2, 2),
    "A": (-5, -1, 2), "Eb/D": (0, 1, 5), "Gm/D": (0, 5, 8), "Bb/D": (0, 4, 8),
    "D": (0, 4, 7), "G": (-7, -3, 0), "Bm": (-3, 0, 4), "Asus4": (-5, 0, 2),
}
BASSES = {"Dm": 0, "Bb": -4, "F": 3, "C": -2, "Gm": -7, "A": -5, "Eb/D": 0, "Gm/D": 0, "Bb/D": 0,
          "D": 0, "G": -7, "Bm": -3, "Asus4": -5}
ORGUE_PLEIN = ((0.5, 0.45), (1, 1.0), (2, 0.6), (3, 0.35), (4, 0.4), (5, 0.12), (6, 0.2), (8, 0.22), (12, 0.08), (16, 0.06))


def note(demi, base=D2):
    return base * 2 ** (demi / 12)


# ============================================================================ musique

def mus_triomphe():
    """Le Triomphe : l'apogée de l'Imperium, grandeur sincère et lumineuse (retours du GD, 18 et 27/11).
    Il entre sur 1b et doit tenir à plein jusqu'à 1d (environ 10,5 s). La première phrase monte
    jusqu'à la tonique en 7,5 s, exactement la durée de 1b : l'accord de ré se pose avec « Maître de
    Guerre ! » (1c) et tient jusqu'à 1d. Ré majeur, 48 à la noire, deux temps par accord :
    I – IV – V4-3 – I, puis vi – IV – V4-3 – I. Plein jeu d'orgue, chœur, cuivres larges, la ligne
    au chœur et à la trompette douce. Ni batterie ni montée pop."""
    r = nouveau_hasard(1001)
    noire = 60 / 48
    pas = 2 * noire                                                                   # 2,5 s par accord
    # (accord, durée en accords, ligne de chant : (demi-tons depuis ré 4, durée en accords))
    phrase = [("D", 1, [(4, 1)]), ("G", 1, [(9, 1)]), ("Asus4", 0.5, [(12, 0.5)]), ("A", 0.5, [(11, 0.5)]),
              ("D", 2, [(12, 2)]),
              ("Bm", 1, [(4, 1)]), ("G", 1, [(5, 1)]), ("Asus4", 0.5, [(7, 0.5)]), ("A", 0.5, [(11, 0.5)]),
              ("D", 2, [(12, 2)])]
    L = mk(pas * sum(d for _, d, _ in phrase))
    m = np.zeros(L + mk(8))
    t0 = 0.0
    for k, (a, d, chant) in enumerate(phrase):
        da = d * pas
        # Le dernier accord déborde sur la queue : le fondu de boucle enchaîne ré plein sur ré plein, et la
        # toute première lecture (entrée sur 1b) commence à plein au lieu de sortir d'une réverbération.
        tenue = da + (4.5 if k == len(phrase) - 1 else 0.0)
        att = 0.12 if k == 0 else min(0.6, da * 0.3)
        place(m, orgue(r, note(BASSES[a], D2), tenue + 0.2, 0.5), t0)                  # pédale
        for x in ACCORDS[a]:
            place(m, orgue(r, note(x, D2 * 2), tenue + 0.2, 0.34, ORGUE_PLEIN), t0)
            place(m, choeur(r, note(x, D2 * 2), tenue + 0.6, "a" if a == "D" else "o", force=0.75,
                            attaque=0.15 if k == 0 else 0.4), t0)
            place(m, cuivre(r, note(x, D2 * 2), tenue * 0.97, 0.45, attaque=att), t0)
        place(m, cuivre(r, note(BASSES[a], D2), tenue * 0.97, 0.5, attaque=att), t0)
        tc = t0
        for x, dc in chant:
            dur = dc * pas
            place(m, choeur(r, note(x, D2 * 4), dur + 0.5, "a", voix=8, force=0.6, attaque=0.3), tc)
            place(m, cuivre(r, note(x, D2 * 4), dur * 0.97, 0.28, attaque=0.25), tc)
            tc += dur
        if a == "D":
            place(m, timbale(r, D2, 0.9 if d > 1 else 0.7), t0)
        if a == "Asus4":
            for q in range(8):                                                          # roulement vers la résolution
                place(m, timbale(r, note(-5, D2), 0.2 + 0.06 * q), t0 + q * da / 8)
        t0 += da
    st = reverb_st(m, 4.5, 0.42, 1101, sombre=9000)
    return boucler(st, L, 1.0)


def mus_attente():
    """Après la clameur : ce qui inquiète. Bourdon d'orgue ré–la, chœur rare et voilé, une couleur
    napolitaine (mi bémol) qui ne se résout pas. Boucle de 30 s."""
    r = nouveau_hasard(1002)
    L = mk(30.0)
    m = np.zeros(L + mk(8))
    place(m, orgue(r, D2, 31.0, 0.4, jeux=((0.5, 0.3), (1, 1.0), (2, 0.5), (3, 0.15))), 0)
    place(m, orgue(r, note(7, D2), 31.0, 0.25, jeux=((1, 1.0), (2, 0.4))), 0)
    for i, a in enumerate(["Dm", "Bb/D", "Gm/D", "Eb/D"]):
        for d in ACCORDS[a]:
            place(m, choeur(r, note(d, D2 * 2), 8.5, "u", voix=5, force=0.55, attaque=2.0), i * 7.5)
    st = reverb_st(m, 5.0, 0.55, 1102, sombre=4000)
    return boucler(st, L, 5.0)


def mus_horus():
    """Le gros plan d'Horus : une note tenue. Ré à l'unisson et à l'octave (orgue, chœur, cuivre
    grave), sans mélodie ; seule la lumière du chœur respire. Boucle de 20 s, fondu d'entrée par le jeu."""
    r = nouveau_hasard(1003)
    L = mk(20.0)
    m = np.zeros(L + mk(8))
    place(m, orgue(r, D2, 22.0, 0.45), 0)
    place(m, orgue(r, D2 * 2, 22.0, 0.35), 0)
    place(m, cuivre(r, D2, 22.0, 0.5, attaque=0.5), 0)
    t = np.arange(mk(22.0)) / SR
    for f, v in ((D2 * 2, "u"), (D2 * 4, "o")):
        c = choeur(r, f, 22.0, v, voix=8, force=0.8, attaque=0.5)
        place(m, c * (0.75 + 0.25 * np.sin(2 * np.pi * t / 10.0)), 0)                  # période de 10 s : boucle juste
    st = reverb_st(m, 5.0, 0.5, 1103, sombre=5000)
    return boucler(st, L, 2.0)


# ============================================================================ ambiances

def amb_triomphe():
    """1a : la plaine du Triomphe. Tambours lointains, des millions de pas, le métal des armures, le vent."""
    r = nouveau_hasard(2001)
    L = mk(40.0)
    n = L + mk(6)
    t = np.arange(n) / SR
    pas_hz = 60 / 48 * 2                                                              # deux pas par temps
    masse = bruit(r, n, lo=30, hi=220) * (0.7 + 0.3 * np.sin(2 * np.pi * pas_hz * t) ** 2)
    sol = bruit(r, n, lo=200, hi=1200) * (0.6 + 0.4 * np.abs(np.sin(np.pi * pas_hz * t))) * 0.25
    armures = bruit(r, n, lo=2500, hi=7000) * (0.5 + 0.5 * np.abs(np.sin(np.pi * pas_hz * t + 0.6))) * 0.06
    tambours = np.zeros(n)
    noire = 60 / 48
    for k in range(int(n / SR / noire)):
        f = 1.0 if k % 4 == 0 else 0.55
        place(tambours, tambour_guerre(r, f), k * noire + r.normal(0, 0.01))
        place(tambours, tambour_guerre(r, f * 0.6), k * noire + 0.09)                   # l'écho d'une autre colonne
    tambours = filtre(tambours, hi=700)
    vent = bruit(r, n, lo=200, hi=2500) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.07 * t)) * 0.15
    m = masse * 0.9 + sol + armures + vent
    st = reverb_st(m, 2.5, 0.3, 2101)[:n] + reverb_st(tambours, 4.0, 0.6, 2111, sombre=1500)[:n] * 0.9
    return boucler(st, L, 4.0)


def amb_vent():
    """La plaine sans foule : le vent, la poussière qui file sur le granit. Sert au silence brutal et aux fins."""
    r = nouveau_hasard(2002)
    L = mk(30.0)
    n = L + mk(4)
    t = np.arange(n) / SR
    rafales = 0.55 + 0.45 * np.sin(2 * np.pi * 0.05 * t + 1) * np.sin(2 * np.pi * 0.13 * t)
    vent = bruit(r, n, lo=150, hi=1800) * rafales * 0.4 + bruit(r, n, lo=40, hi=150) * 0.25
    poussiere = bruit(r, n, lo=3000, hi=9000) * rafales ** 2 * 0.05
    sifflement = formants(r.standard_normal(n), (820,), (12,), (1.0,)) * rafales ** 3 * 0.25
    m = vent + poussiere + sifflement
    st = np.stack([m, np.roll(m, mk(0.37)) * 0.95 + bruit(r, n, lo=150, hi=1800) * rafales * 0.08], 1)
    return boucler(st, L, 3.0)


def amb_bivouac():
    """Le champ après la fête : vent et poussière, feux de camp, outils sur le métal au loin, un moteur
    au ralenti, un tambour isolé très loin. Aucune voix (pas de murmures de foule)."""
    r = nouveau_hasard(2003)
    L = mk(60.0)
    n = L + mk(5)
    t = np.arange(n) / SR
    rafales = 0.6 + 0.4 * np.sin(2 * np.pi * 0.04 * t) * np.sin(2 * np.pi * 0.11 * t + 2)
    vent = bruit(r, n, lo=150, hi=1500) * rafales * 0.3 + bruit(r, n, lo=3000, hi=8000) * rafales ** 2 * 0.03
    feu = bruit(r, n, lo=200, hi=900) * 0.05
    for _ in range(900):                                                              # braises qui claquent
        k = mk(r.uniform(0.002, 0.008))
        place(feu, bruit(r, k + 64, lo=1500, hi=7000)[:k] * np.hanning(k) * r.uniform(0.05, 0.4), r.uniform(0, n / SR))
    metal = np.zeros(n)
    tc = 1.0
    while tc < n / SR - 1:                                                            # quelqu'un répare une chenille
        for c in range(int(r.integers(2, 5))):
            k = mk(0.6)
            tt = np.arange(k) / SR
            f0 = r.uniform(900, 1600)
            coup = sum(a * np.sin(2 * np.pi * f0 * m_ * tt) * np.exp(-tt * (12 + 8 * m_)) for m_, a in ((1, 1), (2.76, 0.5), (5.4, 0.25)))
            place(metal, coup * 0.12, tc + c * r.uniform(0.35, 0.5))
        tc += r.uniform(4.0, 8.0)
    metal = filtre(metal, hi=3500)
    moteur = sum(a * np.sin(2 * np.pi * 31.5 * h * t + r.uniform(0, 6)) for h, a in ((1, 1), (2, 0.6), (3, 0.4), (4, 0.25), (6, 0.1)))
    moteur = moteur * (0.8 + 0.2 * np.sin(2 * np.pi * 7.9 * t)) * 0.05                # le Rhino au ralenti, loin
    tambour = np.zeros(n)
    for tc in (14.0, 15.25, 16.5, 44.0, 45.25):
        place(tambour, tambour_guerre(r, 0.25), tc)
    tambour = filtre(tambour, hi=400)
    m = vent + feu + moteur
    st = np.stack([m + metal * 0.8, m * 0.97 + metal * 0.5], 1)
    st = st[:n] + reverb_st(tambour, 4.0, 0.8, 2113, sombre=1200)[:n]
    st = st + np.stack([reverb(metal, 2.0, 1.0, 2121)[:n], reverb(metal, 2.0, 1.0, 2122)[:n]], 1) * 0.3
    return boucler(st, L, 4.0)


def amb_nef():
    """La nef impériale (décor test du Tools Programmer, pour les épisodes suivants) : une pierre immense
    et froide. L'air qui bouge à peine, le grondement des machines du palais sous le dallage, un courant
    d'air dans les bannières, de lourds pas lointains qui roulent sous les voûtes, une porte de bronze
    très loin, et un chant grave à peine audible, des salles plus loin. 60 s, réverbération de 8 s."""
    r = nouveau_hasard(2004)
    L = mk(60.0)
    n = L + mk(9)
    t = np.arange(n) / SR
    air = bruit(r, n, lo=25, hi=180) * 0.5 + bruit(r, n, lo=200, hi=1200) * 0.06
    machines = (np.sin(2 * np.pi * 41 * t) + 0.5 * np.sin(2 * np.pi * 82.3 * t) + 0.2 * np.sin(2 * np.pi * 123 * t))
    machines *= 0.12 * (0.85 + 0.15 * np.sin(2 * np.pi * t / 15.0))                    # période 15 s : boucle juste
    courant = (0.5 + 0.5 * np.sin(2 * np.pi * t / 20.0 + 0.7)) ** 3                     # période 20 s
    bannieres = filtre(bruit(r, n), lo=700, hi=3000) * courant * 0.03
    for _ in range(14):                                                                # le tissu qui claque doucement
        k = mk(0.5)
        tt = np.arange(k) / SR
        c = filtre(bruit(r, k), lo=500, hi=3000) * np.hanning(k) * np.exp(-tt * 4)
        place(bannieres, c * 0.15, r.uniform(0, 60.0))
    lointain = np.zeros(n)                                                             # ce qui ne sonne que par la voûte
    tp = 2.0
    while tp < 56.0:                                                                   # pas lourds, par marches de 8 à 14
        for _ in range(int(r.integers(8, 15))):
            k = mk(0.25)
            tt = np.arange(k) / SR
            pas = np.sin(2 * np.pi * r.uniform(60, 80) * tt) * np.exp(-tt * 25)
            pas += filtre(bruit(r, k), lo=300, hi=2500) * np.exp(-tt * 70) * 0.5         # la céramite sur la pierre
            place(lointain, pas * r.uniform(0.5, 0.8), tp)
            tp += r.uniform(0.62, 0.72)
        tp += r.uniform(6, 14)
    for t0 in (23.0, 47.5):                                                            # une porte de bronze, très loin
        k = mk(2.5)
        tt = np.arange(k) / SR
        porte = np.sin(2 * np.pi * 38 * tt) * np.exp(-tt * 3) + filtre(bruit(r, k), lo=60, hi=600) * np.exp(-tt * 8) * 0.6
        place(lointain, porte * 0.8, t0)
    lointain = filtre(lointain, hi=1800)
    chant = np.zeros(n)                                                                # chant grave des salles voisines
    for t0, d in ((0.0, 0), (15.0, 5), (30.0, -2), (45.0, 0)):
        for f in (note(d, D2), note(d + 7, D2)):
            place(chant, choeur(r, f, 17.0, "u", voix=5, force=1.0, attaque=4.0), t0)
    chant = filtre(chant, hi=700) * 0.05
    m = air + machines + bannieres + chant
    st = reverb_st(m, 3.0, 0.5, 2141, sombre=2500)[:n] + reverb_st(lointain, 8.0, 0.9, 2143, sombre=2200)[:n]
    return boucler(st, L, 8.0)


# ============================================================================ bruitages

def foule(r, dur, voix_hz=(95, 240), groupes=28, voyelle="a"):
    """Une foule immense, sans un mot : des milliers de souffles voisés détimbrés en voyelle ouverte."""
    n = mk(dur)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for _ in range(groupes):
        g = np.zeros(n)
        for _ in range(10):
            f0 = r.uniform(*voix_hz) * (1 + 0.04 * np.sin(2 * np.pi * r.uniform(0.2, 0.8) * t + r.uniform(0, 6)))
            ph = np.cumsum(f0) / SR + r.uniform(0, 1)
            g += (2 * (ph % 1) - 1) * r.uniform(0.5, 1)
        F, B, G = VOYELLES[voyelle]
        F = tuple(f * r.uniform(0.92, 1.08) for f in F)
        y += formants(g, F, tuple(b * 2.5 for b in B), G) * r.uniform(0.5, 1)
    return y / groupes + bruit(r, n, lo=250, hi=3500) * 0.08


def sfx_clameur_maitre():
    """1c : la plaine entière exulte (retour du GD, 18/11) : explosion en 0,5 s, puis des vagues de
    joie qui repartent, armes levées. À 1d (environ 3 s plus tard), l'Empereur se détourne : la
    clameur retombe, inquiète, les voix descendent et il reste une rumeur basse qui s'éteint. 13 s."""
    r = nouveau_hasard(3001)
    D = 13.0
    BASCULE = 3.2                                                                      # passage de 1c à 1d
    n = mk(D)
    t = np.arange(n) / SR
    vagues = 1 + 0.18 * np.exp(-((t - 1.6) / 0.35) ** 2) + 0.14 * np.exp(-((t - 2.6) / 0.3) ** 2)
    env = np.clip(t / 0.5, 0, 1) ** 1.5 * vagues * np.where(t < BASCULE, 1.0, np.exp(-(t - BASCULE) * 0.6))
    joie = foule(r, D, (125, 310), 30, "a")
    # la bascule : le haut de la foule s'efface plus vite que le grave, la clameur « tombe »
    clair = filtre(joie, lo=900)
    joie = joie - clair * np.clip((t - BASCULE) / 1.5, 0, 1)
    rumeur = np.clip((t - BASCULE + 0.5) / 2.0, 0, 1) * np.clip((D - t) / 4.0, 0, 1)
    y = joie * env + foule(r, D, (80, 150), 12, "u") * rumeur * 0.16
    armes = np.zeros(n)                                                                # armes et étendards levés
    for _ in range(260):
        k = mk(0.08)
        tt = np.arange(k) / SR
        c = (np.sin(2 * np.pi * r.uniform(600, 1800) * tt) * 0.5 + bruit(r, k, lo=1200, hi=7000)) * np.exp(-tt * 60)
        place(armes, c * r.uniform(0.2, 1), r.uniform(0.2, BASCULE))
    y += armes / (np.abs(armes).max() + 1e-9) * 0.12 * np.abs(y).max()
    y += bruit(r, n, lo=30, hi=200) * env * 0.6                                       # le sol qui tremble
    return reverb_st(y, 3.0, 0.4, 3101, sombre=4500)


def sfx_clameur_lupercal():
    """5d : la Légion scande son primarque en trois temps, LU-PER-CAL (retour du GD, 18/11) : trois
    frappes de milliers de poings sur les plastrons, chacune avec un cri de gorge. Trois voyelles
    (u, e, a) donnent le rythme du nom sans articuler de syllabes ; le troisième cri tient et s'éteint
    en grondement. 9 s."""
    r = nouveau_hasard(3002)
    D = 9.0
    n = mk(D)
    t = np.arange(n) / SR
    TEMPS = ((0.0, "u", 0.38, 1.0), (0.62, "e", 0.38, 0.92), (1.24, "a", 1.6, 1.0))   # début, voyelle, tenue, force
    coups = np.zeros(n)
    cris = np.zeros(n)
    for t0, voy, tenue, g in TEMPS:
        for _ in range(400):                                                          # céramite contre céramite
            k = mk(0.12)
            tt = np.arange(k) / SR
            f0 = r.uniform(350, 900)
            c = (np.sin(2 * np.pi * f0 * tt) * 0.6 + bruit(r, k, lo=500, hi=5000)) * np.exp(-tt * 45)
            place(coups, c * r.uniform(0.4, 1) * g, t0 + abs(r.normal(0, 0.022)))
        k = mk(0.6)
        tt = np.arange(k) / SR
        place(coups, np.sin(2 * np.pi * 48 * tt) * np.exp(-tt * 7) * 60 * g, t0)        # le poids de la masse
        dc = tenue + (3.0 if voy == "a" else 0.35)
        cri = foule(r, dc, (80, 135), 18, voy)
        tc = np.arange(len(cri)) / SR
        if voy == "a":
            ec = np.clip(tc / 0.06, 0, 1) * np.where(tc < tenue, 1.0, np.exp(-(tc - tenue) * 1.1))
        else:
            ec = np.clip(tc / 0.05, 0, 1) * np.clip((tenue + 0.12 - tc) / 0.12, 0, 1)
        place(cris, cri / (np.abs(cri).max() + 1e-9) * ec * g, t0 + 0.03)
    y = coups / (np.abs(coups).max() + 1e-9) * 0.9 + cris / (np.abs(cris).max() + 1e-9) * 0.85
    y += bruit(r, n, lo=30, hi=180) * np.abs(filtre(cris, hi=8)) * 2.0                  # le sol sous la Légion
    return reverb_st(y, 3.5, 0.4, 3102, sombre=3200)


def sfx_vox_crepite(i):
    """Le vox de Dremm s'ouvre : un claquement de micro, un souffle de parasites en bande étroite. 0,5 s."""
    r = nouveau_hasard(3010 + i)
    n = mk(0.5)
    t = np.arange(n) / SR
    y = bruit(r, n, lo=400, hi=3200, ) * np.exp(-t * 6) * 0.35
    for _ in range(25 + 10 * i):                                                      # grésillements
        k = mk(r.uniform(0.001, 0.004))
        place(y, r.standard_normal(k) * r.uniform(0.3, 1), r.uniform(0.02, 0.45))
    k = mk(0.012)
    place(y, np.hanning(k) * 1.2, 0.0)                                                # le clic du bouton
    return filtre(y, lo=300, hi=3400, ordre=3) * env_ar(n, 0.002, 0.08)


def sfx_eboulement():
    """3 : la carcasse ork cède. Le métal hurle (0 à 0,9 s), le choc, les débris, puis le silence où
    la poussière retombe. 6 s."""
    r = nouveau_hasard(3020)
    D = 6.0
    n = mk(D)
    t = np.arange(n) / SR
    cri = np.zeros(n)
    k = mk(1.3)
    tt = np.arange(k) / SR
    for f0, a in ((420, 1.0), (687, 0.6), (1130, 0.45), (1890, 0.3), (2710, 0.2)):     # partiels inharmoniques qui plient
        f = f0 * (1 - 0.25 * (tt / tt[-1]) ** 1.5) * (1 + 0.015 * np.sin(2 * np.pi * r.uniform(9, 17) * tt))
        cri[:k] += a * np.sin(2 * np.pi * np.cumsum(f) / SR) * (tt / tt[-1]) ** 0.7
    frottement = bruit(r, k, lo=600, hi=4000) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 37 * tt)))
    cri[:k] += frottement * (tt / tt[-1]) * 0.5
    cri[:k] *= np.clip((1.05 - tt) / 0.15, 0, 1)
    choc = np.zeros(n)
    k = mk(1.5)
    tt = np.arange(k) / SR
    place(choc, (np.sin(2 * np.pi * 42 * tt) * 2 + bruit(r, k, hi=300) * 2) * np.exp(-tt * 3.5), 0.92)
    place(choc, bruit(r, k, lo=200, hi=6000) * np.exp(-tt * 6) * 1.2, 0.92)
    for _ in range(40):                                                               # tôles et boulons qui retombent
        k2 = mk(0.4)
        t2 = np.arange(k2) / SR
        f0 = r.uniform(300, 2500)
        c = sum(a * np.sin(2 * np.pi * f0 * m_ * t2) for m_, a in ((1, 1), (2.4, 0.5), (4.1, 0.2))) * np.exp(-t2 * r.uniform(15, 40))
        place(choc, c * r.uniform(0.1, 0.5) * np.exp(-r.uniform(0, 1.5)), 0.95 + r.exponential(0.5))
    poussiere = bruit(r, n, lo=1500, hi=7000) * np.clip((t - 0.9) / 0.2, 0, 1) * np.exp(-np.maximum(t - 1.2, 0) * 1.2) * 0.25
    y = cri * 0.5 + choc + poussiere
    return reverb_st(y, 2.5, 0.3, 3121)


def sfx_poutre_grince():
    """La QTE : la poutre (acier ork) tenue à bout de bras. Grincement en saccades, boucle de 2 s ;
    le jeu règle volume et hauteur sur la jauge."""
    r = nouveau_hasard(3030)
    L = mk(2.0)
    n = L + mk(0.3)
    t = np.arange(n) / SR
    y = np.zeros(n)
    tc = 0.0
    while tc < n / SR:                                                                # collé-glissé
        k = mk(r.uniform(0.004, 0.012))
        place(y, np.hanning(k) * r.uniform(0.5, 1), tc)
        tc += 1 / (45 + 20 * np.sin(2 * np.pi * tc / 2.0)) * r.uniform(0.8, 1.2)
    y = formants(y, (310, 760, 1450), (40, 60, 90), (1.0, 0.7, 0.4)) + bruit(r, n, lo=80, hi=300) * 0.2
    y *= 0.7 + 0.3 * np.sin(2 * np.pi * t / 1.0) ** 2                                 # période 1 s : boucle juste
    return boucler(np.stack([y, y], 1), L, 0.3)


def sfx_choix_tic():
    """Le tic sourd du choix minuté : un coup de bois feutré sur une note grave. 0,3 s."""
    r = nouveau_hasard(3040)
    n = mk(0.3)
    t = np.arange(n) / SR
    y = np.sin(2 * np.pi * 110 * t) * np.exp(-t * 22) + bruit(r, n, lo=300, hi=1800) * np.exp(-t * 90) * 0.4
    return np.stack([y, y], 1)


def sfx_choix_battement(i):
    """Le battement du choix minuté (décision QA v1) : un coup sourd, comme un cœur sous l'armure,
    que la boîte rapproche de 1 s à 0,35 s. Assez court (0,3 s) pour ne jamais se chevaucher."""
    r = nouveau_hasard(3050 + i)
    n = mk(0.3)
    t = np.arange(n) / SR
    f = (52, 58)[i] * (1 + 0.35 * np.exp(-t * 30))
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 14) * np.clip(t / 0.004, 0, 1)
    y += filtre(bruit(r, n), lo=80, hi=400) * np.exp(-t * 60) * 0.35                    # le feutre de la mailloche
    y = np.tanh(y * 1.4)
    return np.stack([y, y], 1)


# ============================================================================ sortie

if __name__ == "__main__":
    sauver("mus_ullanor_triomphe", mus_triomphe(), crete=0.7, rms_db=-19, finir=False)
    sauver("mus_ullanor_attente", mus_attente(), crete=0.6, rms_db=-24, finir=False)
    sauver("mus_ullanor_horus", mus_horus(), crete=0.7, rms_db=-20, finir=False)
    sauver("amb_ullanor_triomphe", amb_triomphe(), crete=0.8, rms_db=-20, finir=False)
    sauver("amb_ullanor_vent", amb_vent(), crete=0.6, rms_db=-27, finir=False)
    sauver("amb_ullanor_bivouac", amb_bivouac(), crete=0.6, rms_db=-26, finir=False)
    sauver("sfx_clameur_maitre", sfx_clameur_maitre(), crete=0.89)
    sauver("sfx_clameur_lupercal", sfx_clameur_lupercal(), crete=0.89)
    for i in range(3):
        sauver(f"sfx_vox_crepite_{i + 1:02d}", sfx_vox_crepite(i), crete=0.5)
    sauver("sfx_eboulement", sfx_eboulement(), crete=0.89)
    sauver("sfx_poutre_grince", sfx_poutre_grince(), crete=0.5, finir=False)
    sauver("sfx_choix_tic", sfx_choix_tic(), crete=0.5)
    for i in range(2):
        sauver(f"sfx_choix_battement_{i + 1:02d}", sfx_choix_battement(i), crete=0.6)
    sauver("amb_nef_imperiale", amb_nef(), crete=0.6, rms_db=-27, finir=False)
