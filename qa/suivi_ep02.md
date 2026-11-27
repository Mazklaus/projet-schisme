# Suivi de production : ep02

*Généré par `tools/ci/verifier_episode.py` le 2026-11-27. Sources : 6 fichier(s) .dlg, séquencier `ep02-sequenciers.md`.*

**50 point(s) ouvert(s)** : 1 décor(s) absent(s), 21 à importer, 0 incomplet(s), 27 sans ambiance son, 0 ambiance(s) sans fichier, 1 personnage(s) en gros plan sans buste, 0 buste(s) sans les deux côtés. 5 décor(s) complet(s).

**Thermomètre** : 0 % peint, 0 % des personnages en plan large animés, 0 % des décors finis.

| Date | Commit | Peint | Animé | Fini | Points ouverts |
|---|---|---|---|---|---|
| 2026-11-27 15:03 | 3c38ebf | 0 % | 0 % | 0 % | 50 |

## 1. Décors (CA2, import par le Lead)

### Absents : référencés mais introuvables

| Décor | Référencé dans | Note |
|---|---|---|
| `xenobia_sommet_alarme` | ch04-repliques.dlg › rupture | état de `xenobia_sommet` ? (ajouter un alias dans data/decors_alias.json) |

### Livrés hors du dépôt : à importer dans assets/decors/

| Décor | Source | Contrat §6 |
|---|---|---|
| `murder_campagne` | `episode-02/murder_campagne` | aucune couche _ombre |
| `murder_ciel` | `episode-02/murder_ciel` | aucune couche _ombre |
| `murder_epines` | `episode-02/murder_epines` | complet |
| `nikaea_amphitheatre` | `episode-02/nikaea_amphitheatre` | complet |
| `nikaea_exterieur` | `episode-02/nikaea_exterieur` | complet |
| `nikaea_feu` | `episode-02/nikaea_feu` | complet |
| `nikaea_tente` | `episode-02/nikaea_tente` | complet |
| `palais_6319` | `episode-02/palais_6319` | complet |
| `palais_salle_trone` | `episode-02/palais_salle_trone` | complet |
| `vs_ateliers` | `episode-02/vs_ateliers` | complet |
| `vs_cales_loge_porte` | `episode-02/vs_cales_loge_porte` | complet |
| `vs_galerie_haute` | `episode-02/vs_galerie_haute` | complet |
| `vs_galerie_privee` | `episode-02/vs_galerie_privee` | complet |
| `vs_grand_hangar` | `episode-02/vs_grand_hangar` | complet |
| `vs_quartiers_27_nuit` | `episode-02/vs_quartiers_27_nuit` | aucun JSON de décor (decor.json ou <plan>.json avec « calques ») |
| `vs_quartiers_sefa` | `episode-02/vs_quartiers_sefa` | complet |
| `vs_salle_briefing` | `episode-02/vs_salle_briefing` | complet |
| `whisperheads` | `episode-02/whisperheads` | complet |
| `xenobia_coursive_nuit` | `episode-02/xenobia_coursive_nuit` | complet |
| `xenobia_salle_objets` | `episode-02/xenobia_salle_objets` | complet |
| `xenobia_sommet` | `episode-02/xenobia_sommet` | complet |

Complets : `archive`, `barge_galerie`, `vs_cales_loge`, `vs_galerie`, `vs_quartiers_27`.

## 2. Ambiances son (Sound Designer, pose des @ambiance par le Narrative Designer)

### Décors sans ambiance

Aucun nœud qui pose ce décor n'a de `@ambiance`.

| Décor | Posé dans |
|---|---|
| `archive` | ch01-repliques.dlg › archive_ep02_ch1, ch01-repliques.dlg › archive_deux_recits, ch02-repliques.dlg › archive_ep02_ch2, ch02-repliques.dlg › archive_ep02_ch2_fin |
| `barge_galerie` | ch01-repliques.dlg › ralliement |
| `murder_campagne` | ch03-repliques.dlg › six_mois |
| `murder_ciel` | ch03-repliques.dlg › trois_vaisseaux |
| `murder_epines` | ch03-repliques.dlg › descente |
| `nikaea_amphitheatre` | ch05-repliques.dlg › concile, ch05-repliques.dlg › decret |
| `nikaea_exterieur` | ch05-repliques.dlg › arrivee_nikaea |
| `nikaea_feu` | ch05-repliques.dlg › nuit_nikaea |
| `nikaea_tente` | ch05-repliques.dlg › choix_akhenet |
| `palais_6319` | ch01-repliques.dlg › assaut_palais |
| `palais_salle_trone` | ch01-repliques.dlg › soir_trone |
| `vs_ateliers` | ch06-repliques.dlg › ateliers |
| `vs_cales_loge` | ch04-repliques.dlg › loge_invite_dedans |
| `vs_cales_loge_porte` | ch04-repliques.dlg › loge_invite |
| `vs_galerie` | ch06-repliques.dlg › detour |
| `vs_galerie_haute` | ch02-repliques.dlg › corps_principal |
| `vs_galerie_privee` | ch06-repliques.dlg › conseil |
| `vs_grand_hangar` | ch06-repliques.dlg › decret_nom |
| `vs_quartiers_27` | ch02-repliques.dlg › version_officielle, ch04-repliques.dlg › ce_qu_il_a_vu |
| `vs_quartiers_27_nuit` | ch06-repliques.dlg › krenn_epauliere |
| `vs_quartiers_sefa` | ch02-repliques.dlg › sefa_voix |
| `vs_salle_briefing` | ch01-repliques.dlg › fausse_terra |
| `whisperheads` | ch02-repliques.dlg › forteresse |
| `xenobia_coursive_nuit` | ch04-repliques.dlg › coursive |
| `xenobia_salle_objets` | ch04-repliques.dlg › salle_objets |
| `xenobia_sommet` | ch04-repliques.dlg › sommet |
| `xenobia_sommet_alarme` | ch04-repliques.dlg › rupture |

## 3. Bustes de gros plan (CA1)

### Personnages en gros plan sans buste

| Personnage | Gros plans |
|---|---|
| `venn` | ch02-repliques.dlg › voix; ch02-repliques.dlg › venn_crise; ch02-repliques.dlg › venn_signaler (+1) |

## 4. Finition visuelle (CA2, TP2 ; suivi GD et QA à chaque build)

**0 % peint sur les 37 scènes** (0 % en moyenne sur 26 décor(s) trouvé(s) ; 26 en maquette : aucun calque retouché ni peint).

### Avancement par scène

| Chapitre | Scène | Décor | Peint | État |
|---|---|---|---|---|
| c01 | archive_ep02_ch1 | `archive` | 0 % | maquette; aplats : 10_fond (83%), 20_etageres (82%), 50_avant_plan (100%) |
| c01 | ralliement | `barge_galerie` | 0 % | maquette; aplats : 00_exterieur_nuit (86%), 00_exterieur_aube (73%), 20_baie (86%) … |
| c01 | fausse_terra | `vs_salle_briefing` | 0 % | maquette; aplats : 00_exterieur_6319 (87%), 10_salle (80%), 30_table (63%) …; hors dépôt |
| c01 | assaut_palais | `palais_6319` | 0 % | maquette; aplats : 36_bannieres (79%), 20_cour (72%), 50_avant_plan (93%); hors dépôt |
| c01 | soir_trone | `palais_salle_trone` | 0 % | maquette; aplats : 00_dehors (98%), 10_salle (79%), 20_colonnes (74%) …; hors dépôt |
| c01 | archive_deux_recits | `archive` | 0 % | maquette; aplats : 10_fond (83%), 20_etageres (82%), 50_avant_plan (100%) |
| c02 | archive_ep02_ch2 | `archive` | 0 % | maquette; aplats : 10_fond (83%), 20_etageres (82%), 50_avant_plan (100%) |
| c02 | corps_principal | `vs_galerie_haute` | 0 % | maquette; aplats : 00_espace (97%), 10_hangar (79%), 20_navettes (61%) …; hors dépôt |
| c02 | forteresse | `whisperheads` | 0 % | maquette; aplats : 05_montagnes (99%), 10_forteresse (99%), 20_pente (79%) …; hors dépôt |
| c02 | version_officielle | `vs_quartiers_27` | 0 % | maquette; aplats : 00_fond (66%), 10_voute (49%), 20_nef (69%) … |
| c02 | sefa_voix | `vs_quartiers_sefa` | 0 % | maquette; aplats : 00_dehors (97%), 10_cabine (92%), 30_mobilier (78%) …; hors dépôt |
| c02 | archive_ep02_ch2_fin | `archive` | 0 % | maquette; aplats : 10_fond (83%), 20_etageres (82%), 50_avant_plan (100%) |
| c03 | archive_ep02_ch3 | `archive` | 0 % | maquette; aplats : 10_fond (83%), 20_etageres (82%), 50_avant_plan (100%) |
| c03 | descente | `murder_epines` | 0 % | maquette; aplats : 10_foret_loin (93%), 20_clairiere (79%), 30_epines (78%) …; hors dépôt |
| c03 | six_mois | `murder_campagne` | 0 % | maquette; aplats : 10_horizon (97%), 20_tranchee (64%), 50_avant_plan (97%); hors dépôt |
| c03 | trois_vaisseaux | `murder_ciel` | 0 % | maquette; aplats : 10_vaisseaux (49%), 30_cimes (69%); hors dépôt |
| c04 | archive_ep02_ch4 | `archive` | 0 % | maquette; aplats : 10_fond (83%), 20_etageres (82%), 50_avant_plan (100%) |
| c04 | sommet | `xenobia_sommet` | 0 % | maquette; aplats : 10_terrasse (70%), 15_arcade (69%), 30_pergola (69%); hors dépôt |
| c04 | salle_objets | `xenobia_salle_objets` | 0 % | maquette; aplats : 10_salle (76%), 20_vitrines (64%), 30_boite (84%) …; hors dépôt |
| c04 | loge_invite | `vs_cales_loge_porte` | 0 % | maquette; aplats : 10_couloir (72%), 50_avant_plan (99%); hors dépôt |
| c04 | loge_invite_dedans | `vs_cales_loge` | 0 % | maquette; aplats : 00_fond (82%), 10_voute (76%), 20_cale (77%) … |
| c04 | coursive | `xenobia_coursive_nuit` | 0 % | maquette; aplats : 10_coursive (84%), 50_avant_plan (100%); hors dépôt |
| c04 | rupture | `xenobia_sommet_alarme` | 0 % | absent (décor provisoire) |
| c04 | ce_qu_il_a_vu | `vs_quartiers_27` | 0 % | maquette; aplats : 00_fond (66%), 10_voute (49%), 20_nef (69%) … |
| c05 | archive_ep02_ch5 | `archive` | 0 % | maquette; aplats : 10_fond (83%), 20_etageres (82%), 50_avant_plan (100%) |
| c05 | arrivee_nikaea | `nikaea_exterieur` | 0 % | maquette; aplats : 50_avant_plan (89%); hors dépôt |
| c05 | concile | `nikaea_amphitheatre` | 0 % | maquette; hors dépôt |
| c05 | nuit_nikaea | `nikaea_feu` | 0 % | maquette; aplats : 10_camp (60%), 50_avant_plan (78%); hors dépôt |
| c05 | decret | `nikaea_amphitheatre` | 0 % | maquette; hors dépôt |
| c05 | choix_akhenet | `nikaea_tente` | 0 % | maquette; 3 calque(s); aplats : 10_tente (58%), 50_avant_plan (75%); hors dépôt |
| c06 | archive_ep02_ch6 | `archive` | 0 % | maquette; aplats : 10_fond (83%), 20_etageres (82%), 50_avant_plan (100%) |
| c06 | conseil | `vs_galerie_privee` | 0 % | maquette; aplats : 00_espace (92%), 10_galerie (78%), 50_avant_plan (79%); hors dépôt |
| c06 | decret_nom | `vs_grand_hangar` | 0 % | maquette; aplats : 00_espace (86%), 10_hangar (65%), 30_galerie (89%) …; hors dépôt |
| c06 | ateliers | `vs_ateliers` | 0 % | maquette; aplats : 10_atelier (69%), 20_rateliers (67%), 50_avant_plan (99%); hors dépôt |
| c06 | krenn_epauliere | `vs_quartiers_27_nuit` | 0 % | maquette; 3 calque(s); aplats : 20_nef_ombre_nuit (96%); hors dépôt |
| c06 | detour | `vs_galerie` | 0 % | maquette; aplats : 00_exterieur_croisade (93%), 20_verriere (45%), 50_avant_plan (87%) |
| c06 | archive_ep02_fin | `archive` | 0 % | maquette; aplats : 10_fond (83%), 20_etageres (82%), 50_avant_plan (100%) |

### Personnages en plan large

| Personnage | Sprite | Chapitres |
|---|---|---|
| `akhenet` | provisoire | c05 |
| `bjarn` | provisoire | c05 |
| `casse` | provisoire | c03 |
| `dremm` | provisoire | c01, c02, c03, c04, c06 |
| `horus` | provisoire | c06 |
| `krenn` | provisoire | c01, c02, c03, c04, c06 |
| `sefa` | provisoire | c02 |
| `vaskar` | fixe | c01, c02, c03, c04, c06 |
| `venn` | provisoire | c02 |

0 sur 9 animé(s). « provisoire » : silhouette grise du moteur ; « fixe » : image sans rig.

