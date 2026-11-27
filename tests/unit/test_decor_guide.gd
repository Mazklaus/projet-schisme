extends GutTest
## Format du guide de style de la DA (§6) : <plan>.json, distances, _normal, _ombre, voile.

const FIXTURES := "res://tests/fixtures/decors"


func test_conversion() -> void:
	var d := Decor25D.lire("guide_mini", FIXTURES)
	assert_false(d.has("erreurs"), str(d.get("erreurs")))
	assert_eq(d.taille, [64.0, 36.0])
	var c: Array = d.calques
	assert_eq(c.size(), 4)
	assert_eq([c[0].profondeur, c[0].lumiere], [0.0, false], "ciel fixe, non éclairé")
	assert_almost_eq(c[1].profondeur, 5.0 / 6000.0, 0.0001, "parallaxe en 1/d")
	assert_eq(c[2].profondeur, 1.0, "le calque le plus proche sert de référence")
	assert_eq(c[2].fichier, "calques/40_perso_plat.png", "version plate préférée (lumière non cuite)")
	assert_eq(c[2].normales, "calques/40_perso_plat_normal.png")
	assert_eq(c[2].nom, "40_perso", "le nœud garde le nom du calque")
	assert_eq(c[2].ombre, "calques/40_perso_ombre.png")
	assert_almost_eq(c[1].voile[1], 1.0 - exp(-2.0), 0.001, "voile t = 1 - exp(-d/d0)")
	assert_eq([c[3].profondeur, c[3].lumiere], [1.0, false], "particules devant, non éclairées")
	assert_eq(c[3].melange, "addition")
	assert_false(c[0].has("melange"), "le ciel reste en mélange normal")


func test_construction() -> void:
	var dec := Decor25D.new()
	dec.dossier_decors = FIXTURES
	dec.id_decor = "guide_mini"
	add_child_autofree(dec)
	assert_eq(dec.calques.size(), 4)
	var perso := dec.calques[2]
	assert_eq(String(perso.name), "Calque_40_perso")
	assert_not_null(perso.get_node_or_null("Ombre"))
	# Ombre en multiplication dosée par son alpha (shader « blend_mul »).
	var mat := perso.get_node("Ombre").material as ShaderMaterial
	assert_not_null(mat)
	assert_string_contains(mat.shader.code, "blend_mul")
	assert_not_null((dec.calques[1].get_node("Image") as Sprite2D).material, "voile sur le fond")
	assert_eq(BudgetPerf.verifier_decor(dec), PackedStringArray())


func test_tete_separee() -> void:
	var dec := Decor25D.new()
	dec.dossier_decors = FIXTURES
	dec.id_decor = "guide_tete"
	add_child_autofree(dec)
	var couche := dec.calques[0]
	var noms := couche.get_children().map(func(n): return String(n.name))
	assert_eq(noms, ["Image", "Tete", "Avant"], "corps, tête puis col devant")
	var corps := (couche.get_node("Image") as Sprite2D).texture as CanvasTexture
	assert_string_ends_with(corps.diffuse_texture.resource_path, "45_perso_corps.png")
	var tete := couche.get_node("Tete") as Sprite2D
	assert_eq(tete.position, Vector2(32, 16), "pivot au cou")
	assert_eq(tete.offset, Vector2(-32, -16), "la tête reste à sa place au repos")
	assert_not_null((tete.texture as CanvasTexture).normal_texture)
	assert_almost_eq(float(tete.get_meta("rotation_max")), deg_to_rad(15.0), 0.001)
	assert_eq(dec.detacher_tete(couche.name), tete, "pas de découpe automatique si la tête est livrée")


func test_version_plate_seulement_sous_lumieres_du_moteur() -> void:
	assert_false(Decor25D.plan_eclaire({"cle": {"type": "soleil"}}), "soleil peint (Ullanor) : versions peintes")
	assert_true(Decor25D.plan_eclaire({"cle": {"type": "brasero (Light2D point)"}}))
	assert_true(Decor25D.plan_eclaire({"lumieres": [{"position_px": [0, 0]}]}))
	assert_false(Decor25D.plan_eclaire({"plat": false, "lumieres": [{}]}), "choix forcé dans le JSON")
	var u := Decor25D.lire("ullanor")
	for c in u.calques:
		assert_false(String(c.fichier).ends_with("_plat.png"), "Ullanor : %s" % c.fichier)


func _guide_interieur() -> Dictionary:
	return {"plan": "interieur", "cadre_px": [64, 36], "calques": [
		{"fichier": "calques/00_ciel.png", "distance_m": 10000.0, "note": "distance : infini m (valeur représentative ci-dessus)"},
		{"fichier": "calques/10_fond.png", "distance_m": 20},
		{"fichier": "calques/40_perso.png", "distance_m": 8}],
		"cle": {"type": "lampe (PointLight2D)", "position_px": [40, 10], "couleur": "#FFB868", "energie": 1.6, "portee_px": 30},
		"appoints": [{"type": "veille froide", "couleur": "#C8D2DC", "niveau": 0.3, "zone": "fond seulement ; ambiant 0,17 ailleurs"}]}


func test_infini_normalise_reste_sans_parallaxe() -> void:
	var d := Decor25D.depuis_guide(_guide_interieur(), FIXTURES.path_join("guide_mini"))
	assert_eq(d.calques[0].profondeur, 0.0, "10000 + note « infini » : ciel fixe")
	assert_eq(d.calques[0].lumiere, false)


func test_ambiant_ecrit_avec_virgule_avant_ailleurs() -> void:
	var d := Decor25D.depuis_guide(_guide_interieur(), FIXTURES.path_join("guide_mini"))
	assert_almost_eq(Color(d.ambiant).r, 0.17, 0.01, "« ambiant 0,17 ailleurs »")


func test_personnages_eclaires_par_une_cle_basse_a_eux() -> void:
	var d := Decor25D.depuis_guide(_guide_interieur(), FIXTURES.path_join("guide_mini"))
	assert_eq(d.calques[2].get("masque_lumiere"), Decor25D.MASQUE_PERSONNAGES)
	assert_false(d.calques[1].has("masque_lumiere"), "le décor garde la clé haute")
	var basses: Array = d.lumieres.filter(func(e): return e.get("masque", 0) == Decor25D.MASQUE_PERSONNAGES)
	assert_eq(basses.size(), 1)
	assert_eq(basses[0].hauteur_px, Decor25D.HAUTEUR_MODELE_PX)
