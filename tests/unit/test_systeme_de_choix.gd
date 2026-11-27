extends GutTest
## Règles de systeme-de-choix.md : registre des personnages, règle du canon, bornes des
## relations et des traits, état par défaut d'un épisode.


func _jouer(source: String, drapeaux: Dictionary) -> void:
	var l := LecteurDialogue.new(FormatDialogue.analyser(source), drapeaux)
	l.demarrer("a")
	for i in 50:
		if l.avancer().type == "fin":
			break


func test_registre_lu() -> void:
	assert_eq(Personnages.registre().ilse.statut, "original")
	assert_true(Personnages.est_canon("horus"))
	assert_false(Personnages.est_canon("vaskar"))


func test_vivant_refuse_pour_un_personnage_canon() -> void:
	var dr := {}
	_jouer("=== a\n~ vivant_horus = false\n~ vivant_ilse = true\nA: fin", dr)
	assert_false(dr.has("vivant_horus"), "la règle du canon est tenue par le code")
	assert_true(dr.vivant_ilse)
	assert_push_error("personnage canon")


func test_traits_bornes_de_0_a_10_et_relations_de_moins_3_a_3() -> void:
	var dr := {"trait_vaskar_orgueil": 9, "trait_vaskar_doute": 1, "relation_dremm": -2}
	_jouer("=== a\n~ trait_vaskar_orgueil += 4\n~ trait_vaskar_doute -= 5\n~ relation_dremm -= 4\nA: fin", dr)
	assert_eq(dr.trait_vaskar_orgueil, 10)
	assert_eq(dr.trait_vaskar_doute, 0)
	assert_eq(dr.relation_dremm, -3)


func test_etat_par_defaut_de_l_episode() -> void:
	assert_eq(Jeu.etat_defaut("ep01_ullanor"), {}, "épisode 1 : rien avant lui")
	assert_eq(Jeu.etat_defaut("episode_inexistant"), {})
	var ep02 := Jeu.etat_defaut("ep02_vengeful_spirit")
	assert_eq(int(ep02.choix_ep01_ullanor), 3, "épisode 2 : le silence d'Ullanor")
	assert_false(ep02.vivant_ilse)
	for cle in ep02:
		assert_true(Personnages.ecriture_permise(cle), cle)


func test_cles_des_dialogues_conformes() -> void:
	var sortie := []
	var code := OS.execute("python3", [ProjectSettings.globalize_path("res://tools/ci/verifier_cles.py"),
		ProjectSettings.globalize_path("res://")], sortie, true)
	if code == -1:
		pending("python3 indisponible")
		return
	assert_eq(code, 0, "".join(sortie))
