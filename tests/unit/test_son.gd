extends GutTest
## Son de la tranche : chaque son appelé par le dialogue ou par la scène existe dans
## assets/audio/, et l'autoload Son reste silencieux (sans erreur) quand un fichier manque.

const DLG := "res://data/dialogues/ep01/ullanor.dlg"
## Sons appelés depuis scenes/ullanor/tranche_ullanor.gd (préfixe compris).
const SONS_SCENE := ["amb_ullanor_bivouac", "sfx_eboulement", "sfx_poutre_grince", "sfx_choix_tic", "sfx_vox_crepite_01"]
const PREFIXES := {"ambiance": "amb_", "musique": "mus_", "bruitage": "sfx_"}


func _fichier_existe(nom: String) -> bool:
	# Un bruitage peut n'exister qu'en variantes (sfx_<nom>_01…).
	return FileAccess.file_exists(Son.DOSSIER + nom + ".ogg") or FileAccess.file_exists(Son.DOSSIER + nom + "_01.ogg")


func test_sons_du_dialogue_presents() -> void:
	var appels := 0
	for ligne in FileAccess.get_file_as_string(DLG).split("\n"):
		var mots := ligne.strip_edges().split(" ", false)
		if mots.size() < 2 or not mots[0].begins_with("@") or not PREFIXES.has(mots[0].substr(1)):
			continue
		if mots[1] == "stop":
			continue
		appels += 1
		var nom: String = PREFIXES[mots[0].substr(1)] + mots[1]
		assert_true(_fichier_existe(nom), "son absent : %s (%s)" % [nom, ligne.strip_edges()])
	assert_gt(appels, 8, "le dialogue de la tranche pose ses sons")


func test_sons_de_la_scene_presents() -> void:
	for nom in SONS_SCENE:
		assert_true(_fichier_existe(nom), "son absent : " + nom)


func test_tracabilite() -> void:
	var sources := FileAccess.get_file_as_string("res://assets/audio/SOURCES.md")
	for f in DirAccess.get_files_at(Son.DOSSIER):
		if f.get_extension() == "ogg":
			assert_true(sources.contains(f.get_basename()), "absent de SOURCES.md : " + f)


func test_fichier_absent_silencieux() -> void:
	assert_null(Son.bruitage("inexistant"))
	Son.musique("inexistant", 0.0)
	assert_eq(Son.en_cours("musique"), "")
	Son.musique("stop", 0.0)
	Son.ambiance("inexistant", 0.0)
	assert_eq(Son.en_cours("ambiance"), "")
