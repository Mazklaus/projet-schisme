extends GutTest


func test_catalogue_du_jeu() -> void:
	assert_true(Catalogue.episodes.has("ep00_prologue"))
	assert_false(Catalogue.ordre.has("ep00_prologue"), "démo cachée du menu")
	for id in Catalogue.ordre:
		for c in Catalogue.episode(id).chapitres:
			assert_true(ResourceLoader.exists(c.scene), c.scene)
			for f in ([c.plans] if typeof(c.get("plans")) == TYPE_STRING else c.get("plans", [])):
				assert_true(FileAccess.file_exists(f), f)


func test_validation() -> void:
	assert_eq(Catalogue.valider_episode({"id": "a", "numero": 1, "titre": "t", "chapitres": [{"id": "c", "scene": "s"}]}), PackedStringArray())
	assert_gt(Catalogue.valider_episode({"id": "a"}).size(), 0)
	assert_gt(Catalogue.valider_episode({"id": "a", "numero": 1, "titre": "t", "chapitres": []}).size(), 0)
	var double := {"id": "a", "numero": 1, "titre": "t", "chapitres": [{"id": "c", "scene": "s"}, {"id": "c", "scene": "s"}]}
	assert_string_contains(", ".join(Catalogue.valider_episode(double)), "double")


func test_suivant_traverse_les_episodes() -> void:
	var sauve := [Catalogue.episodes.duplicate(true), Catalogue.ordre.duplicate()]
	Catalogue.episodes = {
		"e1": {"id": "e1", "numero": 1, "chapitres": [{"id": "a"}, {"id": "b"}]},
		"e2": {"id": "e2", "numero": 2, "chapitres": [{"id": "x"}]},
	}
	Catalogue.ordre = ["e1", "e2"]
	assert_eq(Catalogue.suivant("e1", "a"), {"episode": "e1", "chapitre": "b"})
	assert_eq(Catalogue.suivant("e1", "b"), {"episode": "e2", "chapitre": "x"})
	assert_eq(Catalogue.suivant("e2", "x"), {})
	Catalogue.episodes = sauve[0]
	Catalogue.ordre = sauve[1]


func test_partie_enchaine_les_chapitres_et_sauve() -> void:
	Sauvegarde.effacer(0)
	Jeu.nouvelle_partie("ep00_prologue")
	assert_eq([Jeu.etat.episode, Jeu.etat.chapitre], ["ep00_prologue", "c01"])
	Jeu.poser_drapeau("vivant_ilse")
	Jeu.terminer_chapitre()
	assert_eq(Jeu.etat.chapitre, "c02")
	var lu := Sauvegarde.lire(0)
	assert_eq(lu.chapitre, "c02")
	assert_true(lu.drapeaux.vivant_ilse)
	Jeu.terminer_chapitre()
	assert_true(Jeu.etat.episodes_termines.has("ep00_prologue"))
	assert_true(Jeu.charger(0))
	assert_eq(Jeu.etat.chapitre, "c02")
