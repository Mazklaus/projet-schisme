extends GutTest
## Vie des figures immobiles (respiration, balancement) et de la foule peinte.


func _figure(nom: String, echelle := 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = nom
	s.scale = Vector2.ONE * echelle
	add_child_autofree(s)
	return s


func test_respiration_bornee_et_pieds_fixes() -> void:
	var s := _figure("frere_1", 0.8)
	var v := VieFigure.animer(s)
	var bas := INF
	var haut := -INF
	for i in 120:
		v.appliquer(i * 0.1)
		assert_almost_eq(s.scale.x, 0.8, 0.0001, "jamais d'élargissement")
		assert_eq(s.position, Vector2.ZERO, "les pieds ne bougent pas")
		bas = minf(bas, s.scale.y)
		haut = maxf(haut, s.scale.y)
		assert_lte(absf(s.skew), v.balancement + 0.0001)
	assert_almost_eq(bas, 0.8, 0.002, "repos à l'échelle de base")
	assert_almost_eq(haut, 0.8 * (1.0 + v.respiration), 0.002, "inspiration complète")


func test_deux_figurants_desynchronises() -> void:
	var a := _figure("frere_1")
	var b := _figure("frere_2")
	var va := VieFigure.animer(a)
	var vb := VieFigure.animer(b)
	var ecart := 0.0
	for i in 60:
		va.appliquer(i * 0.1)
		vb.appliquer(i * 0.1)
		ecart = maxf(ecart, absf(a.scale.y - b.scale.y))
	assert_gt(ecart, 0.002, "pas de foule qui respire à l'unisson")
	# Même nom : même mouvement d'une partie à l'autre.
	# (Deux nœuds frères ne peuvent pas porter le même nom : la graine est passée à part.)
	var c := _figure("autre")
	var vc := VieFigure.animer(c, "frere_1")
	vc.appliquer(2.3)
	va.appliquer(2.3)
	assert_almost_eq(c.scale.y, a.scale.y, 0.00001)
	assert_eq(VieFigure.animer(a), va, "une seule vie par figure")


func test_reprendre_une_nouvelle_echelle() -> void:
	var s := _figure("vaskar_enfant")
	var v := VieFigure.animer(s)
	v.appliquer(1.0)
	s.scale = Vector2.ONE * 0.55
	v.reprendre()
	v.appliquer(1.0)
	assert_almost_eq(s.scale.x, 0.55, 0.0001)
	assert_between(s.scale.y, 0.55, 0.55 * (1.0 + v.respiration) + 0.0001)


func test_intensite_nulle_fige() -> void:
	var s := _figure("ilse")
	var v := VieFigure.animer(s)
	v.intensite = 0.0
	v.appliquer(3.7)
	assert_eq(s.scale, Vector2.ONE)
	assert_eq(s.skew, 0.0)


func test_joueur_respire_moins_en_marchant() -> void:
	var j := PersonnageJoue.new()
	j.sprite = Sprite2D.new()
	j.add_child(j.sprite)
	add_child_autofree(j)
	var v := VieFigure.animer(j.sprite)
	v.intensite = 0.25
	j._process(0.1)
	assert_almost_eq(v.intensite, 0.55, 0.001, "retour en fondu vers la pleine respiration à l'arrêt")
	j._process(1.0)
	assert_eq(v.intensite, 1.0)


func test_calques_de_foule() -> void:
	assert_true(Decor25D.est_foule({"fichier": "calques/40_personnages.png"}))
	assert_true(Decor25D.est_foule({"fichier": "calques/gabarit_25_personnages_fond.png"}))
	assert_true(Decor25D.est_foule({"fichier": "calques/40_personnages_plat.png", "nom": "40_personnages"}))
	assert_false(Decor25D.est_foule({"fichier": "calques/10_collines.png"}))
	assert_false(Decor25D.est_foule({"fichier": "calques/40_personnages.png", "foule": false}), "désactivable")
	assert_true(Decor25D.est_foule({"fichier": "calques/45_vaskar.png", "foule": true}), "activable")
	assert_false(Decor25D.est_foule({"fichier": "calques/40_personnages.png", "tete": {}}), "tête livrée à part")


func test_lignes_de_pieds() -> void:
	# 64 × 40 : une figure de x 8 à 23 (pieds à y 32), une autre de x 40 à 55 (pieds à y 20).
	var img := Image.create(64, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(8, 4, 16, 28), Color.WHITE)
	img.fill_rect(Rect2i(40, 4, 16, 16), Color.WHITE)
	var p := Decor25D.lignes_de_pieds(img)
	assert_eq(p.get_width(), 64 / Decor25D.FOULE_COLONNE_PX)
	assert_almost_eq(p.get_pixel(1, 0).r, 32.0 / 40.0, 0.11, "pieds de la première figure")
	assert_almost_eq(p.get_pixel(5, 0).r, 20.0 / 40.0, 0.11, "pieds de la seconde")
	assert_almost_eq(p.get_pixel(0, 0).r, p.get_pixel(1, 0).r, 0.001, "colonne vide : voisine la plus proche")
	assert_almost_eq(p.get_pixel(7, 0).r, p.get_pixel(5, 0).r, 0.001)
	var vide := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	vide.fill(Color(0, 0, 0, 0))
	assert_eq(Decor25D.lignes_de_pieds(vide).get_pixel(0, 0).r, 0.0, "rien ne bouge")


func test_materiau_foule() -> void:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var m := Decor25D.materiau_foule(ImageTexture.create_from_image(img), "Calque_40_personnages")
	assert_string_contains(m.shader.code, "NORMAL_MAP", "les normales suivent la figure")
	assert_gt(float(m.get_shader_parameter("respiration")), 0.0)
	assert_eq(m.get_shader_parameter("taille_px"), Vector2(32, 32))
	assert_not_null(m.get_shader_parameter("pieds"))
