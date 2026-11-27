# Sprites en pied : preparer_sprite.py

À partir du kit Blender de CA1 (`cA1/pied/astartes_pied.py`, `soldat_pied.py`), une commande sort les pièces d'un personnage au format du contrat de rig v1 (`animation/contrat-rig-personnages.md`) :

```
python3 tools/sprites/preparer_sprite.py <perso> --type astartes|humain --travail DIR \
    [--couleurs-de <pied peint de CA1>] [--installer assets/personnages/<perso>/pied]
```

1. `passes_blender.py` lance le script de CA1 tel quel, et rend après chaque `_rgb.png` une passe albédo et une passe de normales monde.
2. `decouper_pied.py` (CA1) découpe les pièces sur l'albédo, avec les pivots et `rig.json`.
3. Les normales de la découpe (tirées de la profondeur) sont remplacées par celles de Blender, en espace caméra, convention OpenGL (Y+), au même cadrage.
4. `--couleurs-de` garde les couleurs peintes de CA1 quand la pièce a le même cadrage (écart toléré : 2 px, recalé).
5. `ombre_contact.png` et la clé `ombre` de `rig.json`.
6. `retouche_commune.json` et `retoucher_pieces.sh` pour TP2 : même graine et mêmes réglages pour toutes les pièces. Les défauts (graine 32, force 0,55, contrôle 0,6, lumière 10, couleur 0,6, fond 8A6A48) sont ceux de la série Ilse v3 acceptée par la DA.
7. `planche_normales.png` : couleur | normales | éclairage rasant, pour contrôle à l'œil.

## Raccord des pièces (appris sur Ilse v3)

Même avec la même graine, des pièces retouchées séparément ne se raccordent pas : chaque passe img2img invente son propre détail. CA1 prend donc la couleur de la **vue complète** retouchée partout où la pièce est visible, et ne garde la retouche de la pièce seule que pour les parties cachées dans la vue complète (sous un bras, derrière la jambe avant).

## Pièces propres à un personnage

Le kit ne produit que les pièces du rig ordinaire. Les pièces dédiées à un geste (`bras_croises`, `mains_graver`, `arme_dos`…) livrées par CA1 dans son `pied/` restent la référence : ne pas écraser ce dossier avec `--installer` si la sortie a moins de pièces que la livraison de CA1.
