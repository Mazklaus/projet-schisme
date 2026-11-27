"""Tests de tools/capturer_episode.py (inventaire, planche avant/après, --garder), sans Godot."""
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path

from PIL import Image

OUTIL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "capturer_episode.py")
spec = importlib.util.spec_from_file_location("capturer_episode", OUTIL)
ce = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ce)


def ecrire(p, contenu):
    p = Path(p)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(contenu if isinstance(contenu, str) else json.dumps(contenu), encoding="utf-8")


class TestInventaire(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        r = self.r = Path(self.tmp.name)
        ecrire(r / "data/decors_alias.json", {"rue_matin": {"decor": "rue", "etat": "matin"}})
        ecrire(r / "data/episodes/ep9/episode.json", {"chapitres": [
            {"id": "c01", "plans": "res://data/episodes/ep9/plans.json", "jeu": "res://data/episodes/ep9/c01_jeu.json"}]})
        ecrire(r / "data/episodes/ep9/plans.json", {
            "_note": "x",
            "vue": [{"position": [100, 100], "zoom": 1.0, "duree": 0}, {"position": [300, 200], "zoom": 1.5, "duree": 2}],
            "dehors": {"decor": "cour", "textures": {"Calque_a": "calques/b.png"},
                       "sequence": [{"position": [10, 20], "zoom": 2.0, "duree": 0}]}})
        ecrire(r / "data/episodes/ep9/c01_jeu.json", {"zones": {"z1": {"decor": "cave"}}})
        ecrire(r / "data/episodes/ep9/gros_plans.json", {"scenes": [
            {"chapitre": "c01", "decor": "rue_gros_plan", "cotes": {"ANA": "gauche", "BOB": "droite"}}]})
        ecrire(r / "data/dialogues/ep9/ch01.dlg",
               "=== debut\n@decor rue_matin\n@plan vue\n@plan serre:ana\n@plan inconnu\n=== suite\n@plan dehors\n")
        ecrire(r / "assets/decors/rue/rue.json", {"calques": [], "etats": {"nuit": {}, "matin": {}}})
        ecrire(r / "assets/decors/cour/cour.json", {"calques": []})
        ecrire(r / "assets/decors/rue_gros_plan/rue_gros_plan.json",
               {"calques": [{"fichier": "a.png", "etat": "nuit"}, {"fichier": "b.png", "etat": "aube"}]})
        Image.new("RGBA", (4, 4)).save(self._buste("ana", "buste_gauche_neutre.png"))

    def _buste(self, perso, nom):
        d = self.r / "assets/personnages" / perso
        d.mkdir(parents=True, exist_ok=True)
        return d / nom

    def tearDown(self):
        self.tmp.cleanup()

    def test_scenes_etats_plans_gros_plans(self):
        travaux, manques = ce.inventaire("ep9", self.r)
        ids = {t["id"]: t for t in travaux}
        # chaque état du décor, alias résolu
        self.assertIn("rue__nuit", ids)
        self.assertIn("rue__matin", ids)
        self.assertIn("cour", ids)
        # plan liste : décor courant (alias) et caméra en fin de séquence
        vue = ids["rue__plan_vue"]
        self.assertEqual((vue["decor"], vue["etat"]), ("rue", "matin"))
        self.assertEqual(vue["camera"], {"position": [300, 200], "zoom": 1.5})
        # plan objet : son propre décor et ses textures
        self.assertEqual(ids["cour__plan_dehors"]["textures"], {"Calque_a": "calques/b.png"})
        # gros plan : un cadre par état du fond, seulement pour les bustes livrés
        self.assertIn("rue_gros_plan__ana__nuit", ids)
        self.assertIn("rue_gros_plan__ana__aube", ids)
        self.assertFalse(any("bob" in i for i in ids))
        self.assertTrue(any("BOB" in m for m in manques))
        self.assertTrue(any("inconnu" in m for m in manques))
        self.assertTrue(any("cave" in m and "absent" in m for m in manques))


class TestPlanche(unittest.TestCase):
    def test_avant_apres_et_garder(self):
        with tempfile.TemporaryDirectory() as d:
            cap = Path(d) / "qa" / "captures"
            a, b = cap / "20261127-1000_aaa", cap / "20261127-1100_bbb"
            a.mkdir(parents=True)
            b.mkdir(parents=True)
            Image.new("RGB", (1920, 1080), (40, 40, 40)).save(a / "rue.jpg")
            Image.new("RGB", (1920, 1080), (40, 40, 40)).save(b / "rue.jpg")
            Image.new("RGB", (1920, 1080), (10, 10, 10)).save(a / "cour.jpg")
            Image.new("RGB", (1920, 1080), (200, 90, 10)).save(b / "cour.jpg")
            Image.new("RGB", (1920, 1080), (90, 90, 90)).save(b / "cave.jpg")
            Image.new("RGB", (1920, 1080), (90, 90, 90)).save(a / "vieux.jpg")
            (a / "index.json").write_text("{}")
            self.assertEqual(ce.build_precedente(cap, b.name), a.name)
            statut, disparus = ce.planche(b, ["rue", "cour", "cave"], a)
            self.assertEqual(statut["rue"][0], "identique")
            self.assertEqual(statut["cour"][0], "changé")
            self.assertEqual(statut["cave"][0], "nouveau")
            self.assertEqual(disparus, ["vieux"])
            self.assertTrue((b / "planche_01.jpg").is_file())
            (b / "index.json").write_text("{}")
            self.assertEqual(ce.garder(cap, None, ["cour"]), 0)  # build la plus récente : bbb
            self.assertEqual(Image.open(cap / "cour.jpg").getpixel((5, 5))[0] > 150, True)
            self.assertEqual(ce.garder(cap, b.name, ["absente"]), 1)


if __name__ == "__main__":
    unittest.main()
