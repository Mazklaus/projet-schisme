#!/usr/bin/env python3
"""CI : les décors synchronisés depuis les dossiers du projet n'ont pas été modifiés à la main.

Compare chaque fichier listé dans data/decors_sync.json (verrou écrit par
tools/synchroniser_decors.py) avec le dépôt. Un calque modifié ou supprimé hors de la
synchronisation fait échouer la CI : la correction passe par le projet, puis la synchronisation.
L'écart avec les dossiers du projet (calque figé pas encore embarqué) se vérifie hors CI :
python3 tools/synchroniser_decors.py <etude-heresie> --verifier
Usage : python3 tools/ci/verifier_sync_decors.py [dépôt]
"""
import hashlib
import json
import pathlib
import sys

depot = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
verrou = json.loads((depot / "data/decors_sync.json").read_text(encoding="utf-8"))
erreurs = 0
for ident, v in sorted(verrou.items()):
    base = depot / "assets/decors" / ident
    for rel, somme in v["fichiers"].items():
        p = base / rel
        if not p.exists():
            print(f"::error file={p}::absent du dépôt alors qu'il est synchronisé ({v['source']})")
            erreurs += 1
        elif hashlib.md5(p.read_bytes()).hexdigest() != somme:
            print(f"::error file={p}::modifié hors synchronisation ({v['source']})")
            erreurs += 1
print(f"{len(verrou)} décor(s) synchronisé(s), {erreurs} écart(s) avec le verrou")
sys.exit(1 if erreurs else 0)
