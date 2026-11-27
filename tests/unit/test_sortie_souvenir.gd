extends GutTest
## Règle GD : les réglages d'image d'un souvenir (lumière de l'Empereur, surexposition) ne
## débordent pas du souvenir ; à chaque changement de décor, l'image revient à l'étalonnage du lieu.


func test_retour_aux_quartiers_apres_l_unification() -> void:
	# Le chapitre 2 sans son dialogue : seul le test change de décor.
	var sauve: Array = [Jeu.etat.duplicate(true), Catalogue.episodes.duplicate(true)]
	var c02: Dictionary = Catalogue.chapitre("ep01", "c02").duplicate(true)
	c02.erase("dialogue")
	Catalogue.episodes["test_souvenir"] = {"id": "test_souvenir", "numero": 99, "chapitres": [c02]}
	Jeu.etat.episode = "test_souvenir"
	Jeu.etat.chapitre = c02.id
	var ch: ChapitreJouable = load("res://scenes/chapitres/chapitre_jouable.tscn").instantiate()
	add_child_autofree(ch)
	await wait_frames(2)
	await ch._changer_decor("terra_unification")
	ch._lumiere_montante({"lumiere": {"position_px": [1240, 520], "energie": 2.5, "rayon_px": 900},
		"ambiance": "#FFF6E6", "duree": 0.3})
	await wait_seconds(0.2)
	assert_eq(get_tree().get_nodes_in_group("souvenir_surexpose").size(), 1)
	await ch._changer_decor("vs_quartiers_27")
	var amb := ch.get_node("Ambiance") as CanvasModulate
	var quartiers := ch.decor_par_id("vs_quartiers_27")
	var normal: Color = quartiers.ambiant if quartiers is Decor25D and quartiers.ambiant.a > 0.0 else amb.get_meta("defaut")
	assert_gt(amb.color.get_luminance(), normal.get_luminance(), "fondu depuis la surexposition")
	await wait_seconds(ChapitreJouable.SORTIE_SOUVENIR_S + 2.0)
	assert_true(amb.color.is_equal_approx(normal), "étalonnage des quartiers : %s attendu, %s" % [normal, amb.color])
	assert_eq(get_tree().get_nodes_in_group("souvenir_surexpose").filter(func(n): return not n.is_queued_for_deletion()).size(), 0)
	Jeu.etat = sauve[0]
	Catalogue.episodes = sauve[1]
