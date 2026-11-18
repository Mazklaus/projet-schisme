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
	assert_eq(c[2].normales, "calques/40_perso_normal.png")
	assert_eq(c[2].ombre, "calques/40_perso_ombre.png")
	assert_almost_eq(c[1].voile[1], 1.0 - exp(-2.0), 0.001, "voile t = 1 - exp(-d/d0)")
	assert_eq([c[3].profondeur, c[3].lumiere], [1.0, false], "particules devant, non éclairées")


func test_construction() -> void:
	var dec := Decor25D.new()
	dec.dossier_decors = FIXTURES
	dec.id_decor = "guide_mini"
	add_child_autofree(dec)
	assert_eq(dec.calques.size(), 4)
	var perso := dec.calques[2]
	assert_not_null(perso.get_node_or_null("Ombre"))
	assert_eq((perso.get_node("Ombre").material as CanvasItemMaterial).blend_mode, CanvasItemMaterial.BLEND_MODE_MUL)
	assert_not_null((dec.calques[1].get_node("Image") as Sprite2D).material, "voile sur le fond")
	assert_eq(BudgetPerf.verifier_decor(dec), PackedStringArray())
