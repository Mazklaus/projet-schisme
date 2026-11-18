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
| `mus_ullanor_triomphe` | `mus_triomphe` | 1001 | 1c (clameur) | Boucle de 38 s : orgue, chœur grave, cuivres en houle, timbales, ré mineur modal (i–VI–III–VII–i–iv–V–i), 50 à la noire |
| `mus_ullanor_attente` | `mus_attente` | 1002 | 1d à 1f | Boucle de 30 s : bourdon d'orgue ré–la, chœur voilé, couleur napolitaine non résolue |
| `mus_ullanor_horus` | `mus_horus` | 1003 | 5b–5c | Boucle de 20 s : la note tenue (ré à l'unisson et à l'octave : orgue, chœur, cuivre grave) |
| `amb_ullanor_triomphe` | `amb_triomphe` | 2001 | 1a, 1c | Boucle de 40 s : tambours de défilé lointains, des millions de pas, armures, vent |
| `amb_ullanor_vent` | `amb_vent` | 2002 | 1b, ciné de fin | Boucle de 30 s : vent et poussière sur la plaine, sans foule |
| `amb_ullanor_bivouac` | `amb_bivouac` | 2003 | jeu (bivouac) | Boucle de 60 s : vent, feux de camp, outils sur le métal, moteur au ralenti, un tambour très loin |
| `sfx_clameur_maitre` | `sfx_clameur_maitre` | 3001 | 1c–1d | La plaine explose, puis la clameur retombe, inquiète (15 s avec la réverbération) |
| `sfx_clameur_lupercal` | `sfx_clameur_lupercal` | 3002 | 5d | Poings sur les plastrons (deux fois) et grondement de la Légion, sans syllabes |
| `sfx_vox_crepite_01`, `sfx_vox_crepite_02`, `sfx_vox_crepite_03` | `sfx_vox_crepite` | 3010–3012 | lignes vox de Dremm | Clic de micro et parasites en bande étroite |
| `sfx_eboulement` | `sfx_eboulement` | 3020 | 3 (éboulement) | Le métal hurle, le choc, les débris, puis le silence |
| `sfx_poutre_grince` | `sfx_poutre_grince` | 3030 | QTE et choix | Boucle de 2 s, collé-glissé de l'acier ; volume et hauteur suivent la jauge |
| `sfx_choix_tic` | `sfx_choix_tic` | 3040 | choix minuté | Tic sourd à chaque seconde (signal `delai_seconde` de la boîte) |
