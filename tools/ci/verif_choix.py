#!/usr/bin/env python3
"""Vérifie les .dlg d'un épisode contre la spec du système de choix (systeme-de-choix.md v1.3).

Usage : python3 verif_choix.py <dossier ou fichiers .dlg> [--registre data/personnages.json]

Contrôles (Game Designer) :
  1. Nommage des clés (§2) : familles, traits de la liste fermée, <perso> présent au registre.
  2. Pas de vivant_<perso> pour un personnage canon.
  3. Cibles de choix et de sauts existantes (sauf FIN et @reprendre).
  4. Menu minuté : sa cible par défaut est une option du menu, sans condition.
  5. Règle 3.1 : toutes les options d'un menu écrivent la même liste de clés persistantes
     (erreur pour choix_, vivant_, connait_, relation_ ; simple avis pour un trait, qui vaut 0 s'il est absent)
     (on suit la branche jusqu'au prochain menu, en prenant les sauts sans condition).
  6. Équilibrage : occasions par trait et par personnage, par fichier (chapitre) et au total.
Ce n'est qu'une lecture statique : elle ne remplace pas la partie jouée par le QA.
"""
import json, re, sys, pathlib, collections

TRAITS = {"obeissance", "compassion", "doute", "fraternite", "orgueil"}
RE_NOEUD = re.compile(r"^===\s*([A-Za-z0-9_]+)\s*$")
RE_CHOIX = re.compile(r"^\*\s+(.+?)\s*->\s*([A-Za-z0-9_]+)\s*(?:\[si\s+(.+?)\])?\s*$")
RE_DELAI = re.compile(r"^\*!\s*([0-9.]+)\s*->\s*([A-Za-z0-9_]+)\s*$")
RE_SAUT = re.compile(r"^->\s*([A-Za-z0-9_]+)\s*(?:\[si\s+(.+?)\])?\s*$")
RE_AFFECT = re.compile(r"^~\s*([A-Za-z0-9_]+)\s*(=|\+=|-=)\s*(.+?)\s*$")
FAMILLES = [
    ("choix", re.compile(r"^choix_ep\d{2,3}_[a-z0-9]+(_[a-z0-9]+)?$")),
    ("vivant", re.compile(r"^vivant_([a-z0-9_]+)$")),
    ("connait", re.compile(r"^connait_([a-z0-9]+)_[a-z0-9]+(_[a-z0-9]+)?$")),
    ("relation", re.compile(r"^relation_([a-z0-9_]+)$")),
    ("trait", re.compile(r"^trait_([a-z0-9]+)_([a-z0-9]+)$")),
    ("local", re.compile(r"^ep\d{2,3}_[a-z0-9_]+$")),
]


def lire(fichiers):
    noeuds, ordre = {}, []
    for f in fichiers:
        courant = None
        for num, brut in enumerate(pathlib.Path(f).read_text(encoding="utf-8").splitlines(), 1):
            l = brut.strip()
            if not l or l.startswith("//"):
                continue
            m = RE_NOEUD.match(l)
            if m:
                courant = {"nom": m[1], "fichier": pathlib.Path(f).name, "instr": []}
                noeuds[m[1]] = courant
                ordre.append(m[1])
                continue
            if courant is None:
                continue
            for typ, rx in (("delai", RE_DELAI), ("choix", RE_CHOIX), ("saut", RE_SAUT), ("affect", RE_AFFECT)):
                m = rx.match(l)
                if m:
                    courant["instr"].append((typ, m.groups(), num))
                    break
            else:
                if l.startswith("@reprendre"):
                    courant["instr"].append(("reprendre", (l,), num))
    return noeuds, ordre


def famille(cle):
    for nom, rx in FAMILLES:
        m = rx.match(cle)
        if m:
            return nom, m
    return None, None


def menus(noeud):
    """Regroupe les choix consécutifs d'un nœud en menus."""
    res, cur = [], None
    for typ, g, num in noeud["instr"]:
        if typ == "choix":
            if cur is None:
                cur = {"options": [], "delai": None, "ligne": num}
                res.append(cur)
            cur["options"].append({"texte": g[0], "cible": g[1], "cond": g[2]})
        elif typ == "delai" and cur is not None:
            cur["delai"] = (float(g[0]), g[1])
        else:
            cur = None
    return res


def cles_branche(noeuds, depart, vus=None):
    """Clés persistantes écrites depuis `depart` jusqu'au prochain menu (sauts sans condition suivis)."""
    vus = vus or set()
    if depart in vus or depart not in noeuds:
        return {}
    vus.add(depart)
    ecrit = {}
    for typ, g, _ in noeuds[depart]["instr"]:
        if typ == "affect":
            fam, _m = famille(g[0])
            if fam and fam != "local":
                ecrit[g[0]] = (g[1], g[2])
        elif typ == "choix":
            return ecrit
        elif typ == "saut":
            if g[1] is None:
                ecrit.update(cles_branche(noeuds, g[0], vus))
                return ecrit
    return ecrit


def main():
    args = sys.argv[1:]
    registre = {}
    if "--registre" in args:
        i = args.index("--registre")
        registre = json.loads(pathlib.Path(args[i + 1]).read_text(encoding="utf-8")).get("personnages", {})
        del args[i:i + 2]
    fichiers = []
    for a in args:
        p = pathlib.Path(a)
        fichiers += sorted(p.glob("*.dlg")) if p.is_dir() else [p]
    noeuds, ordre = lire(fichiers)
    erreurs, avis = [], []

    # 1 et 2 : nommage
    for n in ordre:
        for typ, g, num in noeuds[n]["instr"]:
            if typ != "affect":
                continue
            cle, ou = g[0], f"{noeuds[n]['fichier']}:{num}"
            fam, m = famille(cle)
            if fam is None:
                erreurs.append(f"{ou} : clé hors spec « {cle} »")
                continue
            perso = None
            if fam == "trait":
                perso = m[1]
                if m[2] not in TRAITS:
                    erreurs.append(f"{ou} : trait inconnu « {m[2]} » (liste fermée)")
            elif fam in ("vivant", "connait", "relation"):
                perso = m[1]
            if perso and registre:
                if perso not in registre:
                    avis.append(f"{ou} : « {perso} » absent du registre ({cle})")
                elif fam == "vivant" and registre[perso].get("statut") == "canon":
                    erreurs.append(f"{ou} : {cle} sur un personnage canon")

    # 3 à 6 : menus
    occasions = collections.defaultdict(lambda: collections.defaultdict(int))
    deja_vus = set()
    for n in ordre:
        noeud = noeuds[n]
        for typ, g, num in noeud["instr"]:
            cible = g[0] if typ == "saut" else (g[1] if typ in ("choix", "delai") else None)
            if cible and cible != "FIN" and cible not in noeuds:
                erreurs.append(f"{noeud['fichier']}:{num} : cible inconnue « {cible} »")
        for menu in menus(noeud):
            ou = f"{noeud['fichier']}:{menu['ligne']} ({n})"
            if menu["delai"]:
                d = [o for o in menu["options"] if o["cible"] == menu["delai"][1]]
                if not d:
                    # Défaut « quelqu'un parle à sa place » : accepté s'il écrit les mêmes clés qu'une option.
                    cles_defaut = set(cles_branche(noeuds, menu["delai"][1]))
                    if not any(cles_defaut == set(cles_branche(noeuds, o["cible"])) for o in menu["options"]):
                        avis.append(f"{ou} : le défaut minuté vise « {menu['delai'][1]} », qui n'est pas une option du menu et n'en reproduit pas les clés")
                elif all(o["cond"] for o in d):
                    erreurs.append(f"{ou} : l'option par défaut est conditionnelle")
                if menu["delai"][0] < 5:
                    erreurs.append(f"{ou} : minuteur de {menu['delai'][0]} s, sous le minimum de 5 s")
            branches = [cles_branche(noeuds, o["cible"]) for o in menu["options"]]
            listes = [set(b) for b in branches]
            union = set().union(*listes) if listes else set()
            for o, l in zip(menu["options"], listes):
                manque = union - l
                graves = sorted(c for c in manque if famille(c)[0] != "trait")
                legers = sorted(c for c in manque if famille(c)[0] == "trait")
                if graves:
                    erreurs.append(f"{ou} : l'option « {o['texte']} » n'écrit pas {', '.join(graves)} (règle 3.1)")
                if legers:
                    avis.append(f"{ou} : l'option « {o['texte']} » n'écrit pas {', '.join(legers)} (trait absent = +0, toléré)")
            traits_menu = set()
            for b in branches:
                for cle, (op, val) in b.items():
                    fam, m = famille(cle)
                    if fam == "trait" and op == "+=" and val.lstrip("+").isdigit() and int(val) > 0:
                        traits_menu.add(cle)
            # Les variantes d'un même choix (un menu par branche d'un choix précédent) écrivent
            # la même liste de clés : on les compte une seule fois par chapitre.
            groupe = (noeud["fichier"], frozenset(union))
            if groupe in deja_vus:
                continue
            deja_vus.add(groupe)
            for t in traits_menu:
                occasions[t][noeud["fichier"]] += 1

    print("== Occasions par trait (menus qui peuvent l'augmenter ; variantes d'un même choix comptées une fois)")
    for t in sorted(occasions):
        total = sum(occasions[t].values())
        detail = ", ".join(f"{f} {c}" for f, c in sorted(occasions[t].items()))
        marque = ""
        if max(occasions[t].values()) > 3:
            marque = "  <- plus de 3 dans un chapitre"
        print(f"  {t:28} {total:2}  ({detail}){marque}")
    print("   Rappel : 4 à 6 pour le POV principal, 1 à 3 pour un POV d'un chapitre. Les choix pendant le jeu")
    print("   (déclenchés par @jeu, hors menu) ne sont pas comptés : les ajouter à la main.")
    print(f"\n== Erreurs ({len(erreurs)})")
    for e in erreurs:
        print("  " + e)
    print(f"\n== Avis ({len(avis)})")
    for a in avis:
        print("  " + a)
    sys.exit(1 if erreurs else 0)


if __name__ == "__main__":
    main()
