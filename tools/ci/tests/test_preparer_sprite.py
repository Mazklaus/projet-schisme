"""Tests de tools/sprites/preparer_sprite.py : conversion des normales et ombre de contact."""
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

OUTIL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "sprites", "preparer_sprite.py")
spec = importlib.util.spec_from_file_location("preparer_sprite", OUTIL)
ps = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ps)


class TestNormales(unittest.TestCase):
    def test_monde_vers_camera_opengl(self):
        # monde : -Y = vers la caméra de CA1, +Z = haut, +X = droite de l'écran
        n = np.array([[[0, -1, 0], [0, 0, 1], [1, 0, 0]]], np.float32) * 0.5 + 0.5
        c = ps.normale_camera(n)
        np.testing.assert_allclose(c[0, 0], [0, 0, 1], atol=1e-6)   # face à la caméra : bleu
        np.testing.assert_allclose(c[0, 1], [0, 1, 0], atol=1e-6)   # vers le haut : Y+ (OpenGL)
        np.testing.assert_allclose(c[0, 2], [1, 0, 0], atol=1e-6)   # vers la droite

    def test_reduction_sans_fuite_du_fond(self):
        c = np.zeros((8, 8, 3), np.float32)
        c[..., 0] = 1                                               # normale vers la droite
        a = np.zeros((8, 8), np.float32)
        a[:, :4] = 1
        n = ps.reduire_normale(c, a, (4, 4))
        self.assertTrue(np.allclose(n[:, 0], [1, 0, 0], atol=1e-3))
        self.assertTrue(np.allclose(np.linalg.norm(n, axis=-1), 1, atol=1e-4))


class TestOmbre(unittest.TestCase):
    def test_ombre_sous_les_pieds(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)
            Image.new("RGBA", (40, 20), (0, 0, 0, 255)).save(p / "pied_avant.png")
            Image.new("RGBA", (30, 20), (0, 0, 0, 255)).save(p / "pied_arriere.png")
            rig = {"pieds": [60, 200], "pieces": {"pied_avant": {"fichier": "pied_avant.png", "pose": [50, 182]},
                                                  "pied_arriere": {"fichier": "pied_arriere.png", "pose": [30, 180]}}}
            o = ps.ombre_contact(p, rig)
            im = np.asarray(Image.open(p / o["fichier"]))
            self.assertEqual(im.shape[2], 4)
            self.assertLessEqual(im[..., 3].max(), 0.75 * 255 + 1)
            self.assertEqual(im[0, 0, 3], 0)                        # bords transparents
            cx = o["pose"][0] + im.shape[1] / 2
            self.assertLess(abs(cx - 60), 15)                        # centrée sous les pieds
            self.assertLess(o["pose"][1], 200)
            self.assertGreater(o["pose"][1] + im.shape[0], 200)


if __name__ == "__main__":
    unittest.main()


class TestPiecesPerdues(unittest.TestCase):
    def test_pieces_dediees_de_ca1_signalees(self):
        import tempfile, json as js
        with tempfile.TemporaryDirectory() as d:
            f = os.path.join(d, "rig.json")
            js.dump({"pieces": {"torse": {}, "bras_croises": {}, "mains_graver": {}}}, open(f, "w"))
            self.assertEqual(ps.pieces_perdues(f, {"pieces": {"torse": {}}}), ["bras_croises", "mains_graver"])
            self.assertEqual(ps.pieces_perdues(os.path.join(d, "absent.json"), {"pieces": {}}), [])

