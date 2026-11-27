"""Tests de tools/finir_decor.py avec un faux retoucheur (aucun modèle chargé)."""
import json
import os
import subprocess
import sys
import tempfile
import unittest

from PIL import Image

ICI = os.path.dirname(os.path.abspath(__file__))
OUTIL = os.path.join(ICI, "..", "..", "finir_decor.py")
FAUX = '''import sys, json, os
from PIL import Image, ImageOps
e, s = sys.argv[1], sys.argv[2]
im = Image.open(e).convert("RGBA"); r, g, b, a = im.split()
Image.merge("RGBA", (*ImageOps.invert(Image.merge("RGB", (r, g, b))).split(), a)).save(s)
json.dump({"entree": e, "sortie": s, "date": "2026-11-27T10:00:00", "reglages": {"argv": sys.argv[3:]},
           "statut": "essai"}, open(os.path.splitext(s)[0] + ".retouche.json", "w"))
'''


class TestFinirDecor(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = self.tmp.name
        self.d = os.path.join(t, "salle")
        os.makedirs(os.path.join(self.d, "calques", "4k"))
        json.dump({"cadre_px": [32, 18], "calques": ["00_ciel", "10_salle (+normal)"],
                   "retouche": {"defaut": {"force": 0.5}, "calques": {"10_salle": {"preset": "nef"}}}},
                  open(os.path.join(self.d, "salle.json"), "w"))
        for n, taille in (("00_ciel", (32, 18)), ("10_salle", (32, 18)), ("4k/10_salle", (64, 36))):
            Image.new("RGBA", taille, (200, 100, 50, 255)).save(os.path.join(self.d, "calques", n + ".png"))
        self.faux = os.path.join(t, "faux.py")
        open(self.faux, "w").write(FAUX)

    def tearDown(self):
        self.tmp.cleanup()

    def lancer(self, *args):
        env = dict(os.environ, RETOUCHER=self.faux)
        return subprocess.run([sys.executable, OUTIL, self.d, "--sans-peinture", *args], env=env,
                              capture_output=True, text=True)

    def test_retouche_4k_puis_1080_et_restauration(self):
        r = self.lancer()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("--preset nef", r.stdout)                      # réglages du bloc « retouche » du décor
        self.assertIn("--force 0.5", r.stdout)
        c = os.path.join(self.d, "calques")
        self.assertEqual(Image.open(f"{c}/4k/10_salle.png").getpixel((0, 0))[:3], (55, 155, 205))
        self.assertEqual(Image.open(f"{c}/10_salle.png").size, (32, 18))
        self.assertEqual(Image.open(f"{c}/10_salle.png").getpixel((0, 0))[:3], (55, 155, 205))
        fiche = json.load(open(f"{c}/10_salle.retouche.json"))
        self.assertEqual(fiche["sortie"], "calques/10_salle.png")
        self.assertFalse(os.path.exists(f"{c}/00_ciel.retouche.json"))   # ciel : pas de retouche
        self.assertTrue(os.path.isfile(f"{c}/_maquette/4k/10_salle.png"))
        self.lancer()                                                    # relancer repart de la maquette
        self.assertEqual(Image.open(f"{c}/10_salle.png").getpixel((0, 0))[:3], (55, 155, 205))
        subprocess.run([sys.executable, OUTIL, self.d, "--restaurer"], check=True, capture_output=True)
        self.assertEqual(Image.open(f"{c}/10_salle.png").getpixel((0, 0))[:3], (200, 100, 50))
        self.assertFalse(os.path.exists(f"{c}/10_salle.retouche.json"))

    def test_reprise_d_une_retouche_choisie(self):
        choix = os.path.join(self.tmp.name, "fond")
        os.makedirs(choix)
        Image.new("RGBA", (32, 18), (10, 20, 30, 255)).save(os.path.join(choix, "10_salle_g62.png"))
        json.dump({"statut": "fige", "choix": "DA"}, open(os.path.join(choix, "10_salle_g62.retouche.json"), "w"))
        r = self.lancer("--retouche-de", choix, "--graine", "62")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertNotIn("faux.py", r.stdout)                            # aucune retouche relancée
        c = os.path.join(self.d, "calques")
        self.assertEqual(Image.open(f"{c}/4k/10_salle.png").size, (64, 36))   # 1080 choisi, remonté en 4k
        self.assertEqual(Image.open(f"{c}/10_salle.png").getpixel((0, 0))[:3], (10, 20, 30))
        fiche = json.load(open(f"{c}/10_salle.retouche.json"))
        self.assertEqual((fiche["statut"], fiche["sortie"]), ("fige", "calques/10_salle.png"))


if __name__ == "__main__":
    unittest.main()


class TestGardeFouFini(unittest.TestCase):
    def test_statut_fini_ramene_a_peint(self):
        import importlib.util
        from pathlib import Path
        spec = importlib.util.spec_from_file_location("finir_decor", OUTIL)
        finir_decor = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(finir_decor)
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)
            (p / "decor.json").write_text('{"statut": "fini (DA)", "calques": []}', encoding="utf-8")
            (p / "autre.json").write_text('{"statut": "peint"}', encoding="utf-8")
            self.assertEqual(finir_decor.retirer_fini(p), ["decor.json"])
            self.assertEqual(json.loads((p / "decor.json").read_text())["statut"], "peint")
            self.assertEqual(json.loads((p / "autre.json").read_text())["statut"], "peint")
