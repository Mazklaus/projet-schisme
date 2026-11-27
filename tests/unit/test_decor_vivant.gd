extends GutTest
## Décors peints qui vivent (Ullanor) : dérive des fumées, drapeaux, souffle des Titans, particules.


func test_masque_drapeaux() -> void:
	var img := Decor25D.masque_drapeaux([[100, 50, 32, 40]], Vector2(400, 200))
	assert_eq(img.get_size(), Vector2i(200, 100), "à mi-résolution")
	assert_almost_eq(img.get_pixel(58, 25).r, 0.0, 0.02, "fixé en haut")
	assert_gt(img.get_pixel(58, 45).r, 0.8, "libre en bas")
	assert_eq(img.get_pixel(10, 10).r, 0.0, "rien hors des drapeaux")
	var petit := Decor25D.masque_drapeaux([[100, 50, 8, 40]], Vector2(400, 200))
	assert_lt(petit.get_pixel(52, 45).r, img.get_pixel(58, 45).r, "un petit fanion ondule moins")


func test_materiau_vivant() -> void:
	var tex := ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	var m := Decor25D.materiau_vivant({"derive": [4, 100, 0.02, -0.01], "souffle": [5, 7.0, 30],
		"drapeaux": [[10, 4, 8, 12]], "drapeau_px": 2.5}, tex)
	assert_string_contains(m.shader.code, "NORMAL_MAP", "les normales suivent")
	assert_eq(m.get_shader_parameter("taille_px"), Vector2(64, 32))
	assert_eq(m.get_shader_parameter("derive_px"), 4.0)
	assert_eq(m.get_shader_parameter("derive_vitesse"), Vector2(0.02, -0.01))
	assert_eq(m.get_shader_parameter("souffle_sol_px"), 30.0)
	assert_eq(m.get_shader_parameter("drapeau_px"), 2.5)
	assert_not_null(m.get_shader_parameter("drapeaux"))


func test_foule_reglable() -> void:
	assert_true(Decor25D.est_foule({"fichier": "calques/20_titans.png", "foule": {"vitesse": 0.5}}))
	var m := Decor25D.materiau_foule(null, "x", {"respiration": 0.004, "vitesse": 0.45})
	assert_eq(m.get_shader_parameter("respiration"), 0.004)
	assert_eq(m.get_shader_parameter("vitesse"), 0.45)


func test_ullanor_vit_sans_changer_la_composition() -> void:
	var d := Decor25D.lire("ullanor")
	assert_false(d.has("erreurs"), str(d.get("erreurs")))
	var vivants: Array = d.calques.filter(func(c): return c.has("vie")).map(func(c): return String(c.fichier).get_file())
	for f in ["00_ciel.png", "20_titans.png", "25_poussiere.png", "30_voie.png"]:
		assert_true(f in vivants, "calque vivant : " + f)
	assert_eq(d.particules.size(), 4)
	var dec := Decor25D.new()
	dec.id_decor = "ullanor"
	add_child_autofree(dec)
	var titans := dec.get_node("Calque_20_titans")
	assert_string_contains(((titans.get_node("Image") as Sprite2D).material as ShaderMaterial).shader.code, "souffle_px")
	assert_not_null(titans.get_node_or_null("Particules_fumee"), "fumée des Titans")
	assert_not_null(dec.get_node("Calque_30_voie").get_node_or_null("Particules_braises"))
	assert_not_null(dec.get_node("Calque_45_vaskar").get_node_or_null("Particules_poussiere"))
	# Même images, mêmes places : seules la matière et les particules bougent.
	assert_eq((titans.get_node("Image") as Sprite2D).position, Vector2.ZERO)


func test_particules() -> void:
	var e := Decor25D.particules({"type": "braises", "zone": [0, 100, 200, 50], "nombre": 12})
	assert_eq(e.amount, 12)
	assert_eq(e.position, Vector2(100, 125), "centrées sur la zone")
	assert_true(e.local_coords, "suivent la parallaxe de leur calque")
	assert_eq(e.preprocess, e.lifetime, "déjà là à l'ouverture du plan")
	e.free()
