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
2. **Le champ après la fête.** Trois points d'intérêt facultatifs : l'étendard, les deux frères et Ilse. Une invite « E : regarder » apparaît à moins de 160 px. Si le joueur traîne, Dremm le relance au vox au bout de 30 s.
3. **L'éboulement.** Il se produit derrière Vaskar quand il a dépassé le poste de l'Armée (x > 2980), ou au plus tard 50 s après le début du jeu. Viennent ensuite « … ici » et le rappel de Dremm au vox, affichés en surimpression sans arrêter le jeu.
4. **La QTE.** Près de la poutre, maintenir E fait monter la poutre, qui tremble ; la jauge se remplit en 1,4 s. Le **choix minuté de 8 s** s'ouvre ensuite (barre de temps). Le silence vaut « obéir ». Rejoindre la bannière de la 27e sans s'arrêter, ou ne rien faire pendant 20 s après le rappel, vaut aussi « obéir ».
5. **Ciné de fin**, avec les variantes de 5a, 5e et 5f selon le choix. La partie est sauvegardée au début de la ciné de fin.

| Choix | `choix_ullanor` | `soldate_vivante` | `relation_dremm` | `relation_ilse` | Trait | Écho |
|---|---|---|---|---|---|---|
| La sortir | 1 | vrai | −1 | +2 | `trait_compassion` +1 | Elle s'en souviendra. |
| Appeler des auxiliaires | 2 | vrai (`soldate_connait_sauveur` faux) | 0 | 0 | | Personne ne saura qui l'a sauvée. |
| Obéir, ou silence | 3 | faux | +1 | 0 (sans objet) | `trait_obeissance` +1 | Le capitaine s'en souviendra. |

Les relations sont bornées de −3 à +3. Elles sont sauvegardées dans `user://sauvegardes/emplacement_0.json`, sous `drapeaux`.

## Placeholders

Les personnages et objets du bivouac, le décor du bivouac, les silhouettes de l'Empereur et d'Horus dans l'ouverture et le gros plan d'Horus sont générés par `tools/placeholders/generer_tranche_ullanor.py`. Il suffit de les remplacer en gardant le même nom de fichier (`assets/tranche_ullanor/props/<nom>.png` et `_normal.png`).

Pas encore fait : le son et la musique (rien n'est branché) et le hochement de tête de Dremm en 5a. Ce dernier attend des calques de personnages découpés.

## Tests automatiques

- `tests/unit/test_tranche_ullanor.gd` vérifie les critères QA : le choix minuté de 8 s, le silence qui vaut obéir, le tableau de mémoire, les échos et les variantes, la sauvegarde, la fidélité au script et les 3 points d'intérêt.
- `tools/ci/parcours_ullanor.gd` joue la tranche de bout en bout et vérifie la sauvegarde :

```
godot --headless -s res://tools/ci/parcours_ullanor.gd -- --choix=sortir        # ou auxiliaires, obeir, silence, rassemblement, inaction
godot --headless -s res://tools/ci/parcours_ullanor.gd -- --choix=obeir --flaner --sans-poi   # relance vox à 30 s
xvfb-run godot --rendering-driver opengl3 -s res://tools/ci/parcours_ullanor.gd -- --choix=sortir --cine --vitesse=1 --captures=/tmp/captures
```
