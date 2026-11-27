# Tranche verticale : Ullanor, après le Triomphe

Sources : `script-tv.md` v0.3 (texte figé) et `game-design-tv.md` v0.2. Le texte est dans `data/dialogues/ep01/ullanor.dlg`, la mise en scène dans `scenes/ullanor/tranche_ullanor.gd`, et les plans caméra dans `data/episodes/ep01_ullanor/plans.json`.

## Jouer

Dans le menu, choisir **Nouvelle partie** (ou « Épisode 1 »). Pour aller plus vite, la ligne de commande `projet-schisme -- --nouvelle-partie` lance directement la tranche, sans passer par le menu ; cela marche aussi dans un build exporté.

| Action | Touches |
|---|---|
| Se déplacer | ZQSD ou WASD (selon la position physique des touches), ou les flèches |
| Regarder / soulever (maintenir) | E ou Entrée |
| Avancer le texte | Espace ou clic |
| Moniteur de performance | F3 |

## Déroulé et règles

1. **Ciné d'ouverture**, en 6 plans dans le décor de la DA (`assets/decors/ullanor`, lu tel quel depuis `ullanor.json`).
2. **Le champ après la fête.** Trois points d'intérêt facultatifs : l'étendard, les deux frères et Ilse. Une invite « E : regarder » apparaît à moins de 160 px. Si le joueur n'a pas bougé 4 s après la prise en main, une icône des touches (lettres du clavier du joueur, flèches, stick) apparaît en bas de l'écran ; elle disparaît au premier mouvement et ne revient plus. Après 30 s d'inactivité (sans bouger, la lecture d'un point d'intérêt ne compte pas), Dremm relance le joueur au vox.
3. **L'éboulement.** Il se produit derrière Vaskar, à l'écran, quand il dépasse le poste d'Ilse (x > 2980), sur le chemin de la bannière. Il n'y a plus de coupure à heure fixe. Filet de sécurité : si le joueur reste immobile 30 s de plus après la relance, la caméra glisse jusqu'au poste et l'éboulement se joue sous ses yeux. Il ne se produit jamais hors champ. Au déclenchement, la caméra se recadre entre le poste et Vaskar, qui se fige jusqu'au rappel de Dremm. Viennent ensuite « … ici » et le rappel de Dremm au vox, affichés en surimpression sans arrêter le jeu.
4. **La QTE.** Près de la poutre, maintenir E fait monter la poutre, qui tremble ; la jauge se remplit en 1,4 s. Le **choix minuté de 8 s** s'ouvre ensuite. Aucune option n'est présélectionnée : la première direction (touches ou stick) en sélectionne une, et Entrée seul ne choisit rien. Le temps se lit sur un trait fin qui se consume sous les options, au rythme d'un battement sourd qui accélère (signal `battement(intensite)` de la boîte, son `sfx_choix_battement`). Le silence vaut « obéir ». Rejoindre la bannière de la 27e sans s'arrêter, ou ne rien faire pendant 20 s après le rappel, vaut aussi « obéir ».
5. **Ciné de fin**, avec les variantes de 5a, 5e et 5f selon le choix. La partie est sauvegardée au début de la ciné de fin. Sur le gros plan, une ombre de fumée passe sur le visage d'Horus et laisse le reflet doré allumé (`@fumee`). « LUPERCAL ! » s'incruste sur l'image en ivoire et or, avec un tremblement de caméra (`@clameur`).
6. **Écran de fin** « Ullanor », après un noir franc : une ligne à la 3e personne rappelle le choix de Vaskar (textes du GD dans `RAPPEL_CHOIX`), avec les boutons Rejouer et Quitter. Le jeu ne reboucle plus sur l'ouverture.

| Choix | `choix_ullanor` | `soldate_vivante` | `relation_dremm` | `relation_ilse` | Trait | Écho |
|---|---|---|---|---|---|---|
| La sortir | 1 | vrai | −1 | +2 | `trait_compassion` +1 | Elle s'en souviendra. |
| Appeler des auxiliaires | 2 | vrai (`soldate_connait_sauveur` faux) | 0 | 0 | | Personne ne saura qui l'a sauvée. |
| Obéir, ou silence | 3 | faux | +1 | 0 (sans objet) | `trait_obeissance` +1 | Le capitaine s'en souviendra. |

Les relations sont bornées de −3 à +3. Elles sont sauvegardées dans `user://sauvegardes/emplacement_0.json`, sous `drapeaux`.

## Placeholders

Les personnages et objets du bivouac, le décor du bivouac, les silhouettes de l'Empereur et d'Horus dans l'ouverture et le gros plan d'Horus sont générés par `tools/placeholders/generer_tranche_ullanor.py`. Il suffit de les remplacer en gardant le même nom de fichier (`assets/tranche_ullanor/props/<nom>.png` et `_normal.png`).

Pas encore fait : le son et la musique (rien n'est branché).

Le hochement de tête de Dremm en 5a (`@hochement`) détache automatiquement la tête de son calque plein cadre (`Decor25D.detacher_tete`), du haut de la silhouette jusqu'aux épaules, et la fait pivoter au cou. Rien n'est à préparer côté images.

## Tests automatiques

- `tests/unit/test_tranche_ullanor.gd` vérifie les critères QA : le choix minuté de 8 s, le silence qui vaut obéir, le tableau de mémoire, les échos et les variantes, la sauvegarde, la fidélité au script et les 3 points d'intérêt.
- `tools/ci/parcours_ullanor.gd` joue la tranche de bout en bout et vérifie la sauvegarde :

```
godot --headless -s res://tools/ci/parcours_ullanor.gd -- --choix=sortir        # ou auxiliaires, obeir, silence, rassemblement, inaction
godot --headless -s res://tools/ci/parcours_ullanor.gd -- --choix=obeir --flaner --sans-poi   # relance vox à 30 s
godot --headless -s res://tools/ci/parcours_ullanor.gd -- --choix=silence --immobile --sans-poi   # invite, relance, éboulement montré
xvfb-run godot --rendering-driver opengl3 -s res://tools/ci/parcours_ullanor.gd -- --choix=sortir --cine --vitesse=1 --captures=/tmp/captures
```
