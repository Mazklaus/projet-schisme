# Suivi de production (QA)

Rapports de `tools/ci/verifier_episode.py` : liste de travail par épisode (décors, ambiances son, bustes, finition visuelle).
La CI les régénère pour chaque épisode de `data/dialogues/` (résumé de la CI et artefact `suivi-production`).

- `suivi_ep01.md` : épisode 1, données du dépôt.
- `suivi_ep02.md` : épisode 2, lancé hors CI sur les sources du projet (répliques, séquencier et décors de CA2
  pas encore importés dans le dépôt) :

      E=/mnt/project-files/etude-heresie/episode-02
      python3 tools/ci/verifier_episode.py ep02 --dlg $E --sequencier $E/ep02-sequenciers.md --decors $E --sortie qa/suivi_ep02.md --historique qa/historique_ep02.csv

- `historique_<ep>.csv` : une ligne datée par exécution locale avec `--historique` (% peint, % animé, % fini,
  points ouverts), pour suivre la courbe ; la CI y ajoute la ligne du build dans son artefact.
- `captures/<décor>*.png` : captures en jeu. Un décor au statut « fini » sans capture fait échouer la CI.

## Captures automatiques (à chaque build)

```
python3 tools/capturer_episode.py ep01 --godot ~/godot/godot
```

Le jeu tourne sans fenêtre (xvfb-run, opengl3) et rend, avec le moteur du jeu, chaque scène dans chacun
de ses états (jour, nuit, aube…), chaque `@plan` des .dlg (caméra en fin de séquence) et chaque gros
plan (fond + buste, un cadre par personnage). Sortie dans `qa/captures/<date>_<commit>/` : une image
par cadre, `planche_NN.jpg` (avant | après contre la build précédente, changés et nouveaux en tête),
`rapport.md` (échecs, cadres non capturables, disparus) et `index.json`. Environ 4 min 30 pour ep01.

Les dossiers de build restent locaux (ignorés par git). Quand la DA valide un décor sur une capture,
elle la garde, ce qui la versionne et permet le statut « fini » :

```
python3 tools/capturer_episode.py ep01 --garder orvane_rues__nuit orvane_rues__aube
```

Options : `--liste` (cadres prévus, sans rendu), `--seulement 'orvane_*'`, `--reference <build>`,
`--build <nom>`, `--png`.
