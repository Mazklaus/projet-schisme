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


if __name__ == "__main__":
    unittest.main()
