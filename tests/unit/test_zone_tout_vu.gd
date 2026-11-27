extends GutTest
## Spec v1.4 §9 (GD, QA ép. 1) : dans une zone d'exploration, quand tous les points d'intérêt
## disponibles sont vus, la suite part TOUT_VU_S secondes après la fin de la dernière réplique ;
## le max_s des déclencheurs reste un filet. Un point masqué par une condition ne compte pas.


func _zone_c05(vivant_ilse: bool) -> ChapitreJouable:
	var c05: Dictionary = Catalogue.chapitre("ep01", "c05").duplicate(true)
	c05.erase("dialogue")
	Catalogue.episodes["test_tout_vu"] = {"id": "test_tout_vu", "numero": 99, "chapitres": [c05]}
	Jeu.etat.episode = "test_tout_vu"
	Jeu.etat.chapitre = c05.id
	Jeu.etat.drapeaux["vivant_ilse"] = vivant_ilse
	var ch: ChapitreJouable = load("res://scenes/chapitres/chapitre_jouable.tscn").instantiate()
	add_child_autofree(ch)
	await wait_frames(2)
	if ch.zones.is_empty():
		ch.zones = JSON.parse_string(FileAccess.get_file_as_string(c05.jeu))
	await ch._commencer_jeu("graver")
	return ch


func test_tout_vu_lance_la_suite_sans_attendre_le_filet() -> void:
	var sauve: Array = [Jeu.etat.duplicate(true), Catalogue.episodes.duplicate(true)]
	var ch := await _zone_c05(false)
	assert_false(ch.pois.has("poi_ilse_grave"), "Ilse morte : son point n'existe pas")
	ch.pois_vus["poi_mur"] = true
	assert_false(ch.tous_pois_vus())
	ch.pois_vus["poi_sefa_note"] = true
	assert_true(ch.tous_pois_vus(), "le point masqué par une condition ne compte pas")
	ch.boite.hide()
	ch.temps_jeu = 10.0
	assert_eq(ch.declencheur_pret(), -1, "pas avant les 3 s")
	ch.temps_jeu = 10.0 + ChapitreJouable.TOUT_VU_S + 0.1
	assert_eq(ch.declencheur_pret(), 0, "la suite part 3 s après, loin du max_s de 45 s, et c'est celle du filet")
	Jeu.etat = sauve[0]
	Catalogue.episodes = sauve[1]


func test_point_restant_attend_le_filet() -> void:
	var sauve: Array = [Jeu.etat.duplicate(true), Catalogue.episodes.duplicate(true)]
	var ch := await _zone_c05(true)
	ch.pois_vus["poi_mur"] = true
	ch.pois_vus["poi_sefa_note"] = true
	assert_false(ch.tous_pois_vus(), "Ilse vivante : son point reste à voir")
	ch.boite.hide()
	ch.temps_jeu = 20.0
	assert_eq(ch.declencheur_pret(), -1)
	Jeu.etat = sauve[0]
	Catalogue.episodes = sauve[1]
