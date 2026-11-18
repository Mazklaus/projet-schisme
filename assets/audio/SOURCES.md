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
