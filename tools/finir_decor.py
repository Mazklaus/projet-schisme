#!/usr/bin/env python3
"""Finition d'un décor en une commande : retouche img2img → peindre_plan → 4k → synchronisation vers le dépôt.

Pour les retoucheurs (TP2, TP3, TP4) : lancer, puis vérifier l'avant/après et le rapport. Sur le dossier
source d'un décor (<id>/<id>.json + calques/ [+ calques/4k/]), pour chaque calque éclairé :
  1. sauvegarde de la maquette dans calques/_maquette/ (rien n'est perdu ; --restaurer la remet) ;
  2. retouche avec retoucher.py (TP2), en partant du 4k s'il existe. Réglages, dans l'ordre :
     la fiche <calque>.retouche.json déjà figée, sinon le bloc « retouche » du JSON du décor
     ({"defaut": {...}, "calques": {"10_salle": {...}}}), sinon les défauts de retoucher.py ;
  3. passe peindre_plan.py sur le résultat (elle écrit <calque>.peint.json) ;
  4. le 4k est remplacé par le résultat peint, et le 1080 en est la réduction : les deux sont toujours
     issus de la même retouche (règle CI « 4k plus récent que sa retouche ») ; la fiche .retouche.json
     est copiée à côté du calque 1080, avec sa « sortie » ;
  5. avec --depot : import dans assets/decors/<id> (tools/importer_decor.py), puis contrôle par
     verifier_decors.py et verifier_episode.py ; --branche crée une branche et un commit, --pr ouvre la PR.
Écrit une planche avant/après (finition/<id>_avant_apres.png) et un journal (finition/<id>.json).

Usage :
  python3 tools/finir_decor.py <dossier_decor> [--calques 10_salle,20_table] [--graine 7]
      [--sans-retouche] [--sans-peinture] [--depot .] [--branche] [--pr] [--restaurer] [--essai]
Variables : RETOUCHE_PY (python du venv de retouche), RETOUCHER (chemin de retoucher.py),
PEINDRE_PLAN (chemin de peindre_plan.py), PEINDRE_PY (python avec numpy et opencv).
"""
import argparse
import datetime
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

ICI = Path(__file__).resolve().parent
sys.path.insert(0, str(ICI / "ci"))
from verifier_episode import AUTO_LISSE, calques_declares, json_du_decor  # noqa: E402

CHAINE = Path(os.environ.get("CHAINE_IMAGES", "/mnt/project-files/etude-heresie/chaine-images"))
RETOUCHER = Path(os.environ.get("RETOUCHER", CHAINE / "retouche" / "retoucher.py"))
PEINDRE = Path(os.environ.get("PEINDRE_PLAN", CHAINE / "outils" / "peindre_plan.py"))
RETOUCHE_PY = os.environ.get("RETOUCHE_PY", sys.executable)
PEINDRE_PY = os.environ.get("PEINDRE_PY", sys.executable)
VARIANTES = ("_normal", "_ombre", "_plat", "_plat_normal")


def journal(msg):
    print(f"[finir_decor] {msg}", flush=True)


def lancer(cmd, essai=False, cwd=None):
    journal("$ " + " ".join(str(c) for c in cmd))
    if not essai:
        subprocess.run([str(c) for c in cmd], check=True, cwd=cwd)


def calques_a_finir(dossier, d, choix):
    """Calques éclairés du décor : ni gabarit, ni variante, ni calque lisse par nature (ciel, brume, lumens…)."""
    out = []
    for f, _, _ in calques_declares(d):
        p = dossier / f
        nom = p.stem
        if nom.startswith("gabarit_") or not p.is_file() or "/_maquette/" in str(p):
            continue
        if choix and nom not in choix:
            continue
        if not choix and any(s in nom for s in AUTO_LISSE):
            continue
        out.append(p)
    return out


def reglages(dossier, d, p):
    """Fiche figée du calque, sinon bloc « retouche » du décor."""
    fiche = p.with_suffix(".retouche.json")
    if fiche.is_file():
        f = json.loads(fiche.read_text(encoding="utf-8"))
        if f.get("statut") == "fige":
            return dict(f.get("reglages", {})), "fiche figée"
    bloc = d.get("retouche") if isinstance(d.get("retouche"), dict) else {}
    r = dict(bloc.get("defaut", {}))
    r.update(bloc.get("calques", {}).get(p.stem, {}))
    return r, "bloc retouche du décor" if r else "défauts de retoucher.py"


def options(r, graine):
    cmd = []
    for k, v in r.items():
        if k in ("entree", "sortie", "fiche", "graines") or v in ("", None, False):
            continue
        cmd += [f"--{k}"] if v is True else [f"--{k}", str(v)]
    return cmd + ["--graines", str(r.get("graines", graine)).split(",")[0]]


def planche(paires, chemin):
    """Avant/après côte à côte, une ligne par calque (vignettes 640 px)."""
    w = 640
    lignes = []
    for avant, apres in paires:
        a, b = (Image.open(x).convert("RGBA") for x in (avant, apres))
        h = int(w * a.height / a.width)
        lignes.append((a.resize((w, h)), b.resize((w, h))))
    if not lignes:
        return
    H = sum(a.height for a, _ in lignes)
    c = Image.new("RGBA", (2 * w, H), (60, 60, 64, 255))
    y = 0
    for a, b in lignes:
        c.alpha_composite(a, (0, y))
        c.alpha_composite(b, (w, y))
        y += a.height
    chemin.parent.mkdir(parents=True, exist_ok=True)
    c.convert("RGB").save(chemin, quality=88)


def restaurer(dossier):
    sauv = dossier / "calques" / "_maquette"
    if not sauv.is_dir():
        journal("rien à restaurer")
        return
    for f in sauv.rglob("*.png"):
        cible = dossier / "calques" / f.relative_to(sauv)
        shutil.copy2(f, cible)
        for ext in (".retouche.json", ".peint.json"):
            q = cible.with_suffix(ext)
            if q.exists():
                q.unlink()
        journal(f"restauré : {cible.relative_to(dossier)}")


def finir(a):
    dossier = Path(a.dossier).resolve()
    ident = dossier.name
    chemin, d, err = json_du_decor(str(dossier))
    if chemin is None:
        sys.exit(f"pas de JSON de décor dans {dossier} ({err})")
    if a.restaurer:
        return restaurer(dossier)
    choix = set(a.calques.split(",")) if a.calques else set()
    calques = calques_a_finir(dossier, d, choix)
    if not calques:
        sys.exit("aucun calque à finir")
    travail = dossier / "calques" / "_finition"
    sauv = dossier / "calques" / "_maquette"
    travail.mkdir(parents=True, exist_ok=True)
    bilan, paires = [], []
    for p in calques:
        k4 = p.parent / "4k" / p.name
        source = k4 if k4.is_file() else p
        rel = source.relative_to(dossier / "calques")
        maquette = sauv / rel
        if not maquette.exists():                       # la maquette d'origine n'est sauvegardée qu'une fois
            maquette.parent.mkdir(parents=True, exist_ok=True)
            if not a.essai:
                shutil.copy2(source, maquette)
            if source != p and not (sauv / p.name).exists() and not a.essai:
                shutil.copy2(p, sauv / p.name)
        entree = maquette if maquette.exists() else source  # on repart toujours de la maquette
        etape = entree
        ligne = {"calque": p.name, "source": str(rel)}
        if not a.sans_retouche:
            r, origine = reglages(dossier, d, p)
            sortie = travail / f"{p.stem}_retouche.png"
            prof = p.with_name(p.stem + "_profondeur.png")
            if prof.is_file() and "profondeur" not in r:
                r["profondeur"] = str(prof)
            lancer([RETOUCHE_PY, RETOUCHER, entree, sortie] + options(r, a.graine), a.essai)
            ligne["retouche"] = origine
            etape = sortie
        if not a.sans_peinture:
            peint = travail / f"{p.stem}_peint.png"
            lancer([PEINDRE_PY, PEINDRE, etape, peint], a.essai)
            etape = peint
        if a.essai:
            bilan.append(ligne)
            continue
        final = Image.open(etape).convert("RGBA")
        if source == k4:                               # 4k = résultat peint ; 1080 = sa réduction
            final.save(k4, optimize=True)
            final.resize(Image.open(p).size, Image.LANCZOS).save(p, optimize=True)
        else:
            final.resize(Image.open(p).size, Image.LANCZOS).save(p, optimize=True)
        maintenant = datetime.datetime.now().isoformat(timespec="seconds")
        if not a.sans_retouche:
            f = json.loads((travail / f"{p.stem}_retouche.retouche.json").read_text(encoding="utf-8"))
            f.update({"sortie": f"calques/{p.name}", "date": maintenant, "finir_decor": True,
                      "statut": f.get("statut", "essai")})
            p.with_suffix(".retouche.json").write_text(json.dumps(f, ensure_ascii=False, indent=2), encoding="utf-8")
        if not a.sans_peinture:
            q = travail / f"{p.stem}_peint.peint.json"
            m = json.loads(q.read_text(encoding="utf-8")) if q.is_file() else {"outil": "peindre_plan.py"}
            m.update({"sortie": f"calques/{p.name}", "date": maintenant})
            p.with_suffix(".peint.json").write_text(json.dumps(m, ensure_ascii=False, indent=1), encoding="utf-8")
        paires.append((sauv / p.name if (sauv / p.name).exists() else maquette, p))
        ligne["fait"] = maintenant
        bilan.append(ligne)
        journal(f"fini : {p.name}" + (" (+4k)" if source == k4 else ""))
    sortie_dir = dossier.parent / "finition"
    planche(paires, sortie_dir / f"{ident}_avant_apres.jpg")
    sortie_dir.mkdir(parents=True, exist_ok=True)
    (sortie_dir / f"{ident}.json").write_text(json.dumps({"decor": ident, "calques": bilan}, ensure_ascii=False, indent=2),
                                             encoding="utf-8")
    journal(f"planche : {sortie_dir / (ident + '_avant_apres.jpg')}")
    if a.depot and not a.essai:
        synchroniser(dossier, ident, Path(a.depot).resolve(), a)


def retirer_fini(dossier_decor, essai=False):
    """Garde-fou (GD) : seule la DA, sur une capture en jeu, marque un décor « fini ».
    Un décor qui vient d'être repeint repasse donc au statut « peint »."""
    rabattus = []
    for f in sorted(Path(dossier_decor).glob("*.json")):
        try:
            d = json.loads(f.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        if isinstance(d, dict) and "fini" in str(d.get("statut", "")).lower():
            journal(f"statut « {d['statut']} » de {f.name} ramené à « peint » : la DA valide sur capture en jeu")
            d["statut"] = "peint"
            rabattus.append(f.name)
            if not essai:
                f.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return rabattus


def synchroniser(dossier, ident, depot, a):
    lancer([sys.executable, depot / "tools" / "importer_decor.py", dossier, ident], cwd=depot)  # calques/ sans 4k
    retirer_fini(depot / "assets" / "decors" / ident, essai=a.essai)
    cible = depot / "assets" / "decors" / ident / "calques"
    for f in (dossier / "calques").glob("*.json"):                                 # fiches .retouche/.peint
        shutil.copy2(f, cible / f.name)
    for sous in ("_maquette", "_finition"):                                        # jamais dans le jeu
        shutil.rmtree(cible / sous, ignore_errors=True)
    lancer([sys.executable, depot / "tools" / "ci" / "verifier_decors.py", depot])
    if a.branche or a.pr:
        b = f"decors/finition-{ident}"
        lancer(["git", "-C", depot, "checkout", "-B", b])
        lancer(["git", "-C", depot, "add", f"assets/decors/{ident}"])
        lancer(["git", "-C", depot, "commit", "-m", f"Décor {ident} : retouche, peindre_plan et 4k (finir_decor.py)"])
        if a.pr:
            lancer(["git", "-C", depot, "-c", "push.negotiate=true", "push", "-u", "origin", b])
            lancer(["gh", "api", "repos/{owner}/{repo}/pulls", "-f", f"title=Décor {ident} : finition",
                    "-f", f"head={b}", "-f", "base=main",
                    "-f", f"body=Retouche, peindre_plan et 4k par tools/finir_decor.py. Statut « peint » : seule la DA, sur capture en jeu, passe le décor à « fini ». Planche avant/après : "
                          f"finition/{ident}_avant_apres.jpg (dossier source du décor)."])


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("dossier")
    ap.add_argument("--calques", help="noms de calques à finir (défaut : tous les calques éclairés)")
    ap.add_argument("--graine", type=int, default=7)
    ap.add_argument("--sans-retouche", action="store_true", help="peindre_plan seulement")
    ap.add_argument("--sans-peinture", action="store_true", help="retouche seulement")
    ap.add_argument("--depot", help="clone de projet-schisme : importe et contrôle le décor")
    ap.add_argument("--branche", action="store_true", help="avec --depot : branche et commit")
    ap.add_argument("--pr", action="store_true", help="avec --depot : pousse et ouvre la PR")
    ap.add_argument("--restaurer", action="store_true", help="remet les maquettes sauvegardées")
    ap.add_argument("--essai", action="store_true", help="affiche les commandes sans rien écrire")
    finir(ap.parse_args(argv))


if __name__ == "__main__":
    main()
