extends GutTest
## Figurants avec pose (forme objet) et alias de décor avec etat_selon (audit texte-image, LD).

const CJ := preload("res://src/core/chapitre_jouable.gd")


func test_spec_figure_texte_et_objet() -> void:
	assert_eq(CJ.spec_figure("krenn").nom, "krenn")
	var s := CJ.spec_figure({"nom": "krenn", "geste": "assis_nettoyer", "miroir": true, "decalage": [4, -2], "echelle": 0.8})
	assert_eq(s.geste, "assis_nettoyer")
	assert_true(s.miroir)
	assert_eq(s.decalage, [4, -2])
	assert_almost_eq(s.echelle, 0.8, 0.001)


func test_poser_figure_sprite() -> void:
	var f := Sprite2D.new()
	f.position = Vector2(100, 100)
	CJ.poser_figure(f, CJ.spec_figure({"nom": "x", "miroir": true, "decalage": [10, 0], "echelle": 2.0, "geste": "inconnu"}))
	assert_eq(f.position, Vector2(110, 100))
	assert_almost_eq(f.scale.x, -2.0, 0.001)
	assert_almost_eq(f.scale.y, 2.0, 0.001)
	f.free()


func test_alias_etat_selon() -> void:
	var r := CJ.resoudre_decor("archive_fin")
	assert_eq(r.decor, "archive")
	assert_eq(CJ.etat_selon(r.etat_selon, {"choix_ep01_orvane": 1}), "fin_longue")
	assert_eq(CJ.etat_selon(r.etat_selon, {"choix_ep01_orvane": 2}), "fin_courte")
	assert_eq(CJ.resoudre_decor("archive_ch2_fin").etat, "ch2_fin")
	assert_true(CJ.resoudre_decor("orvane_matin").etat_selon.is_empty())
