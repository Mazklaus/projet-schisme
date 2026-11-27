#!/usr/bin/env python3
"""Bustes des gros plans (règle GD 27/11) : pas de miroir sur un personnage asymétrique.

Les bustes de CA1 sont peints d'un seul côté ; l'autre côté livré est un miroir rééclairé
(relevé QA v2). data/bustes_peints.json donne les côtés peints de chaque personnage. Pour chaque
personnage placé dans data/episodes/*/gros_plans.json et qui a des bustes
(assets/personnages/<perso>/), le côté choisi doit exister et être peint ; un personnage à bustes
non déclaré est une erreur. Un personnage sans buste reste en plan large (régie) : non contrôlé.
Code 1 s'il y a une erreur.
"""
import json
import pathlib
import sys

DEPOT = pathlib.Path(__file__).resolve().parents[2]


def main() -> int:
    erreurs = []
    peints = json.loads((DEPOT / "data/bustes_peints.json").read_text(encoding="utf-8"))
    for f in sorted(DEPOT.glob("data/episodes/*/gros_plans.json")):
        for s in json.loads(f.read_text(encoding="utf-8")).get("scenes", []):
            for perso, cote in s.get("cotes", {}).items():
                dossier = DEPOT / "assets/personnages" / perso.lower()
                if not dossier.is_dir() or not any(dossier.glob("buste*.png")):
                    continue
                autre = "droite" if cote == "gauche" else "gauche"
                b = dossier / f"buste_{cote}_neutre.png"
                lieu = f"{f.relative_to(DEPOT)} {s.get('chapitre')} {s.get('decor')}"
                if not b.exists():
                    erreurs.append(f"{lieu} : {perso} à {cote}, mais {b.relative_to(DEPOT)} n'existe pas")
                    continue
                cotes = peints.get(perso.lower())
                if cotes is None:
                    erreurs.append(f"{lieu} : déclarer les côtés peints de {perso} dans data/bustes_peints.json")
                elif cote not in cotes:
                    erreurs.append(f"{lieu} : {perso} à {cote} utilise un buste non peint (miroir) ; "
                                   f"côté peint : {', '.join(cotes)}")
    for e in erreurs:
        print(f"::error::{e}")
    print(f"{len(erreurs)} erreur(s) de bustes")
    return 1 if erreurs else 0


if __name__ == "__main__":
    sys.exit(main())
