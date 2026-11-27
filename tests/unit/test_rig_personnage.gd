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
	var avant: float = r.os.bras_avant.rotation
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
	var pas: int = get_signal_emit_count(r, "evenement_anim")
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
			assert_true(g.main in ["pointe", "poing", "pommeau"], nom)
	for nom in ["montrer", "croiser_bras", "main_epaule", "saluer", "degainer", "agenouiller",
			"casque_sous_bras", "main_pommeau"]:
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



## Ilse v0 montée comme un Astartes : seul le profil de mouvement change.
func _rig_astartes() -> RigPersonnage:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DOSSIER + "/rig.json"))
	d.type = "astartes"
	var r := RigPersonnage.new()
	r.construire(d, DOSSIER)
	add_child_autofree(r)
	return r


func test_astartes_plus_lourd_et_plus_lent() -> void:
	var h := _rig()
	var a := _rig_astartes()
	assert_eq(a.type_rig, "astartes")
	assert_lt(float(a.profil.pas_rad_s), float(h.profil.pas_rad_s), "pas plus lent")
	assert_gt(float(a.profil.poids_px), float(h.profil.poids_px), "plus de poids")
	watch_signals(h)
	watch_signals(a)
	h.marche = 1.0
	a.marche = 1.0
	_avancer(h, 1.4)
	_avancer(a, 1.4)
	assert_lt(get_signal_emit_count(a, "evenement_anim"), get_signal_emit_count(h, "evenement_anim"), "moins d'appuis")
	# Gestes économes : même geste, moins d'amplitude, entrée plus longue.
	a.jouer_geste("montrer")
	_avancer(a, 1.5)
	assert_almost_eq(rad_to_deg(a.os.torse.rotation), -3.0, 1.0, "bloc propre : le bras arrière tendu montre")
	assert_gt(a.duree_visible("montrer"), h.duree_visible("montrer"))


func test_geste_propre_au_type() -> void:
	var a := _rig_astartes()
	var g := {"os": {"bras_avant": -80}, "astartes": {"os": {"bras_avant": -50}}}
	assert_eq(a.os_du_geste(g), {"bras_avant": -50})
	assert_eq(_rig().os_du_geste(g), {"bras_avant": -80.0})


func test_casque_sans_piece() -> void:
	# Sans tete_casque ni casque_main (Ilse), le geste se joue sans erreur et la tête reste visible.
	var r := _rig()
	assert_true(r.jouer_geste("casque_sous_bras"))
	_avancer(r, 1.5)
	assert_true(r.pieces.tete.visible)
	assert_true(r.jouer_geste("main_pommeau"))
	_avancer(r, 1.5)
	assert_true(r.pieces.main_avant.visible, "pas de main_avant_pommeau livrée : main ordinaire")



func test_epauliere_suit_peu_le_bras() -> void:
	# Pièce d'épaulière ajoutée à Ilse pour le test (le contrat la réserve aux Astartes).
	var d = JSON.parse_string(FileAccess.get_file_as_string(DOSSIER + "/rig.json"))
	d.pieces["epauliere_avant"] = {"fichier": "bras_avant.png", "pose": [6, 61], "pivot": [17, 18], "parent": "bras_avant"}
	var r := RigPersonnage.new()
	r.construire(d, DOSSIER)
	add_child_autofree(r)
	r.jouer_geste("montrer")
	_avancer(r, 1.5)
	var bras := rad_to_deg(r.os.bras_avant.rotation)
	var globale := bras + rad_to_deg(r.os.epauliere_avant.rotation)
	assert_almost_eq(globale, bras * RigPersonnage.EPAULIERE_SUIT, 1.0, "l'épaulière ne se lève pas comme une aile")


func test_bassin_a_l_echelle_de_la_hanche() -> void:
	var r := _rig()
	assert_almost_eq(r.echelle_hanche, 1.0, 0.01, "Ilse sert de référence")
	r.echelle_hanche = 1.2
	assert_almost_eq(r.bassin_du_geste({"bassin_y": 85}), 102.0, 0.01)
	assert_eq(r.bassin_du_geste({"bassin_y": 85, "humain": {"bassin_y": 40}}), 40.0)



func test_piece_de_remplacement_a_mi_geste() -> void:
	# bras_tendu ajouté pour le test : invisible au repos, montré à mi-geste à la place du bras.
	var d = JSON.parse_string(FileAccess.get_file_as_string(DOSSIER + "/rig.json"))
	d.pieces["bras_tendu"] = {"fichier": "bras_avant.png", "pose": [6, 61], "pivot": [17, 18], "parent": "torse"}
	var r := RigPersonnage.new()
	r.construire(d, DOSSIER)
	add_child_autofree(r)
	r.avancer(0.016)
	assert_false(r.pieces.bras_tendu.visible)
	r.jouer_geste("montrer")
	r.avancer(0.1)
	assert_false(r.pieces.bras_tendu.visible, "pas encore : début du mouvement")
	_avancer(r, 1.0)
	assert_true(r.pieces.bras_tendu.visible)
	assert_false(r.pieces.bras_avant.visible)
	assert_false(r.pieces.main_avant_pointe.visible)
	_avancer(r, 3.0)
	assert_false(r.pieces.bras_tendu.visible, "rendue au repos")
	assert_true(r.pieces.bras_avant.visible)



func test_astartes_montre_avec_le_bras_arriere() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DOSSIER + "/rig.json"))
	d.type = "astartes"
	d.pieces["bras_tendu_arriere"] = {"fichier": "bras_arriere.png", "pose": [46, 61], "pivot": [23, 18], "parent": "torse"}
	d.pieces["bras_tendu"] = {"fichier": "bras_avant.png", "pose": [6, 61], "pivot": [17, 18], "parent": "torse"}
	var r := RigPersonnage.new()
	r.construire(d, DOSSIER)
	add_child_autofree(r)
	r.avancer(0.016)
	assert_false(r.pieces.bras_tendu.visible, "pièce dédiée d'un autre type : cachée au repos")
	r.jouer_geste("montrer")
	_avancer(r, 1.5)
	assert_true(r.pieces.bras_tendu_arriere.visible)
	assert_false(r.pieces.bras_arriere.visible)
	assert_true(r.pieces.bras_avant.visible, "le bras avant reste en place")
	_avancer(r, 4.0)
	assert_false(r.pieces.bras_tendu_arriere.visible)
	assert_true(r.pieces.bras_arriere.visible)
