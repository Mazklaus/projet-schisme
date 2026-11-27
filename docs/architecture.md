# Architecture du squelette (Godot 4.7.2, 2.5D, PC natif)

Lead Programmer, 18/11/2026. Ce squelette ne contient que des placeholders. La tranche verticale (Ullanor) viendra s'y brancher.

## Arborescence

| Dossier | Contenu |
|---|---|
| `src/core/` | Autoloads `Sauvegarde`, `Catalogue`, `Jeu` ; base de scène `Chapitre` |
| `src/decor/` | `Decor25D` : calques peints en parallaxe, éclairés grâce à leurs normales |
| `src/camera/` | `CameraCine` : plans de cinématique (position, zoom, courbe, tremblement) |
| `src/dialogue/` | `FormatDialogue` (analyse des `.dlg`) et `LecteurDialogue` (exécution pas à pas) |
| `src/ui/` | `BoiteDialogue` (texte en machine à écrire, choix, choix minutés), menu principal |
| `src/perf/` | `BudgetPerf` (seuils) et moniteur en jeu (F3) |
| `data/episodes/<id>/` | `episode.json` (liste des chapitres) et fichiers de plans caméra |
| `data/dialogues/` | Dialogues `.dlg`, écrits par la narration |
| `assets/decors/<id>/` | Calques, normales et `decor.json` produits par la chaîne d'images (Tools) |
| `scenes/` | Scènes `.tscn` (démo, menu) |
| `tools/ci/` | Vérification des décors, parcours automatique de la démo |
| `src/jeu/` | Personnage joué (déplacement 2.5D) |
| `scenes/ullanor/` | Tranche verticale d'Ullanor, voir [tranche-ullanor.md](tranche-ullanor.md) |
| `tests/unit/` | Tests GUT |

## Décor 2.5D : le contrat avec la chaîne d'images

Le format est défini dans `assets/decors/<id>/decor.json`. Il est documenté en tête de `src/decor/decor_25d.gd` et vérifié par `tools/ci/verifier_decors.py`.

- Calques nommés `<NN>_<nom>.png`, où NN donne l'ordre de dessin.
- Normales facultatives dans `<NN>_<nom>_n.png`, de même taille que le calque. Elles sont en espace tangent OpenGL (Y vers le haut).
- `profondeur` règle la parallaxe : 0 garde le calque fixe à l'écran, 1 le fait suivre la caméra, et une valeur au-dessus de 1 le place au premier plan.
- `position` est facultative. Elle sert à poser une figure détourée sans qu'elle occupe toute la taille du décor.
- `lumiere` vaut `false` pour un ciel qui ne doit pas recevoir les lumières.
- Cadre de référence : la composition est exacte quand la caméra est centrée sur le décor au zoom 1.

Le moteur lit aussi tel quel le format du guide de style de la DA (`guide-de-style.md`, §6), sans conversion préalable : le `<plan>.json` qui contient `cadre_px` (par exemple `ullanor.json`). Dans ce format :

- `distance_m` donne la parallaxe en 1/d, et le calque le plus proche sert de référence (profondeur 1). On peut forcer la référence avec `distance_reference_m`.
- Un calque sans distance est soit le ciel (`00_…`, fixe), soit des particules (au premier plan). Ni l'un ni l'autre n'est éclairé.
- Les fichiers `<nom>_normal.png` et `<nom>_ombre.png` (en multiplication) sont repris automatiquement.
- Le `voile` (couleur, `d0_m`) est appliqué par un shader, avec t = 1 − exp(−d/d0), comme dans `assembler.py`.
- Un calque absent est ignoré, avec un avertissement.

Pour comparer avec l'assemblage de la DA, `tools/ci/capture_decor.gd` rend un décor tel que le moteur l'affiche.

L'éclairage passe par des `PointLight2D` ou `DirectionalLight2D` placées dans la scène, avec un `CanvasModulate` pour l'ambiance. Les normales donnent le relief.

## Dialogues (`.dlg`)

La syntaxe complète est en tête de `src/dialogue/format_dialogue.gd`. En bref :

```
=== noeud
CAPITAINE (froid): Tiens ta position.
> Narration.
* Aider -> aider
* Obéir -> obeir [si relation_capitaine >= 1]
*! 8 -> obeir            // choix minuté : sans réponse en 8 s, le silence vaut obéir
~ relation_capitaine += 1
@plan eboulement         // commande exécutée par la scène
@carton 2.5 Ullanor.
-> FIN
```

Commandes gérées par `Chapitre` : `@plan` (avec `&` en dernier argument, la commande n'est pas attendue), `@attendre`, `@lumiere`, `@carton`, `@titre`, `@montrer`, `@cacher`, `@fondu`, `@teinte`, `@echelle`, `@sauver`, `@fin`. Une réplique `NOM (vox):` s'affiche en italique, avec la mention « (vox) ». Un chapitre ajoute les siennes en surchargeant `_commande_specifique`.

Les drapeaux vivent dans la sauvegarde (`Jeu.etat.drapeaux`) et restent partagés entre les épisodes.

Les clés suivent `etude-heresie/systeme-de-choix.md` : `choix_epNN_<lieu>`, `vivant_<perso>`, `connait_<perso>_<fait>`, `relation_<perso>` (de −3 à +3), `trait_<perso>_<nom>` (de 0 à 10, liste fermée de 5 traits) et `epNN_<sujet>` pour les clés locales. Le lecteur borne relations et traits. Il refuse d'écrire `vivant_<perso>` pour un personnage `canon` du registre `data/personnages.json` (`Personnages`). `tools/ci/verifier_cles.py` contrôle en CI toutes les clés écrites par les `.dlg`. Sans sauvegarde importée, un épisode part de `data/episodes/<id>/etat_defaut.json`, chargé par `Jeu.nouvelle_partie`.

## Épisodes

Chaque épisode est un dossier dans `data/episodes/` contenant un `episode.json`. Les épisodes livrés après coup prennent la forme de paquets `.pck`, déposés dans `episodes/` à côté de l'exécutable et montés au démarrage par `Catalogue`.

## Sauvegarde versionnée

Il y a 6 emplacements, chacun stocké en JSON dans `user://sauvegardes/`. L'écriture est atomique (fichier temporaire, puis renommage).

Pour changer le format, il faut incrémenter `Sauvegarde.VERSION` et ajouter une méthode `_migrer_vers_<N>`. Une migration déjà livrée ne doit jamais être modifiée. Une sauvegarde plus récente que le jeu est refusée. Version 2 : renommage des clés de la tranche (`choix_ullanor` → `choix_ep01_ullanor`, `soldate_vivante` → `vivant_ilse`, `soldate_connait_sauveur` → `connait_ilse_sauveur`). Version 3 : traits propres à chaque personnage joué (`trait_<nom>` → `trait_vaskar_<nom>`).

## Budget de performance

Les seuils sont dans `src/perf/budget.gd`. La machine de référence est de classe GTX 1060 ou RX 580, en 1080p, avec une cible de 60 images/s.

| Mesure | Seuil |
|---|---|
| Temps d'image | 16,6 ms |
| Textures par décor | 256 Mio |
| Côté maximal d'un calque | 8192 px |
| Calques par décor | 16 |
| Lumières 2D par scène | 8 |
| Appels de dessin par image | 1000 |

Les décors du dépôt sont vérifiés par les tests. Le moniteur F3 affiche les compteurs en jeu.

## Lancer

```
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit   # tests
godot --headless -s res://tools/ci/parcours_demo.gd -- --choix=attendre              # démo de bout en bout
python3 tools/placeholders/generer_decor_demo.py                                    # régénère le décor de démo
```
