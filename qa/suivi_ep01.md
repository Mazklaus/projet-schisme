# Suivi de production : ep01

*Généré par `tools/ci/verifier_episode.py` le 2026-11-27. Sources : 6 fichier(s) .dlg, séquencier `ch03-05-sequenciers.md`.*

**15 point(s) ouvert(s)** : 0 décor(s) absent(s), 0 à importer, 7 incomplet(s), 0 sans ambiance son, 0 ambiance(s) sans fichier, 8 personnage(s) en gros plan sans buste, 0 buste(s) sans les deux côtés. 32 décor(s) complet(s).

## 1. Décors (CA2, import par le Lead)

### Incomplets au contrat §6

| Décor | Points ouverts |
|---|---|
| `orvane_aube` | aucune couche _ombre |
| `orvane_barricade` | 30_facades.png : _ombre annoncée mais absente |
| `orvane_nuit` | aucune couche _ombre |
| `terra_unification` | aucun _normal dans le décor (calques éclairés : 10_ruines, 30_champ, 35_lumiere, 40_soldats)<br>aucune couche _ombre |
| `ullanor_aube` | aucun _normal dans le décor (calques éclairés : 10_fond, 20_titans, 25_poussiere, 30_voie) |
| `ullanor_nuit` | aucun _normal dans le décor (calques éclairés : 10_fond, 20_titans, 25_poussiere, 30_voie) |
| `ullanor_plaque` | aucune couche _ombre |

Complets : `archive`, `barge_briefing_gros_plan`, `barge_galerie`, `barge_galerie_gros_plan`, `barge_pont_embarquement`, `barge_pont_embarquement_gros_plan`, `barge_quartiers_27`, `barge_quartiers_27_gros_plan`, `barge_quartiers_civils`, `barge_quartiers_civils_gros_plan`, `barge_quartiers_codicier`, `barge_quartiers_codicier_gros_plan`, `barge_briefing`, `cthonia_tunnel`, `orvane_aube_gros_plan`, `orvane_barricade_gros_plan`, `orvane_bloc`, `orvane_bloc_gros_plan`, `orvane_rues`, `orvane_nuit_gros_plan`, `orvane_rues_gros_plan`, `orvane_soir`, `orvane_soir_gros_plan`, `ullanor`, `ullanor_nuit_gros_plan`, `ullanor_ouverture_gros_plan`, `vs_cales_loge`, `vs_cales_loge_gros_plan`, `vs_galerie`, `vs_galerie_gros_plan`, `vs_quartiers_27`, `vs_quartiers_27_gros_plan`.

## 2. Ambiances son (Sound Designer, pose des @ambiance par le Narrative Designer)

Rien à signaler.

## 3. Bustes de gros plan (CA1)

### Personnages en gros plan sans buste

| Personnage | Gros plans |
|---|---|
| `frère` (absent de data/personnages.json) | gros_plans.json (c05, orvane_soir_gros_plan); gros_plans.json (c04, orvane_rues_gros_plan); gros_plans.json (c04, orvane_rues_gros_plan) (+1) |
| `frère 3` (absent de data/personnages.json) | gros_plans.json (c02, vs_quartiers_27_gros_plan) |
| `frère 4` (absent de data/personnages.json) | gros_plans.json (c02, vs_quartiers_27_gros_plan) |
| `frère de la loge` (absent de data/personnages.json) | gros_plans.json (c02, vs_cales_loge_gros_plan) |
| `ilse` | gros_plans.json (c01, ullanor_ouverture_gros_plan); gros_plans.json (c05, orvane_soir_gros_plan); gros_plans.json (c04, orvane_rues_gros_plan) (+1) |
| `sergent` (absent de data/personnages.json) | gros_plans.json (c01, ullanor_ouverture_gros_plan) |
| `varo` | gros_plans.json (c05, barge_quartiers_codicier_gros_plan) |
| `émissaire` (absent de data/personnages.json) | gros_plans.json (c04, orvane_barricade_gros_plan) |

## 4. Finition visuelle (CA2, TP2 ; suivi GD et QA à chaque build)

**5 % peint sur les 36 scènes** (4 % en moyenne sur 22 décor(s) trouvé(s) ; 21 en maquette : aucun calque retouché ni peint).

### Avancement par scène

| Chapitre | Scène | Décor | Peint | État |
|---|---|---|---|---|
| c01 | archive_ouverture | `archive` | 0 % | maquette; aplats : 10_fond (83%), 20_etageres (82%), 50_avant_plan (100%) |
| c01 | cthonia | `cthonia_tunnel` | 0 % | maquette; aplats : 00_noir (100%), 20_galerie (72%), 30_gravats (70%) … |
| c01 | nuit | `ullanor_nuit` | 0 % | maquette; aplats : 25_poussiere (85%), 50_avant_plan (65%) |
| c01 | aube | `ullanor_aube` | 0 % | maquette; aplats : 25_poussiere (85%), 50_avant_plan (65%) |
| c01 | aube_plaque_offerte | `ullanor_plaque` | 0 % | maquette; aplats : 10_fond (63%), 15_sol (81%) |
| c01 | aube_depart | `archive` | 0 % | maquette; aplats : 10_fond (83%), 20_etageres (82%), 50_avant_plan (100%) |
| c02 | archive_ch2 | `archive` | 0 % | maquette; aplats : 10_fond (83%), 20_etageres (82%), 50_avant_plan (100%) |
| c02 | depart | `vs_galerie` | 0 % | maquette; aplats : 00_exterieur_croisade (93%), 20_verriere (45%), 50_avant_plan (87%) |
| c02 | quartiers | `vs_quartiers_27` | 0 % | maquette; aplats : 00_fond (66%), 10_voute (49%), 20_nef (69%) … |
| c02 | unification | `terra_unification` | 0 % | maquette; aplats : 10_ruines (72%), 40_soldats (53%), 50_tranchee (75%) |
| c02 | retour_krenn | `vs_quartiers_27` | 0 % | maquette; aplats : 00_fond (66%), 10_voute (49%), 20_nef (69%) … |
| c02 | loge | `vs_cales_loge` | 0 % | maquette; aplats : 00_fond (82%), 10_voute (76%), 20_cale (77%) … |
| c02 | retombee | `vs_galerie` | 0 % | maquette; aplats : 00_exterieur_croisade (93%), 20_verriere (45%), 50_avant_plan (87%) |
| c02 | annonce | `archive` | 0 % | maquette; aplats : 10_fond (83%), 20_etageres (82%), 50_avant_plan (100%) |
| c03 | archive_ch3 | `archive` | 0 % | maquette; aplats : 10_fond (83%), 20_etageres (82%), 50_avant_plan (100%) |
| c03 | embarquement | `barge_pont_embarquement` | 0 % | maquette; aplats : 00_fond (88%), 05_exterieur_arrivee (97%), 05_exterieur_orbite (93%) … |
| c03 | quartiers_civils | `barge_quartiers_civils` | 0 % | maquette; aplats : 00_coque (93%), 20_sol (77%), 30_mobilier (67%) … |
| c03 | dremm_sefa | `barge_quartiers_civils` | 0 % | maquette; aplats : 00_coque (93%), 20_sol (77%), 30_mobilier (67%) … |
| c03 | sefa_seule | `barge_quartiers_civils` | 0 % | maquette; aplats : 00_coque (93%), 20_sol (77%), 30_mobilier (67%) … |
| c03 | accroche_orvane | `barge_quartiers_27` | 0 % | maquette; aplats : 00_fond (84%), 10_voute (75%), 20_nef (79%) … |
| c04 | archive_ch4 | `archive` | 0 % | maquette; aplats : 10_fond (83%), 20_etageres (82%), 50_avant_plan (100%) |
| c04 | briefing | `barge_briefing` | 0 % | maquette; aplats : 10_voute (76%), 20_salle (81%), 30_table (67%) … |
| c04 | approche | `orvane_nuit` | 0 % | maquette; aplats : 10_sol (100%), 55_vaisseau (67%), 50_porte (89%) |
| c04 | emissaire | `orvane_barricade` | 0 % | maquette; aplats : 10_fond (90%), 30_facades (61%), 35_barricade (63%) … |
| c04 | assaut | `orvane_rues` | 0 % | maquette; aplats : 10_fond (53%), 30_facades (72%), 32_linge (51%) … |
| c04 | bloc | `orvane_bloc` | 0 % | maquette; aplats : 10_fond (77%), 30_facade (58%), 45_fenetres_allumees (68%) … |
| c04 | citadelle | `orvane_aube` | 0 % | maquette; aplats : 10_citadelle (80%), 20_ville (83%), 50_toit (97%) |
| c04 | retombee_rues | `orvane_rues` | 0 % | maquette; aplats : 10_fond (53%), 30_facades (72%), 32_linge (51%) … |
| c05 | archive_ch5 | `archive` | 0 % | maquette; aplats : 10_fond (83%), 20_etageres (82%), 50_avant_plan (100%) |
| c05 | graver | `orvane_soir` | 0 % | maquette; aplats : 10_fond (81%), 30_mur (79%), 50_avant_plan (89%) |
| c05 | codicier | `barge_quartiers_codicier` | 0 % | maquette; aplats : 10_voute (82%), 20_salle (98%), 35_pupitre (76%) … |
| c05 | ordre_depart | `barge_quartiers_27` | 0 % | maquette; aplats : 00_fond (84%), 10_voute (75%), 20_nef (79%) … |
| c05 | galerie_fin | `barge_galerie` | 0 % | maquette; aplats : 00_exterieur_nuit (86%), 00_exterieur_aube (73%), 20_baie (86%) … |
| c05 | archive_fin | `archive` | 0 % | maquette; aplats : 10_fond (83%), 20_etageres (82%), 50_avant_plan (100%) |
| ullanor | ouverture | `ullanor` | 97 % | aplats : 50_avant_plan (65%) |
| ullanor | fin | `ullanor` | 97 % | aplats : 50_avant_plan (65%) |

### Personnages en plan large

| Personnage | Sprite | Chapitres |
|---|---|---|
| `dremm` | provisoire | c01, c02, c03, c04, c05, ullanor |
| `frere_1` | fixe | c02, c03 |
| `frere_2` | fixe | c02 |
| `horus` | provisoire | c04, ullanor |
| `ilse` | fixe | c01, c04, c05, ullanor |
| `krenn` | provisoire | c01, c02, c05 |
| `krenn_jeune` | provisoire | c02 |
| `peintre` | provisoire | c03 |
| `poete` | provisoire | c03 |
| `sefa` | provisoire | c03, c05 |
| `technaugure` | provisoire | c01 |
| `varo` | provisoire | c05 |
| `vaskar` | fixe | c01, c02, c03, c04, c05, ullanor |
| `vaskar_enfant` | provisoire | c01 |

0 sur 14 animé(s). « provisoire » : silhouette grise du moteur ; « fixe » : image sans rig.

