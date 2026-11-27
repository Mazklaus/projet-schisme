extends GutTest


func _decor(id: String) -> Decor25D:
	var d := Decor25D.new()
	d.id_decor = id
	add_child_autofree(d)
	return d


func test_decor_demo_construit() -> void:
	var d := _decor("demo")
	assert_eq(d.calques.size(), 5)
	assert_eq(d.taille, Vector2(2560, 1080))
	var ciel := d.calques[0]
	assert_almost_eq(ciel.scroll_scale.x, 0.05, 0.001)
	assert_eq((ciel.get_node("Image") as Sprite2D).light_mask & Decor25D.MASQUE_LUMIERE, 0, "le ciel n'est pas éclairé par les lumières du plan")
	var colonne := d.calques[4]
	assert_eq((colonne.get_node("Image") as Sprite2D).position, Vector2(1700, 380))
	var tex := (colonne.get_node("Image") as Sprite2D).texture as CanvasTexture
	assert_not_null(tex.normal_texture)


func test_validation_decor() -> void:
	assert_eq(Decor25D.valider({"version": 1, "taille": [10, 10], "calques": [{"fichier": "a.png"}]}), PackedStringArray())
	assert_gt(Decor25D.valider({"version": 2, "taille": [10, 10], "calques": [{"fichier": "a.png"}]}).size(), 0)
	assert_gt(Decor25D.valider({"version": 1, "taille": [10, 10], "calques": [{"fichier": "a.png", "profondeur": 5}]}).size(), 0)
	assert_gt(Decor25D.valider({"version": 1, "taille": [10, 10], "calques": []}).size(), 0)


func test_tous_les_decors_respectent_le_budget() -> void:
	var dir := DirAccess.open(Decor25D.DOSSIER)
	assert_not_null(dir)
	var n := 0
	for id in dir.get_directories():
		var d := _decor(id)
		assert_gt(d.calques.size(), 0, id)
		assert_eq(BudgetPerf.verifier_decor(d), PackedStringArray(), id)
		n += 1
	assert_gt(n, 0)


func test_scene_demo_se_charge() -> void:
	var s := load("res://scenes/demo/chapitre_demo.tscn") as PackedScene
	assert_not_null(s)
	var st := s.get_state()
	var noms := []
	for i in st.get_node_count():
		noms.append(st.get_node_name(i))
	for n in ["Decor", "Soleil", "Camera", "Boite"]:
		assert_has(noms, n)


func test_calques_alignes_dans_le_cadre_de_reference() -> void:
	# Parallax2D place le calque à (1 - p) × coin_caméra + scroll_offset : avec la caméra
	# centrée sur le décor, ce décalage doit être nul pour toutes les profondeurs.
	var d := _decor("demo")
	var coin := d.taille / 2.0 - Decor25D.taille_ecran() / 2.0
	for c in d.calques:
		var decalage := (Vector2.ONE - c.scroll_scale) * coin + c.scroll_offset
		assert_almost_eq(decalage.length(), 0.0, 0.01, c.name)
