"""Tests de tools/ci/verifier_episode.py : python3 -m unittest discover -s tools/ci/tests"""
import json
import os
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import verifier_episode as ve  # noqa: E402


def png(chemin, plat=True, taille=(64, 64)):
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    if plat:
        a = np.zeros((*taille[::-1], 4), np.uint8); a[...] = (90, 80, 70, 255)
    else:
        a = (np.random.default_rng(1).random((*taille[::-1], 4)) * 255).astype(np.uint8); a[..., 3] = 255
    Image.fromarray(a, "RGBA").save(chemin)


def ecrire(chemin, texte):
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    with open(chemin, "w", encoding="utf-8") as f:
        f.write(texte if isinstance(texte, str) else json.dumps(texte))


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.r = self.tmp.name
        ecrire(f"{self.r}/data/personnages.json", {"personnages": {
            "vaskar": {"affiliation": "Luna Wolves"}, "sefa": {"affiliation": "Remembrancers (civile)"}}})
        ecrire(f"{self.r}/data/decors_alias.json", {"salle": {"decor": "salle_reelle"}})
        ecrire(f"{self.r}/data/dialogues/ep09/ch01.dlg", "\n".join([
            "=== debut", "@decor salle", "@ambiance bord 2", "VASKAR: Bonjour.", "-> suite",
            "=== suite", "@decor hangar", "@plan serre:vaskar", "SEFA (ecoute): Oui.", "@plan serre:sefa"]))
        d = f"{self.r}/assets/decors/salle_reelle"
        ecrire(f"{d}/salle_reelle.json", {"cadre_px": [64, 64], "calques": [
            "00_ciel", "10_salle (+normal, +ombre)", "20_table (+normal)", "30_mur", "gabarit_40_personnages"]})
        png(f"{d}/calques/00_ciel.png"); png(f"{d}/calques/10_salle.png"); png(f"{d}/calques/10_salle_normal.png")
        png(f"{d}/calques/20_table.png", plat=False)
        png(f"{d}/calques/gabarit_40_personnages.png")

    def tearDown(self):
        self.tmp.cleanup()

    def analyser(self, **k):
        return ve.analyser("ep09", self.r, **k)


class TestDecors(Base):
    def test_absent_incomplet_alias(self):
        r = self.analyser()
        self.assertEqual([x["nom"] for x in r["absents"]], ["hangar"])
        pts = r["incomplets"][0]["points"]
        self.assertIn("10_salle.png : _ombre annoncée mais absente", pts)
        self.assertIn("20_table.png : _normal annoncé mais absent", pts)
        self.assertIn("30_mur.png : introuvable", pts)
        self.assertFalse(any("gabarit" in p for p in pts))

    def test_a_importer(self):
        ext = f"{self.r}/livraisons"
        ecrire(f"{ext}/hangar/hangar.json", {"cadre_px": [64, 64], "calques": [{"fichier": "calques/10_h.png"}]})
        png(f"{ext}/hangar/calques/10_h.png")
        r = self.analyser(decors_ext=[ext])
        self.assertEqual(r["a_importer"][0]["nom"], "hangar")
        self.assertIn("aucune couche _ombre", r["a_importer"][0]["points"])

    def test_formats_de_calques(self):
        self.assertEqual(ve.calques_declares({"calques": {"a": ["v/10_x (+ombre)"], "b": {"normal": "n"}}}),
                         [("calques/v/10_x.png", False, True), ("calques/b.png", True, False)])


class TestSonEtBustes(Base):
    def test_ambiance(self):
        r = self.analyser()
        self.assertEqual([x["nom"] for x in r["sans_ambiance"]], ["hangar"])
        self.assertEqual(r["ambiances_absentes"][0]["fichier"], "assets/audio/amb_bord.ogg")
        ecrire(f"{self.r}/assets/audio/amb_bord.ogg", "ogg")
        self.assertEqual(self.analyser()["ambiances_absentes"], [])

    def test_bustes(self):
        r = self.analyser()
        self.assertEqual(sorted(x["perso"] for x in r["sans_buste"]), ["sefa", "vaskar"])
        png(f"{self.r}/assets/personnages/vaskar/buste_gauche_neutre.png")
        png(f"{self.r}/assets/personnages/sefa/buste.png")
        r = self.analyser()
        self.assertEqual([(x["perso"], x["livre"]) for x in r["un_seul_cote"]], [("vaskar", "gauche")])
        os.remove(f"{self.r}/assets/personnages/vaskar/buste_gauche_neutre.png")
        png(f"{self.r}/assets/personnages/vaskar/buste.png")
        self.assertEqual(self.analyser()["un_seul_cote"][0]["livre"], "buste unique (miroir interdit)")

    def test_sequencier(self):
        ecrire(f"{self.r}/seq.md", "## Chapitre 1 « a »\n## Chapitre 2 « b »\n")
        self.assertEqual(self.analyser(sequencier=f"{self.r}/seq.md")["chapitres_sans_dlg"], [2])


class TestFinition(Base):
    def test_maquette_puis_peint(self):
        r = self.analyser()
        f = r["scenes"][0]["f"]
        self.assertTrue(f["maquette"])
        self.assertTrue(any(a.startswith("10_salle") for a in f["aplats"]))
        self.assertFalse(any(a.startswith("00_ciel") for a in f["aplats"]))
        ret = f"{self.r}/assets/decors/salle_reelle/calques/10_salle.retouche.json"
        ecrire(ret, {"sortie": "x.png", "date": "2026-11-27T05:00:00", "reglages": {"force": 0.5}})
        f = self.analyser()["scenes"][0]["f"]
        self.assertTrue(f["maquette"])                           # force < 0,65 : reste maquette
        self.assertGreater(f["pct_ancien"], 0)                   # ancienne courbe : comptée peinte
        ecrire(ret, {"sortie": "x.png", "date": "2026-11-27T05:00:00", "reglages": {"force": 0.7}})
        f = self.analyser()["scenes"][0]["f"]
        self.assertFalse(f["maquette"])
        self.assertGreater(f["pct"], 0)

    def test_style_verifie_sur_la_capture(self):
        cap = f"{self.r}/qa/captures/build"
        ecrire(f"{self.r}/assets/decors/salle_reelle/calques/20_table.retouche.json",
               {"sortie": "x.png", "date": "2026-11-27T05:00:00", "reglages": {"force": 0.7}})
        try:
            ve.CAPTURES = cap
            png(f"{cap}/salle_reelle.png", plat=True, taille=(960, 540))        # en jeu : encore en aplats
            f = self.analyser()["scenes"][0]["f"]
            self.assertTrue(f["maquette"])
            self.assertTrue(any(x.startswith("20_table") for x in f["refuses"]))
            a = np.random.default_rng(2).integers(40, 220, (540, 960, 3)).astype(np.uint8)
            Image.fromarray(a).save(f"{cap}/salle_reelle.png")                 # en jeu : texture partout
            f = self.analyser()["scenes"][0]["f"]
            self.assertEqual(f["refuses"], [])
            self.assertIn("20_table", f["peints_jeu"])
        finally:
            ve.CAPTURES = None

    def test_4k_plus_ancien_que_la_retouche(self):
        d = f"{self.r}/assets/decors/salle_reelle/calques"
        png(f"{d}/4k/10_salle.png")
        os.utime(f"{d}/4k/10_salle.png", (1.7e9, 1.7e9))                       # 2023 : avant la retouche
        ecrire(f"{d}/10_salle.retouche.json", {"sortie": "x.png", "date": "2026-11-27T05:00:00"})
        r = self.analyser()
        self.assertTrue(any("4k/10_salle.png plus ancien" in e for e in r["erreurs"]))
        self.assertEqual(ve.main(["ep09", "--racine", self.r, "--sortie", f"{self.r}/r.md"]), 1)

    def test_4k_resté_en_maquette(self):
        d = f"{self.r}/assets/decors/salle_reelle/calques"
        png(f"{d}/4k/10_salle.png", plat=False, taille=(128, 128))           # 4k différent du 1080
        ecrire(f"{d}/10_salle.retouche.json", {"sortie": "x.png", "date": "2020-01-01T00:00:00"})
        self.assertTrue(any("ne correspond pas" in e for e in self.analyser()["erreurs"]))
        png(f"{d}/4k/10_salle.png", plat=True, taille=(128, 128))            # 4k = 1080 agrandi
        self.assertEqual(self.analyser()["erreurs"], [])

    def test_fini_sans_capture(self):
        p = f"{self.r}/assets/decors/salle_reelle/salle_reelle.json"
        d = json.load(open(p)); d["statut"] = "fini"; ecrire(p, d)
        self.assertTrue(any("sans capture" in e for e in self.analyser()["erreurs"]))
        png(f"{self.r}/qa/captures/salle_reelle_build.png")
        self.assertEqual(self.analyser()["erreurs"], [])

    def test_historique(self):
        h = f"{self.r}/qa/historique_ep09.csv"
        ve.main(["ep09", "--racine", self.r, "--sortie", f"{self.r}/r.md", "--historique", h])
        ve.main(["ep09", "--racine", self.r, "--sortie", f"{self.r}/r.md", "--historique", h])
        lignes = open(h, encoding="utf-8").read().strip().splitlines()
        self.assertEqual(len(lignes), 2)                         # en-tête + une ligne (même build, même jour)
        self.assertIn("| Date | Commit | Peint |", open(f"{self.r}/r.md", encoding="utf-8").read())

    def test_rapport(self):
        md = ve.rapport_md(self.analyser())
        for titre in ("## 1. Décors", "## 2. Ambiances", "## 3. Bustes", "## 4. Finition", "Avancement par scène"):
            self.assertIn(titre, md)


if __name__ == "__main__":
    unittest.main()
