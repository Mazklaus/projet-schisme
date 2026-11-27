#!/usr/bin/env python3
"""Vérifie les clés de drapeaux écrites par les dialogues (systeme-de-choix.md §2 et §7).

- Chaque clé écrite (« ~ cle = v », « += », « -= ») appartient à une des six familles :
  choix_epNN_<lieu>, vivant_<perso>, connait_<perso>_<fait>, relation_<perso>, trait_<nom>,
  epNN_<sujet>.
- <perso> est dans data/personnages.json ; aucune clé vivant_ ne porte sur un personnage canon.
- Les traits sont dans la liste fermée.

Usage : python3 tools/ci/verifier_cles.py [racine du projet]. Code de sortie 1 au moindre écart.
"""
import json
import pathlib
import re
import sys

TRAITS = {"obeissance", "compassion", "doute", "fraternite", "orgueil"}
AFFECTATION = re.compile(r"^\s*~\s*([A-Za-z0-9_]+)\s*(=|\+=|-=)")
EP = r"ep\d{2,3}"


def verifier(racine: pathlib.Path) -> list[str]:
    registre = json.loads((racine / "data/personnages.json").read_text(encoding="utf-8"))["personnages"]
    erreurs = []
    for dlg in sorted((racine / "data/dialogues").rglob("*.dlg")):
        rel = dlg.relative_to(racine)
        for n, ligne in enumerate(dlg.read_text(encoding="utf-8").splitlines(), 1):
            m = AFFECTATION.match(ligne)
            if not m:
                continue
            cle, ou = m.group(1), f"{rel}:{n}"
            if cle != cle.lower():
                erreurs.append(f"{ou} : {cle} doit être en minuscules")
            if re.fullmatch(EP + r"_[a-z0-9_]+", cle) or re.fullmatch(r"choix_" + EP + r"_[a-z0-9]+(_[a-z0-9]+)?", cle):
                continue
            famille, _, reste = cle.partition("_")
            if famille == "trait":
                if reste not in TRAITS:
                    erreurs.append(f"{ou} : trait inconnu « {reste} » (liste fermée : {', '.join(sorted(TRAITS))})")
            elif famille in ("vivant", "relation"):
                perso = registre.get(reste)
                if perso is None:
                    erreurs.append(f"{ou} : {cle} : « {reste} » absent de data/personnages.json")
                elif famille == "vivant" and perso.get("statut") == "canon":
                    erreurs.append(f"{ou} : {cle} interdit, {reste} est un personnage canon")
            elif famille == "connait":
                perso = next((p for p in sorted(registre, key=len, reverse=True) if reste.startswith(p + "_")), None)
                if perso is None:
                    erreurs.append(f"{ou} : {cle} : personnage absent de data/personnages.json")
            else:
                erreurs.append(f"{ou} : {cle} n'appartient à aucune famille de clés")
    return erreurs


if __name__ == "__main__":
    racine = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    erreurs = verifier(racine)
    for e in erreurs:
        print("ÉCHEC :", e)
    print(f"Clés de drapeaux : {len(erreurs)} écart(s)")
    sys.exit(1 if erreurs else 0)
