extends GutTest
## Règle GD 27/11 : aucune étiquette de débogage dans une build exportée.


func test_build_exportee_sans_etiquette() -> void:
	OS.set_environment("SCHISME_SANS_DEBUG", "1")
	assert_false(ChapitreJouable.etiquettes_de_debogage())
	var ch := ChapitreJouable.new()
	var s: Sprite2D = ch._sprite_provisoire("krenn")
	assert_eq(s.find_children("*", "Label", true, false).size(), 0, "pas de nom au-dessus de la silhouette")
	s.free()
	ch.free()
	OS.unset_environment("SCHISME_SANS_DEBUG")


func test_etiquettes_seulement_dans_l_editeur() -> void:
	assert_eq(ChapitreJouable.etiquettes_de_debogage(), OS.has_feature("editor"))
