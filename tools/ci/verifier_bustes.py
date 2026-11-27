#!/usr/bin/env python3
"""Bustes des gros plans (règle GD 27/11) : pas de miroir sur un personnage asymétrique.

Pour chaque personnage placé d'un côté dans data/episodes/*/gros_plans.json et qui a des bustes
(assets/personnages/<perso>/), le buste de ce côté doit être PEINT : buste_<côté>_neutre.png
existe et n'est pas le buste de l'autre côté retourné. Critère : la silhouette (alpha) retournée
est identique à moins de SEUIL près (part des pixels qui diffèrent de plus de 64/255) ; un vrai
buste peint de l'autre côté diffère toujours (Krenn, le plus proche : 0,2 %).
Quand les deux côtés sont en miroir, data/bustes_peints.json dit lequel est peint ; une paire en
miroir non déclarée est aussi une erreur. Un personnage sans aucun buste reste en plan large
(régie) : il n'est pas contrôlé ici.
Code 1 s'il y a une erreur.
"""
import json
import pathlib
import sys

import numpy as np
from PIL import Image

DEPOT = pathlib.Path(__file__).resolve().parents[2]
SEUIL = 0.0005


def charger(p: pathlib.Path) -> np.ndarray:
    return np.asarray(Image.open(p).convert("RGBA")).astype(np.float32)


def est_miroir(a: pathlib.Path, b: pathlib.Path) -> bool:
    x, y = charger(a), charger(b)
    return x.shape == y.shape and float((np.abs(x[..., 3] - y[:, ::-1, 3]) > 64).mean()) < SEUIL


def main() -> int:
    erreurs = []
    miroirs: dict = {}
    peints = json.loads((DEPOT / "data/bustes_peints.json").read_text(encoding="utf-8"))
    for f in sorted(DEPOT.glob("data/episodes/*/gros_plans.json")):
        for s in json.loads(f.read_text(encoding="utf-8")).get("scenes", []):
            for perso, cote in s.get("cotes", {}).items():
                dossier = DEPOT / "assets/personnages" / perso.lower()
                if not dossier.is_dir() or not any(dossier.glob("buste*.png")):
                    continue
                autre = "droite" if cote == "gauche" else "gauche"
                b = dossier / f"buste_{cote}_neutre.png"
                o = dossier / f"buste_{autre}_neutre.png"
                lieu = f"{f.relative_to(DEPOT)} {s.get('chapitre')} {s.get('decor')}"
                if not b.exists():
                    erreurs.append(f"{lieu} : {perso} à {cote}, mais {b.relative_to(DEPOT)} n'existe pas")
                    continue
                if o.exists():
                    cle = str(dossier)
                    if cle not in miroirs:
                        miroirs[cle] = est_miroir(b, o)
                    if miroirs[cle]:
                        cotes = peints.get(perso.lower())
                        if cotes is None:
                            erreurs.append(f"{lieu} : les bustes de {perso} sont en miroir ; déclarer le côté "
                                           "peint dans data/bustes_peints.json")
                        elif cote not in cotes:
                            erreurs.append(f"{lieu} : {perso} à {cote} utilise un buste retourné "
                                           f"(côté peint : {', '.join(cotes)})")
    for e in erreurs:
        print(f"::error::{e}")
    print(f"{len(erreurs)} erreur(s) de bustes")
    return 1 if erreurs else 0


if __name__ == "__main__":
    sys.exit(main())
