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
| `mus_ullanor_triomphe` | `mus_triomphe` | 1001 | 1b–1c (entre sur 1b, tient à plein jusqu'à 1d) | Boucle de 25 s : hymne lumineux en ré majeur, 48 à la noire, deux temps par accord ; la première phrase (I–IV–V4-3–I) se pose sur la tonique à 7,5 s, juste au début de 1c, puis vi–IV–V4-3–I ; plein jeu d'orgue, chœur, cuivres larges, ligne au chœur et à la trompette douce |
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
| `amb_archive` | `amb_archive` | 4004 | l'archive (cadre, 017.M31), ch. 1 et 2 | Boucle de 40 s : petite salle fermée la nuit, lampe à huile qui vacille, une page tournée, le bois qui craque ; très calme |
| `amb_ep02_unification` | `amb_unification` | 4005 | ch. 2, flash-back de Krenn (Terra, l'Unification) | Boucle de 45 s : boue et ruines, rafales et tirs isolés lointains avec écho, explosions qui roulent, feu, vent chargé de cendres |

### Épisode 2 et 3 : Vengeful Spirit (`tools/son/generer_ep02.py`, mêmes outils que `generer_ullanor.py`)

```
python3 tools/son/generer_ep02.py /tmp/wav_ep02
python3 tools/son/encoder_ogg.py /tmp/wav_ep02 assets/audio
```

| Fichier | Fonction du générateur | Graine | Où il sonne | Ce que c'est |
|---|---|---|---|---|
| `amb_ep02_vengeful_spirit` | `amb_vengeful_spirit` | 5001 | chapitres 2 et 3, le vaisseau à l'état pur | Boucle de 60 s : cœur du vaisseau (harmoniques stables de 32 Hz), air dans les gaines, relais régulier, escouade qui passe en cadence, sas lourds, machines des ponts inférieurs ; réverbération de cathédrale (6,5 s) |
| `amb_ep02_loge` | `amb_loge` | 5002 | chapitres 2 et 3, la salle de la loge | Boucle de 45 s, veillée chaleureuse : conversations graves et inintelligibles de cinq frères (syllabes voisées sans mots, filtrées), gobelets posés sur la caisse-table, un rire bref de temps en temps, bougies qui grésillent, cœur du vaisseau étouffé ; rien d'occulte, aucun mot |

### Épisode 1, chapitres 3 à 5 : barge et Orvane (`tools/son/generer_ep01_ch3_5.py`, mêmes outils)

```
python3 tools/son/generer_ep01_ch3_5.py /tmp/wav_ch35
python3 tools/son/encoder_ogg.py /tmp/wav_ch35 assets/audio
```

| Fichier | Fonction du générateur | Graine | Où il sonne | Ce que c'est |
|---|---|---|---|---|
| `amb_ep03_barge_pont` | `amb_barge_pont` | 6001 | ch. 3, pont d'embarquement (`barge_pont_embarquement`) | Boucle de 50 s : hangar immense, turbines de navette qui retombent, hydraulique, métal chaud qui cliquette, grue, serfs au loin (voix sans mots) |
| `amb_ep03_barge` | `amb_barge` | 6002 | ch. 3 à 5, intérieur de la barge (`barge_quartiers_27`, `barge_galerie`, `barge_briefing`) | Boucle de 50 s : moteurs proches, ventilation, relais toutes les 1,25 s, tuyaux qui travaillent, pas dans une coursive voisine |
| `amb_ep03_quartiers_civils` | `amb_quartiers_civils` | 6003 | ch. 3, quartiers des remembrancers (`barge_quartiers_civils`) | Boucle de 45 s : conversations d'hommes et de femmes sans mots, plume, papier, tasses, rires, la barge assourdie |
| `amb_ep03_cabine` | `amb_cabine` | 6004 | ch. 3 et 5, Sefa la nuit, quartiers du codicier (`barge_quartiers_codicier`) | Boucle de 40 s : cabine close, barge étouffée, aération ; rien d'étrange (le frisson du codicier passe par ses yeux) |
| `amb_ep04_orvane_nuit` | `amb_orvane_nuit` | 6005 | ch. 4, approche et émissaire (`orvane_nuit`) | Boucle de 50 s : cité-ruche humaine la nuit, grondement de la ville, sirène lointaine, vent, générateur, coups sourds |
| `amb_ep04_orvane_rues` | `amb_orvane_rues` | 6006 | ch. 4, assaut (`orvane_rues`, `or-rue`, `orvane_barricade`) | Boucle de 50 s : tirs laser et à projectiles à moyenne distance, ricochets, sirène, feu, gravats, foule qui fuit au loin (sans mots) |
| `amb_ep04_orvane_bloc` | `amb_orvane_bloc` | 6007 | ch. 4, le bloc d'habitation à l'aube (`orvane_bloc`, crise C7) | Boucle de 45 s : tirs isolés entre les murs, voix étouffées de civils (sans mots), verre qui tombe, vent, premiers oiseaux |
| `amb_ep04_orvane_matin` | `amb_orvane_matin` | 6008 | ch. 4, retombée (`orvane_aube`) | Boucle de 45 s : feux qui finissent, conduite qui goutte, sirène qui s'éloigne, cendre dans le vent, quelques oiseaux ; identique pour toutes les branches |
| `amb_ep05_orvane_soir` | `amb_orvane_soir` | 6009 | ch. 5, graver les morts (`orvane_soir`) | Boucle de 45 s : vent, brasero, générateur, insectes du soir, et loin deux ciseaux qui frappent la pierre (on grave des noms) |

### Épisode 2 (`tools/son/generer_episode02.py`, préfixe `e2_`, mêmes outils)

Le préfixe `e2_` désigne l'épisode 2. Dans l'épisode 1, les fichiers `amb_ep0N_` portaient le numéro du chapitre.

```
python3 tools/son/generer_episode02.py /tmp/wav_e2
python3 tools/son/encoder_ogg.py /tmp/wav_e2 assets/audio
```

| Fichier | Fonction du générateur | Graine | Où il sonne | Ce que c'est |
|---|---|---|---|---|
| `amb_e2_cour_or` | `amb_cour_or` | 7001 | ch. 1, cours d'or de 63-19 avant l'assaut (`palais_6319`) | Boucle de 40 s : dallage immense, bannières, fontaine, garde d'apparat, fanfare de deux trompettes un peu fausses (le faste creux) |
| `amb_e2_cour_or_assaut` | `amb_cour_or_assaut` | 7002 | ch. 1, l'assaut du palais | Boucle de 45 s : bolters de la Légion contre fusils laser des gardes, marbre qui éclate, corne d'alarme archaïque |
| `amb_e2_tour` | `amb_tour` | 7003 | ch. 1, le flanc pendant qu'Horus monte à la tour | Boucle de 40 s : la bataille qui se tait par vagues, tirs lointains, vent en hauteur, feux |
| `sfx_e2_teleport` | `sfx_teleport` | 7004 | ch. 1, l'éclair au sommet de la tour | L'air qui se charge, l'implosion, le tonnerre qui roule (8 s avec la réverbération) |
| `sfx_e2_tir_unique` | `sfx_tir_unique` | 7005 | ch. 1, Horus tue l'« Empereur » | Un seul coup très loin et ses trois échos sur les façades |
| `amb_e2_palais_soir` | `amb_palais_soir` | 7006 | ch. 1, le palais pris le soir (`palais_salle_trone`) | Boucle de 45 s : salle du trône vide, vent par les vitres brisées, fontaine qui goutte, pas lointains |
| `sfx_e2_couronne` | `sfx_couronne` | 7007 | ch. 1, Dremm jette la couronne | L'or creux sur le marbre, les rebonds, la couronne qui tourne sur sa tranche |
| `amb_e2_navettes` | `amb_navettes` | 7008 | ch. 2, arrivée des civils (`vs_grand_hangar`) | Boucle de 50 s : turbines, foule civile sans mots, malles, signal de bord à deux tons (aucune annonce parlée) |
| `amb_e2_whisperheads` | `amb_whisperheads` | 7009 | ch. 2, la crête (`whisperheads`) | Boucle de 50 s : brouillard et pluie de montagne, vent qui siffle, pierres, assaut de la 10e étouffé par le brouillard |
| `amb_e2_vox_escouade` | `amb_vox_escouade` | 7010 | ch. 2, le vox de l'escouade | Boucle de 30 s : porteuse, crépitements, appels brefs sans mots dans la bande du vox, clics de micro |
| `sfx_e2_vox_anomalie` | `sfx_vox_anomalie` | 7011 | ch. 2, « la voix » (Venn) | Sans voix : une respiration trop régulière dans la porteuse, puis le bruit qui bat en deux temps (long-court) trois fois, une modulation qui descend sous le souffle, et la coupure. Ambigu : on peut croire à une panne |
| `sfx_e2_vox_cris` | `sfx_vox_cris` | 7012 | ch. 2, l'incident de Jubal, entendu au vox | Tirs et cris de gorge sans mots, saturés, puis le canal qui coupe |
