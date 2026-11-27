extends GutTest
## Rig de personnage découpé (contrat v1) : construction, gestes, marche, clignement.
## Pièces de test : Ilse v0 de CA1 (maquette non peinte, découpage et pivots définitifs).

const DOSSIER := "res://tests/fixtures/rigs/ilse/pied"


func _rig() -> RigPersonnage:
	var r := RigPersonnage.charger(DOSSIER)
	assert_not_null(r)
	add_child_autofree(r)
	return r


func _avancer(r: RigPersonnage, secondes: float) -> void:
	var n := int(secondes * 60.0)
	for i in n:
		r.avancer(1.0 / 60.0)


func test_sans_rig_json() -> void:
	assert_null(RigPersonnage.charger("res://tests/fixtures/rigs/personne/pied"))


func test_construction() -> void:
	var r := _rig()
	assert_eq(r.perso, &"ilse")
	assert_eq(r.pieces.size(), 20)
	assert_eq(r.os.size(), 20)
	assert_eq(r.os.main_avant.get_parent(), r.os.avant_bras_avant, "hiérarchie du rig.json")
	assert_eq(r.os.bassin.get_parent(), r.squelette, "le bassin est la racine")
	# Pivot du bassin dans la planche (4 + 42, 148 + 28), relatif aux pieds (51, 347).
	assert_eq(r.os.bassin.position, Vector2(-5, -171))
	assert_almost_eq(r.hauteur(), 343.0, 0.5)
	# Ordre z du contrat : bras arrière au fond, torse avant le bras avant.
	var ordre := r.get_children().map(func(n): return String(n.name)).filter(func(n): return n.begins_with("Piece_"))
	assert_eq(ordre[0], "Piece_bras_arriere")
	assert_lt(ordre.find("Piece_torse"), ordre.find("Piece_bras_avant"))
	assert_lt(ordre.find("Piece_cuisse_arriere"), ordre.find("Piece_bassin"))
	assert_not_null((r.pieces.torse.texture as CanvasTexture).normal_texture, "normales chargées")


func test_variantes_au_repos() -> void:
	var r := _rig()
	r.avancer(0.016)
	assert_true(r.pieces.main_avant.visible)
	assert_false(r.pieces.main_avant_pointe.visible)
	assert_true(r.pieces.tete.visible)
	assert_false(r.pieces.tete_face.visible)


func test_geste_montrer() -> void:
	var r := _rig()
	watch_signals(r)
	assert_true(r.jouer_geste("montrer"))
	assert_signal_emitted_with_parameters(r, "evenement_anim", [&"geste_montrer", &"ilse"])
	_avancer(r, 1.2)
	assert_almost_eq(rad_to_deg(r.os.bras_avant.rotation), -80.0, 3.0, "bras tendu")
	assert_true(r.pieces.main_avant_pointe.visible, "main qui pointe")
	assert_false(r.pieces.main_avant.visible)
	_avancer(r, 3.0)
	assert_almost_eq(rad_to_deg(r.os.bras_avant.rotation), 0.0, 1.0, "retour au repos")
	assert_signal_emitted(r, "geste_termine")
	assert_eq(r.geste_en_cours(), "")


func test_geste_tenu_puis_repos() -> void:
	var r := _rig()
	r.jouer_geste("agenouiller")
	_avancer(r, 5.0)
	assert_gt(r.os.bassin.position.y, -171.0 + 70.0, "le bassin descend")
	assert_eq(r.geste_en_cours(), "agenouiller", "tenu")
	r.jouer_geste("repos")
	_avancer(r, 3.0)
	assert_almost_eq(r.os.bassin.position.y, -171.0, 1.5)
	assert_eq(r.geste_en_cours(), "")


func test_enchainement_sans_saut() -> void:
	var r := _rig()
	r.jouer_geste("montrer")
	_avancer(r, 1.0)
	var avant := r.os.bras_avant.rotation
	r.jouer_geste("saluer")
	r.avancer(1.0 / 60.0)
	assert_almost_eq(r.os.bras_avant.rotation, avant, deg_to_rad(12.0), "pas de retour brutal au repos")


func test_geste_inconnu() -> void:
	var r := _rig()
	assert_false(r.jouer_geste("danser"))
	assert_true("montrer" in r.gestes_connus())


func test_marche_et_pas() -> void:
	var r := _rig()
	watch_signals(r)
	r.marche = 1.0
	_avancer(r, 1.4)
	var pas := get_signal_emit_count(r, "evenement_anim")
	assert_between(pas, 3, 5, "un appui toutes les 0,35 s environ")
	r.marche = 0.0
	_avancer(r, 1.0)
	assert_almost_eq(r.os.cuisse_avant.rotation, 0.0, 0.01, "à l'arrêt, jambes au repos")


func test_clignement() -> void:
	var r := _rig()
	var vu := false
	for i in 60 * 8:
		r.avancer(1.0 / 60.0)
		vu = vu or r.pieces.yeux_fermes.visible
	assert_true(vu, "clignement en 8 s")
	assert_false(r.pieces.yeux_fermes_face.visible)


func test_gestes_json() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(RigPersonnage.GESTES))
	assert_typeof(d, TYPE_DICTIONARY)
	for nom in d.gestes:
		var g: Dictionary = d.gestes[nom]
		for o in g.get("os", {}):
			assert_true(o in RigPersonnage.ORDRE, "%s : pièce %s hors contrat" % [nom, o])
		if g.has("main"):
			assert_true(g.main in ["pointe", "poing"], nom)
	for nom in ["montrer", "croiser_bras", "main_epaule", "saluer", "degainer", "agenouiller"]:
		assert_true(d.gestes.has(nom), "geste demandé par le GD : " + nom)


func test_courbe_anticipation_et_depassement() -> void:
	assert_almost_eq(RigPersonnage.courbe_geste(0.0), 0.0, 0.0001)
	assert_almost_eq(RigPersonnage.courbe_geste(1.0), 1.0, 0.0001)
	var bas := INF
	var haut := -INF
	for i in 101:
		var v := RigPersonnage.courbe_geste(i / 100.0)
		bas = minf(bas, v)
		haut = maxf(haut, v)
	assert_between(bas, -0.08, -0.02, "léger contre-mouvement au départ")
	assert_between(haut, 1.02, 1.08, "petit dépassement à l'arrivée")


func test_poids_de_la_marche() -> void:
	assert_gt(RigPersonnage.poids_marche(PI / 2.0), RigPersonnage.poids_marche(0.0) + 6.0, "bassin plus bas au contact")
	var m := RigPersonnage.angles_marche(PI / 2.0)
	assert_lt(signf(m.bassin) * signf(m.torse), 0.0, "épaules en opposition du bassin")


func test_main_epaule_distincte_de_montrer() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(RigPersonnage.GESTES))
	var montrer: float = d.gestes.montrer.os.bras_avant
	var epaule: float = d.gestes.main_epaule.os.bras_avant
	assert_gt(epaule - montrer, 30.0, "main sur l'épaule : bras nettement plus bas")
	assert_eq(d.gestes.croiser_bras.montre, ["bras_croises"], "pièce dédiée demandée à CA1")
