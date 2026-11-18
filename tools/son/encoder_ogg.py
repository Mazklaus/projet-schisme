#!/usr/bin/env python3
"""Encode les .wav de generer_ullanor.py en Ogg Vorbis dans assets/audio/ (ffmpeg + libvorbis).

Usage : python3 tools/son/encoder_ogg.py <dossier_wav> [assets/audio]
Qualité : musique q6, ambiances q4, bruitages q5. Les boucles (mus_, amb_, sfx_poutre_grince)
sont bouclées par l'autoload Son au chargement, pas dans le fichier.
"""
import glob
import os
import subprocess
import sys

SOURCE = sys.argv[1]
DEST = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
QUALITE = {"mus": 6, "amb": 4, "sfx": 5}

os.makedirs(DEST, exist_ok=True)
for wav in sorted(glob.glob(os.path.join(SOURCE, "*.wav"))):
    nom = os.path.splitext(os.path.basename(wav))[0]
    q = QUALITE.get(nom.split("_")[0], 5)
    ogg = os.path.join(DEST, nom + ".ogg")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", str(q),
                    "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact", ogg], check=True)
    print(f"{nom}.ogg  q{q}  {os.path.getsize(ogg) // 1024} Ko")
