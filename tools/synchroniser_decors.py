#!/usr/bin/env python3
"""Synchronise les décors prêts des dossiers du projet (etude-heresie/episode-*/<id>/) vers
assets/decors/<id>/ du dépôt, et tient le verrou data/decors_sync.json.

Un décor est synchronisé s'il est « prêt » :
  - son JSON source a un « statut » qui commence par « figé » ou contient « validé DA », ou
    « pret_jeu »: true ;
  - ou son id est listé dans data/decors_prets.json (« prets »), tenu par le Lead sur l'avis de la DA.
Ce qui est copié : <id>.json et calques/*.png en 1080 (pas calques/4k/, base_plate/, apercus ni
gabarits : gabarit_*.png sont des repères de composition, jamais affichés).

Le JSON source fait foi, sauf :
  - data/decors_prets.json « garder_json » : ids dont le JSON du dépôt est gardé tel quel
    (format converti à la main pour le moteur) ; seuls les calques sont copiés ;
  - data/decors_prets.json « surcharges » {id: {clé: valeur}} : réglages moteur du Lead
    (reglage_moteur, appoints calés en jeu…) réappliqués par-dessus le JSON source.

Usage :
  python3 tools/synchroniser_decors.py <etude-heresie> [id …]     synchronise (tous les prêts)
  python3 tools/synchroniser_decors.py <etude-heresie> --verifier  écarts dépôt / projet, code 1 s'il y en a
Le verrou (md5 de chaque fichier copié) est contrôlé en CI par tools/ci/verifier_sync_decors.py.
"""
import hashlib
import json
import pathlib
import shutil
import sys

DEPOT = pathlib.Path(__file__).resolve().parent.parent
MANIFESTE = DEPOT / "data/decors_prets.json"
VERROU = DEPOT / "data/decors_sync.json"
VARIANTES = ["", "_normal", "_ombre", "_plat", "_plat_normal", "_prof"]


def md5(p: pathlib.Path) -> str:
    return hashlib.md5(p.read_bytes()).hexdigest()


def manifeste() -> dict:
    return json.loads(MANIFESTE.read_text(encoding="utf-8")) if MANIFESTE.exists() else {}


def source_de(etude: pathlib.Path, ident: str):
    for ep in sorted(etude.glob("episode-*")):
        if (ep / ident / f"{ident}.json").exists():
            return ep / ident
    return None


def est_pret(src: pathlib.Path, ident: str, m: dict) -> bool:
    if ident in m.get("prets", []):
        return True
    j = json.loads((src / f"{ident}.json").read_text(encoding="utf-8"))
    statut = str(j.get("statut", "")).lower()
    return bool(j.get("pret_jeu")) or statut.startswith("figé") or "validé da" in statut


def calques_source(src: pathlib.Path) -> list:
    return [f for f in sorted((src / "calques").glob("*.png")) if not f.name.startswith("gabarit_")]


def fusion(base, sur):
    if isinstance(base, dict) and isinstance(sur, dict):
        out = dict(base)
        for k, v in sur.items():
            out[k] = fusion(base.get(k), v)
        return out
    return sur


def json_cible(src: pathlib.Path, ident: str, m: dict, extras: list) -> dict:
    plan = json.loads((src / f"{ident}.json").read_text(encoding="utf-8"))
    # Calque qui pointe vers un autre lieu (« ../../tranche-verticale/… ») : copié dans calques/.
    for c in plan.get("calques", []):
        f = c.get("fichier", "") if isinstance(c, dict) else ""
        if f.startswith(".."):
            orig = (src / f).resolve()
            for v in VARIANTES:
                alt = orig.with_name(orig.stem + v + orig.suffix)
                if alt.exists():
                    extras.append(alt)
            c["fichier"] = f"calques/{orig.name}"
    return fusion(plan, m.get("surcharges", {}).get(ident, {}))


def synchroniser(etude: pathlib.Path, ident: str, m: dict, verrou: dict) -> list:
    src = source_de(etude, ident)
    cible = DEPOT / "assets/decors" / ident
    (cible / "calques").mkdir(parents=True, exist_ok=True)
    extras: list = []
    plan = json_cible(src, ident, m, extras)
    changes = []
    for f in calques_source(src) + extras:
        d = cible / "calques" / f.name
        if not d.exists() or md5(d) != md5(f):
            shutil.copy2(f, d)
            changes.append(f"calques/{f.name}")
    jc = cible / f"{ident}.json"
    if ident not in m.get("garder_json", []):
        texte = json.dumps(plan, ensure_ascii=False, indent=2) + "\n"
        if not jc.exists() or jc.read_text(encoding="utf-8") != texte:
            jc.write_text(texte, encoding="utf-8")
            changes.append(jc.name)
    verrou[ident] = {"source": str(src.relative_to(etude)),
                     "fichiers": {str(p.relative_to(cible)): md5(p) for p in sorted(cible.rglob("*"))
                                  if p.is_file() and p.suffix in (".png", ".json")}}
    return changes


def ecarts(etude: pathlib.Path, ident: str, m: dict) -> list:
    src = source_de(etude, ident)
    cible = DEPOT / "assets/decors" / ident
    extras: list = []
    plan = json_cible(src, ident, m, extras)
    out = []
    for f in calques_source(src) + extras:
        d = cible / "calques" / f.name
        if not d.exists():
            out.append(f"manquant : calques/{f.name}")
        elif md5(d) != md5(f):
            out.append(f"périmé : calques/{f.name}")
    jc = cible / f"{ident}.json"
    if ident not in m.get("garder_json", []) and (
            not jc.exists() or json.loads(jc.read_text(encoding="utf-8")) != plan):
        out.append(f"périmé : {jc.name}")
    return out


def main() -> int:
    etude = pathlib.Path(sys.argv[1])
    args = sys.argv[2:]
    verifier = "--verifier" in args
    ids = [a for a in args if not a.startswith("--")]
    m = manifeste()
    if not ids:
        ids = sorted(p.name for p in (DEPOT / "assets/decors").iterdir() if p.is_dir())
        ids += [i for i in m.get("prets", []) if i not in ids]
    verrou = json.loads(VERROU.read_text(encoding="utf-8")) if VERROU.exists() else {}
    total = 0
    for ident in ids:
        src = source_de(etude, ident)
        if src is None:
            continue
        if not est_pret(src, ident, m):
            print(f"{ident} : pas marqué prêt, ignoré")
            continue
        if verifier:
            e = ecarts(etude, ident, m)
            for x in e:
                print(f"::error::{ident} : {x}")
            total += len(e)
        else:
            c = synchroniser(etude, ident, m, verrou)
            if c:
                print(f"{ident} : {len(c)} fichier(s) mis à jour : {', '.join(c[:6])}{' …' if len(c) > 6 else ''}")
            total += len(c)
    if not verifier:
        VERROU.write_text(json.dumps(verrou, ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8")
        print(f"{total} fichier(s) mis à jour ; verrou : {VERROU.relative_to(DEPOT)}")
        return 0
    print(f"{total} écart(s) entre le dépôt et les décors prêts du projet")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
