#!/usr/bin/env python3
"""Importe un décor de la DA (dossier <id>/ avec <id>.json et calques/) dans assets/decors/<id>/.

- Copie le JSON et les calques en 1080p (le sous-dossier calques/4k/ n'est pas importé).
- Un calque qui pointe hors du dossier (« ../../tranche-verticale/calques/30_voie.png » : un état
  d'un lieu existant) est copié dans calques/ avec ses variantes (_normal, _ombre, _plat…) et le
  JSON est réécrit pour pointer dessus.
- N'efface rien d'autre dans la cible : relancer l'import met le décor à jour.

Usage : python3 tools/importer_decor.py <dossier_source> [id]
"""
import json
import pathlib
import shutil
import sys

VARIANTES = ["", "_normal", "_ombre", "_plat", "_plat_normal"]


def importer(src: pathlib.Path, ident: str, racine: pathlib.Path) -> pathlib.Path:
    js = src / f"{ident}.json"
    plan = json.loads(js.read_text(encoding="utf-8"))
    cible = racine / "assets/decors" / ident
    (cible / "calques").mkdir(parents=True, exist_ok=True)
    for f in sorted((src / "calques").glob("*.png")):
        shutil.copy2(f, cible / "calques" / f.name)
    for c in plan.get("calques", []):
        f = c.get("fichier", "")
        if not f.startswith(".."):
            continue
        orig = (src / f).resolve()
        for v in VARIANTES:
            alt = orig.with_name(orig.stem + v + orig.suffix)
            if alt.exists():
                shutil.copy2(alt, cible / "calques" / alt.name)
        c["fichier"] = f"calques/{orig.name}"
    (cible / f"{ident}.json").write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return cible


if __name__ == "__main__":
    src = pathlib.Path(sys.argv[1])
    ident = sys.argv[2] if len(sys.argv) > 2 else src.name
    print("importé :", importer(src, ident, pathlib.Path(".")))
