#!/usr/bin/env python3
"""Tableau de bord quotidien du GD : captures et suivi de production après chaque fusion sur main.

    python3 tools/tableau_de_bord.py --sortie /mnt/project-files/etude-heresie/qa-suivi [--episode ep01]

À chaque passage (tâche planifiée horaire) :
  1. met à jour un clone dédié de main (--clone, défaut ~/schisme-tableau) ;
  2. s'il n'y a aucun commit depuis la dernière publication qui touche l'épisode (dialogues, données
     d'épisode, décors, personnages, moteur), s'arrête là (--forcer pour passer outre) ;
  3. lance capturer_episode.py (SCHISME_SANS_DEBUG=1), contre la build publiée précédente ;
  4. lance verifier_episode.py avec l'historique publié ;
  5. publie dans <sortie>/ : tableau_<ep>.md (la page à lire), suivi_<ep>.md, historique_<ep>.csv,
     captures/<build>/ (planches avant/après, rapport, images). Seules les deux dernières builds
     d'images sont gardées ; les planches et rapports des builds plus anciennes restent.
"""
import argparse
import datetime
import json
import os
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

DEPOT = "https://github.com/Mazklaus/projet-schisme.git"
GODOT_VERSION = "4.7.2-stable"
# chemins qui changent l'image ou le suivi d'un épisode ({ep} remplacé)
CHEMINS = ["data/dialogues/{ep}", "data/episodes/{ep}", "data/episodes/{ep}_", "data/decors_alias.json",
           "data/personnages.json", "assets/decors", "assets/personnages", "assets/tranche_ullanor",
           "src", "scenes", "tools/capturer_episode.py", "tools/ci/capturer_episode.gd",
           "tools/ci/verifier_episode.py"]
IMAGES_GARDEES = 2


def journal(msg):
    print(f"[tableau] {msg}", flush=True)


def git(clone, *args, check=True):
    p = subprocess.run(["git", "-C", str(clone), *args], capture_output=True, text=True)
    if check and p.returncode:
        raise SystemExit(f"git {' '.join(args)} : {p.stderr.strip()}")
    return p.stdout.strip()


def maj_clone(clone):
    clone = Path(clone)
    if not (clone / ".git").is_dir():
        url = git(Path(__file__).resolve().parent.parent, "remote", "get-url", "origin", check=False) or DEPOT
        journal(f"clone de main dans {clone}")
        subprocess.run(["git", "clone", "-q", "--depth", "200", "--branch", "main", url, str(clone)], check=True)
    else:
        git(clone, "fetch", "-q", "--depth", "200", "origin", "main")
        git(clone, "checkout", "-q", "-B", "main", "origin/main")
        git(clone, "reset", "-q", "--hard", "origin/main")
    return git(clone, "rev-parse", "HEAD")


def touche_episode(clone, depuis, ep):
    """Commits de depuis..HEAD qui touchent l'épisode ([] si aucun ; None si depuis est inconnu)."""
    if not depuis or git(clone, "cat-file", "-t", depuis, check=False) != "commit":
        return None
    chemins = []
    for c in CHEMINS:
        c = c.format(ep=ep)
        chemins += [str(p.relative_to(clone)) for p in Path(clone).glob(c + "*")] if c.endswith("_") else [c]
    sortie = git(clone, "log", "--format=%h %s", f"{depuis}..HEAD", "--", *chemins)
    return [l for l in sortie.splitlines() if l]


def trouver_godot(choix):
    for c in [choix, os.environ.get("GODOT"), shutil.which("godot"), os.path.expanduser("~/godot/godot")]:
        if c and os.path.isfile(c) and os.access(c, os.X_OK):
            return c
    cible = Path.home() / "godot"
    cible.mkdir(exist_ok=True)
    url = (f"https://github.com/godotengine/godot/releases/download/{GODOT_VERSION}/"
           f"Godot_v{GODOT_VERSION}_linux.x86_64.zip")
    journal(f"téléchargement de Godot {GODOT_VERSION}")
    z = cible / "godot.zip"
    urllib.request.urlretrieve(url, z)
    with zipfile.ZipFile(z) as f:
        f.extractall(cible)
    z.unlink()
    (cible / f"Godot_v{GODOT_VERSION}_linux.x86_64").rename(cible / "godot")
    (cible / "godot").chmod(0o755)
    return str(cible / "godot")


def lire_etat(sortie):
    try:
        return json.loads((sortie / "tableau_etat.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def nettoyer(captures):
    builds = sorted(d for d in captures.iterdir() if d.is_dir())
    for d in builds[:-IMAGES_GARDEES]:
        for f in d.iterdir():
            if f.suffix in (".jpg", ".png") and not f.name.startswith("planche"):
                f.unlink()


def page(sortie, ep, build, sha, commits, code_capt, code_suivi):
    dossier = sortie / "captures" / build
    rapport = (dossier / "rapport.md").read_text(encoding="utf-8") if (dossier / "rapport.md").is_file() else ""
    resume = next((l for l in rapport.splitlines() if l.startswith("Référence")), "")
    suivi = (sortie / f"suivi_{ep}.md").read_text(encoding="utf-8") if (sortie / f"suivi_{ep}.md").is_file() else ""
    L = [f"# Tableau de bord {ep}", "",
         f"Mis à jour le {datetime.datetime.now():%d/%m/%Y à %H:%M} UTC, main @ {sha[:7]}.", "",
         "## Ce qui a changé depuis la publication précédente", ""]
    L += [f"- {c}" for c in commits[:15]] or ["- (première publication, ou publication forcée)"]
    if len(commits) > 15:
        L.append(f"- … et {len(commits) - 15} autres")
    L += ["", "## Captures", "", resume, "",
          f"Planches avant/après : captures/{build}/planche_*.jpg (changés et nouveaux en tête). "
          f"Rapport complet : captures/{build}/rapport.md.", ""]
    if code_capt:
        L += ["**Le rendu a signalé des échecs** : voir la section « Échecs du rendu » du rapport.", ""]
    if code_suivi:
        L += ["**Le suivi de production signale des erreurs bloquantes** (voir ci-dessous).", ""]
    L += ["## Suivi de production", "", suivi.split("\n", 1)[1] if suivi.startswith("#") else suivi]
    (sortie / f"tableau_{ep}.md").write_text("\n".join(L) + "\n", encoding="utf-8")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--sortie", required=True, help="dossier publié (ex. etude-heresie/qa-suivi)")
    ap.add_argument("--episode", default="ep01")
    ap.add_argument("--clone", default=str(Path.home() / "schisme-tableau"))
    ap.add_argument("--godot")
    ap.add_argument("--forcer", action="store_true", help="publier même sans changement de l'épisode")
    a = ap.parse_args(argv)
    sortie = Path(a.sortie)
    sortie.mkdir(parents=True, exist_ok=True)
    clone = Path(a.clone)
    sha = maj_clone(clone)
    etat = lire_etat(sortie)
    cle = f"{a.episode}_sha"
    commits = touche_episode(clone, etat.get(cle), a.episode)
    if etat.get(cle) == sha and not a.forcer:
        journal(f"main @ {sha[:7]} déjà publié : rien à faire")
        return 0
    if commits == [] and not a.forcer:
        journal(f"main @ {sha[:7]} : aucun commit ne touche {a.episode} depuis {etat[cle][:7]}")
        etat[cle] = sha
        (sortie / "tableau_etat.json").write_text(json.dumps(etat, indent=1), encoding="utf-8")
        return 0
    commits = commits or []
    env = dict(os.environ, SCHISME_SANS_DEBUG="1", GODOT=trouver_godot(a.godot))
    captures = sortie / "captures"
    captures.mkdir(exist_ok=True)
    # capturer_episode écrit dans <clone>/qa/captures : on y relie le dossier publié
    lien = clone / "qa" / "captures"
    if lien.is_symlink() or not lien.exists():
        lien.unlink(missing_ok=True)
    else:
        shutil.rmtree(lien)
    lien.symlink_to(captures.resolve(), target_is_directory=True)
    build = datetime.datetime.now().strftime("%Y%m%d-%H%M") + "_" + sha[:7]
    code_capt = subprocess.run([sys.executable, str(clone / "tools" / "capturer_episode.py"), a.episode,
                                "--racine", str(clone), "--build", build], env=env).returncode
    hist = sortie / f"historique_{a.episode}.csv"
    if not hist.is_file() and (clone / "qa" / hist.name).is_file():  # la courbe continue celle du dépôt
        shutil.copy2(clone / "qa" / hist.name, hist)
    code_suivi = subprocess.run([sys.executable, str(clone / "tools" / "ci" / "verifier_episode.py"), a.episode,
                                 "--racine", str(clone), "--sortie", str(sortie / f"suivi_{a.episode}.md"),
                                 "--historique", str(hist)], env=env).returncode
    nettoyer(captures)
    page(sortie, a.episode, build, sha, commits, code_capt, code_suivi)
    etat[cle] = sha
    etat[f"{a.episode}_build"] = build
    (sortie / "tableau_etat.json").write_text(json.dumps(etat, indent=1), encoding="utf-8")
    journal(f"publié : {sortie / f'tableau_{a.episode}.md'} (build {build})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
