# Sources des sons

**Aucun fichier tiers.** Tous les sons de ce dossier sont calculés par synthèse dans
`tools/son/generer_ullanor.py` (Python, numpy, scipy), à graine fixe : la même commande redonne
les mêmes .wav. Aucun échantillon, aucune banque de sons, aucune voix enregistrée ou synthétisée
(le jeu est sans voix : les chœurs et la foule sont des voyelles tenues, sans mots).
Licence : produits par l'équipe pour le projet. Aucun son CC0 n'est utilisé pour l'instant ; s'il en
entrait un, il serait listé ici avec son auteur, son URL et sa licence.

Régénérer :

```
python3 tools/son/generer_ullanor.py /tmp/wav
python3 tools/son/encoder_ogg.py /tmp/wav assets/audio
godot --headless --import
```

| Fichier | Fonction du générateur | Graine | Où il sonne | Ce que c'est |
|---|---|---|---|---|
| `mus_ullanor_triomphe` | `mus_triomphe` | 1001 | 1c (clameur) | Boucle de 38 s : hymne lumineux en ré majeur (I–IV–I–V–vi–IV–V4-3–I), plein jeu d'orgue, chœur, cuivres larges, ligne de chant qui monte à la tonique, 50 à la noire |
| `mus_ullanor_attente` | `mus_attente` | 1002 | 1d à 1f | Boucle de 30 s : bourdon d'orgue ré–la, chœur voilé, couleur napolitaine non résolue |
| `mus_ullanor_horus` | `mus_horus` | 1003 | 5b–5c | Boucle de 20 s : la note tenue (ré à l'unisson et à l'octave : orgue, chœur, cuivre grave) |
| `amb_ullanor_triomphe` | `amb_triomphe` | 2001 | 1a, 1c | Boucle de 40 s : tambours de défilé lointains, des millions de pas, armures, vent |
| `amb_ullanor_vent` | `amb_vent` | 2002 | 1b, ciné de fin | Boucle de 30 s : vent et poussière sur la plaine, sans foule |
| `amb_ullanor_bivouac` | `amb_bivouac` | 2003 | jeu (bivouac) | Boucle de 60 s : vent, feux de camp, outils sur le métal, moteur au ralenti, un tambour très loin |
| `sfx_clameur_maitre` | `sfx_clameur_maitre` | 3001 | 1c–1d | La plaine exulte (vagues de joie, armes levées) ; à 1d, environ 3,2 s plus tard, la clameur retombe, inquiète (16 s avec la réverbération) |
| `sfx_clameur_lupercal` | `sfx_clameur_lupercal` | 3002 | 5d | La Légion scande en trois temps (LU-PER-CAL) : trois frappes de poings sur les plastrons et trois cris de gorge sur u, e, a, sans syllabes articulées ; le dernier tient |
| `sfx_vox_crepite_01`, `sfx_vox_crepite_02`, `sfx_vox_crepite_03` | `sfx_vox_crepite` | 3010–3012 | lignes vox de Dremm | Clic de micro et parasites en bande étroite |
| `sfx_eboulement` | `sfx_eboulement` | 3020 | 3 (éboulement) | Le métal hurle, le choc, les débris, puis le silence |
| `sfx_poutre_grince` | `sfx_poutre_grince` | 3030 | QTE et choix | Boucle de 2 s, collé-glissé de l'acier ; volume et hauteur suivent la jauge |
| `sfx_choix_tic` | `sfx_choix_tic` | 3040 | choix minuté | Tic sourd à chaque seconde (signal `delai_seconde` de la boîte) |
| `sfx_choix_battement_01`, `sfx_choix_battement_02` | `sfx_choix_battement` | 3050–3051 | choix minuté | Coup sourd comme un cœur sous l'armure, 0,3 s ; la boîte le rapproche de 1 s à 0,35 s (signal `battement`) |
| `amb_nef_imperiale` | `amb_nef` | 2004 | décor test de la nef (épisodes suivants) | Boucle de 60 s : pierre immense, air, machines du palais sous le dallage, bannières dans un courant d'air, pas lourds et porte de bronze lointains (réverbération de 8 s), chant grave des salles voisines |

### Épisode 1 : palette (`tools/son/generer_ep01.py`, qui reprend les instruments de `generer_ullanor.py`)

```
python3 tools/son/generer_ep01.py /tmp/wav_ep01
python3 tools/son/encoder_ogg.py /tmp/wav_ep01 assets/audio
```

| Fichier | Fonction du générateur | Graine | Où il sonne | Ce que c'est |
|---|---|---|---|---|
| `mus_ep01_luna_wolves` | `mus_luna_wolves` | 4001 | épisode 1, thème de la Légion | Boucle de 58 s : sol mixolydien, deux cors à l'unisson (la fraternité), quintes à vide, timbales ; la reprise ajoute l'octave, le chœur et un tambour discret ; la phrase finit sur la quinte, ouverte |
| `mus_ep01_horus` | `mus_horus_motif` | 4002 | épisode 1, motif d'Horus | Boucle de 19 s : ré – la – ré – do# – ré au cor grave et au chœur sur un ré majeur d'orgue ; à la reprise, le do# glisse sur do naturel et y reste (la note qui doute) |
| `amb_ep01_cthonia` | `amb_cthonia` | 4003 | flash-backs, tunnels de Cthonia | Boucle de 45 s : roche, gouttes, vapeur dans les conduites, pilon de mine lointain (1 coup / 1,5 s), étais qui travaillent, coups sourds dans une galerie voisine ; espace étroit et sombre |

### Épisode 2 et 3 : Vengeful Spirit (`tools/son/generer_ep02.py`, mêmes outils que `generer_ullanor.py`)

```
python3 tools/son/generer_ep02.py /tmp/wav_ep02
python3 tools/son/encoder_ogg.py /tmp/wav_ep02 assets/audio
```

| Fichier | Fonction du générateur | Graine | Où il sonne | Ce que c'est |
|---|---|---|---|---|
| `amb_ep02_vengeful_spirit` | `amb_vengeful_spirit` | 5001 | chapitres 2 et 3, le vaisseau à l'état pur | Boucle de 60 s : cœur du vaisseau (harmoniques stables de 32 Hz), air dans les gaines, relais régulier, escouade qui passe en cadence, sas lourds, machines des ponts inférieurs ; réverbération de cathédrale (6,5 s) |
| `amb_ep02_loge` | `amb_loge` | 5002 | chapitres 2 et 3, la salle de la loge | Boucle de 45 s, veillée chaleureuse : conversations graves et inintelligibles de cinq frères (syllabes voisées sans mots, filtrées), gobelets posés sur la caisse-table, un rire bref de temps en temps, bougies qui grésillent, cœur du vaisseau étouffé ; rien d'occulte, aucun mot |
