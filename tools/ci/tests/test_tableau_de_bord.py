"""Tests de tools/tableau_de_bord.py : détection des commits qui touchent l'épisode."""
import importlib.util
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

OUTIL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tableau_de_bord.py")
spec = importlib.util.spec_from_file_location("tableau_de_bord", OUTIL)
tdb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tdb)


class TestToucheEpisode(unittest.TestCase):
    def test_commits_de_l_episode_seulement(self):
        with tempfile.TemporaryDirectory() as d:
            r = Path(d)

            def g(*a):
                return subprocess.run(["git", "-C", d, *a], capture_output=True, text=True, check=True).stdout.strip()

            def commit(chemin, msg):
                p = r / chemin
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(msg)
                g("add", "-A")
                g("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", msg)
                return g("rev-parse", "HEAD")

            g("init", "-q")
            base = commit("README.md", "debut")
            commit("data/dialogues/ep02/ch01.dlg", "ep02 seulement")
            self.assertEqual(tdb.touche_episode(r, base, "ep01"), [])
            commit("data/episodes/ep01_ullanor/plans.json", "plans tranche")
            commit("assets/decors/archive/a.json", "decor")
            vus = tdb.touche_episode(r, base, "ep01")
            self.assertEqual([l.split(" ", 1)[1] for l in vus], ["decor", "plans tranche"])
            self.assertIsNone(tdb.touche_episode(r, "0" * 40, "ep01"))
            self.assertIsNone(tdb.touche_episode(r, None, "ep01"))


if __name__ == "__main__":
    unittest.main()
