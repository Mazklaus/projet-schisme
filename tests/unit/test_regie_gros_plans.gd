extends GutTest
## Régie des gros plans (règle GD 27/11) : ouverture large, côtés fixes, pas de ping-pong,
## respiration après quatre gros plans, surcharges du Narrative. Les bustes sont simulés.

class RegieTest extends RegieGrosPlans:
	func buste_existe(_perso: String, _cote: String) -> bool:
		return true


func _regie() -> RegieGrosPlans:
	var r := RegieTest.new({"scenes": [{"chapitre": "c01", "decor": "fond", "noeuds": ["nuit*"],
		"cotes": {"DREMM": "gauche", "VASKAR": "droite"}}]})
	r.entrer("c01", "nuit")
	return r


func _rep(perso: String, texte := "Une réplique assez longue pour durer plus de deux secondes.") -> Dictionary:
	return {"type": "replique", "personnage": perso, "humeur": "", "texte": texte}


func test_ouverture_puis_gros_plan_sur_le_locuteur() -> void:
	var r := _regie()
	assert_eq(r.decider(_rep("DREMM")), "large", "première réplique de la scène")
	assert_eq(r.decider(_rep("VASKAR")), "VASKAR")
	assert_eq(r.cote_du_plan(), "droite", "règle des 180°")
	assert_eq(r.decider(_rep("DREMM")), "DREMM")
	assert_eq(r.cote_du_plan(), "gauche")


func test_narrateur_et_choix_rouvrent_en_large() -> void:
	var r := _regie()
	r.decider(_rep("DREMM"))
	r.decider(_rep("VASKAR"))
	assert_eq(r.decider(_rep("")), "large", "narration")
	assert_eq(r.decider(_rep("DREMM")), "large", "réplique après la narration")
	assert_eq(r.decider(_rep("VASKAR")), "VASKAR")
	assert_eq(r.decider({"type": "choix", "options": []}), "large")
	assert_eq(r.decider(_rep("VASKAR")), "large", "réplique après un choix")


func test_replique_courte_garde_le_plan() -> void:
	var r := _regie()
	r.decider(_rep("DREMM"))
	assert_eq(r.decider(_rep("VASKAR")), "VASKAR")
	assert_eq(r.decider(_rep("DREMM", "Non.")), "VASKAR", "moins de 2 s : pas de ping-pong")


func test_respiration_apres_quatre_gros_plans() -> void:
	var r := _regie()
	r.decider(_rep("DREMM"))
	for i in 4:
		assert_ne(r.decider(_rep("VASKAR" if i % 2 == 0 else "DREMM")), "large")
	assert_eq(r.decider(_rep("VASKAR")), "large", "cinquième : on respire")
	assert_eq(r.decider(_rep("DREMM")), "DREMM")


func test_surcharges() -> void:
	var r := _regie()
	r.surcharger("serre:vaskar")
	assert_eq(r.decider(_rep("")), "VASKAR", "réaction muette sur une ligne de narration")
	r.surcharger("large")
	assert_eq(r.decider(_rep("DREMM")), "large")
	assert_eq(r.decider(_rep("DREMM")), "DREMM", "la règle reprend ensuite")
	r.surcharger("serre:krenn")
	assert_eq(r.decider(_rep("")), "KRENN", "personnage hors des côtés de la scène")
	assert_eq(r.cote_du_plan(), "gauche")


func test_hors_scene_et_sans_buste_reste_large() -> void:
	var r := RegieGrosPlans.new({"scenes": [{"chapitre": "c01", "decor": "fond", "noeuds": ["nuit*"],
		"cotes": {"SERGENT": "gauche"}}]})
	r.entrer("c01", "nuit")
	r.decider(_rep("SERGENT"))
	assert_eq(r.decider(_rep("SERGENT")), "large", "aucun buste de CA1 livré : inerte")
	r.entrer("c01", "aube")
	r.surcharger("serre:sergent")
	assert_eq(r.decider(_rep("SERGENT")), "large", "hors scène")
	assert_true(RegieGrosPlans.est_surcharge("serre:krenn"))
	assert_false(RegieGrosPlans.est_surcharge("archive_table"))


func test_expression_suit_l_humeur_du_personnage_cadre() -> void:
	var r := _regie()
	r.decider(_rep("DREMM"))
	var e := _rep("DREMM")
	e.humeur = "assurance"
	assert_eq(r.decider(e), "DREMM")
	assert_eq(r.expression, "assurance")
	assert_eq(r.decider(_rep("VASKAR")), "VASKAR")
	assert_eq(r.expression, "neutre", "nouveau cadrage : neutre")
	var enfant := _rep("DREMM")
	enfant.humeur = "enfant"
	assert_eq(r.decider(enfant), "large", "Dremm enfant : pas le buste adulte")


func test_bustes_finaux_de_ca1() -> void:
	var d := "res://assets/personnages/"
	assert_eq(RegieGrosPlans.chemin_buste("DREMM", "droite", "assurance"), d + "dremm/buste_droite_assurance.png")
	assert_eq(RegieGrosPlans.chemin_buste("SEFA", "gauche", "colere"), d + "sefa/buste_gauche_neutre.png",
		"expression non peinte : neutre")
	assert_eq(RegieGrosPlans.chemin_buste("ILSE", "gauche"), d + "ilse/buste_gauche_neutre.png")
	assert_true(RegieGrosPlans.new().buste_existe("ILSE", "gauche"))
	assert_eq(RegieGrosPlans.chemin_buste("SERGENT", "gauche"), d + "sergent/buste.png")
	assert_false(RegieGrosPlans.new().buste_existe("SERGENT", "gauche"))
	assert_true(RegieGrosPlans.eclairage_buste("SEFA", "droite").has("fonds"))


func test_eclairage_du_buste() -> void:
	var CJ = load("res://src/core/chapitre_jouable.gd")
	var ecl := RegieGrosPlans.eclairage_buste("DREMM", "droite")
	var n: Array = CJ.construire_eclairage_buste(ecl, "barge_quartiers_civils_gros_plan", "droite")
	assert_eq(n.size(), 3)
	assert_eq((n[0] as CanvasModulate).color, Color("#17161A"))
	assert_eq((n[1] as PointLight2D).position, Vector2(1920 - 895, 720), "x symétrisé à droite")
	assert_almost_eq((n[2] as Light2D).energy, 0.25, 0.001)
	var nuit: Array = CJ.construire_eclairage_buste(RegieGrosPlans.eclairage_buste("DREMM", "gauche"),
		"ullanor_nuit_gros_plan", "gauche")
	assert_true(nuit[1] is PointLight2D, "feu par en dessous : source sous le cadre")
	assert_true((nuit[1] as Node2D).position.y > 1080.0 and (nuit[1] as Node2D).position.x < 480.0,
		"feu en bas à gauche")
	assert_true(nuit[2] is DirectionalLight2D, "lune en contre")
	var sans: Array = CJ.construire_eclairage_buste({}, "ullanor_nuit_gros_plan", "droite")
	assert_true((sans[1] as Node2D).position.x > 1440.0, "fond seul, à droite : symétrisé")
	nuit.append_array(sans)
	assert_almost_eq((nuit[0] as CanvasModulate).color.b, 0.6039 * 0.34, 0.01, "ambiance × gain")
	for x in n + nuit:
		x.free()


func test_cadrage_tete_du_gabarit() -> void:
	var CJ = load("res://src/core/chapitre_jouable.gd")
	var tete: Dictionary = CJ.tete_du_fond("barge_quartiers_civils_gros_plan", "gauche")
	var sp: Sprite2D = CJ.construire_sprite_buste("res://assets/personnages/dremm/buste_gauche_neutre.png", tete, "gauche", "DREMM")
	var b: Dictionary = CJ.cadrage().bustes.DREMM.gauche
	var crane: float = sp.position.y + float(b.crane) * sp.scale.y
	var menton: float = sp.position.y + float(b.menton) * sp.scale.y
	assert_almost_eq(crane / 1080.0, 0.15, 0.005, "crâne à 15 % (DA)")
	assert_almost_eq(menton / 1080.0, 0.45, 0.005, "menton à 45 % (DA)")
	assert_almost_eq(sp.position.x + float(b.x) * sp.scale.x, float(tete.x), 0.5, "axe du gabarit")
	assert_true(sp.material is ShaderMaterial, "normales dosées")
	sp.free()


class RegieSansBusteIlse extends RegieGrosPlans:
	func buste_existe(perso: String, _cote: String) -> bool:
		return perso != "ILSE"


func test_replique_courte_sans_buste_repasse_en_large() -> void:
	var r := RegieSansBusteIlse.new({"scenes": [{"chapitre": "c01", "decor": "fond", "noeuds": ["nuit*"],
		"cotes": {"DREMM": "gauche", "ILSE": "droite"}}]})
	r.entrer("c01", "nuit")
	r.decider(_rep("DREMM"))
	assert_eq(r.decider(_rep("DREMM")), "DREMM")
	assert_eq(r.decider(_rep("ILSE", "Oui.")), "large", "pas le visage de Dremm sur la voix d'Ilse")
