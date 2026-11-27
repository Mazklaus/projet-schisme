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
		"cotes": {"DREMM": "gauche"}}]})
	r.entrer("c01", "nuit")
	r.decider(_rep("DREMM"))
	assert_eq(r.decider(_rep("DREMM")), "large", "aucun buste de CA1 livré : inerte")
	r.entrer("c01", "aube")
	r.surcharger("serre:dremm")
	assert_eq(r.decider(_rep("DREMM")), "large", "hors scène")
	assert_true(RegieGrosPlans.est_surcharge("serre:krenn"))
	assert_false(RegieGrosPlans.est_surcharge("archive_table"))
