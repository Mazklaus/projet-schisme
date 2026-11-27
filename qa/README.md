# Suivi de production (QA)

Rapports de `tools/ci/verifier_episode.py` : liste de travail par épisode (décors, ambiances son, bustes, finition visuelle).
La CI les régénère pour chaque épisode de `data/dialogues/` (résumé de la CI et artefact `suivi-production`).

- `suivi_ep01.md` : épisode 1, données du dépôt.
- `suivi_ep02.md` : épisode 2, lancé hors CI sur les sources du projet (répliques, séquencier et décors de CA2
  pas encore importés dans le dépôt) :

      E=/mnt/project-files/etude-heresie/episode-02
      python3 tools/ci/verifier_episode.py ep02 --dlg $E --sequencier $E/ep02-sequenciers.md --decors $E --sortie qa/suivi_ep02.md

- `captures/<décor>*.png` : captures en jeu. Un décor au statut « fini » sans capture fait échouer la CI.
