extends GutTest
## MiseEnScene (Level Designer) : effets des « mises_en_scene » des fichiers jeu, conditions,
## déclenchement à la réplique, nettoyage au changement de décor.

var mes: MiseEnScene
var decor: Node2D
var image: Sprite2D


func before_each() -> void:
	decor = Node2D.new()
	var calque := Node2D.new()
	calque.name = "Calque_36_etendard"
	image = Sprite2D.new()
	image.name = "Image"
	image.position = Vector2(10, 20)
	calque.add_child(image)
	decor.add_child(calque)
	add_child_autofree(decor)
	mes = MiseEnScene.new()
	mes.camera = Camera2D.new()
	add_child_autofree(mes.camera)
	add_child_autofree(mes)


func _compter(prefixe: String) -> int:
	var n := 0
	for e in mes.effets():
		if String(e.name).begins_with(prefixe):
			n += 1
	return n


func test_conditions_du_dlg_et_enchainees() -> void:
	var d := {"choix_ep01_orvane": 1, "vivant_ilse": true}
	assert_true(MiseEnScene.condition_vraie("", d))
	assert_true(MiseEnScene.condition_vraie("choix_ep01_orvane == 1", d))
	assert_false(MiseEnScene.condition_vraie("choix_ep01_orvane != 1", d))
	assert_true(MiseEnScene.condition_vraie("vivant_ilse == true and choix_ep01_orvane == 1", d))
	assert_false(MiseEnScene.condition_vraie("vivant_ilse == false and choix_ep01_orvane == 1", d))
	assert_false(MiseEnScene.condition_vraie("absent", d), "drapeau absent : faux")


func test_intervalle_tire_dans_ses_bornes() -> void:
	for i in 20:
		var p := MiseEnScene.point([[700, 1700], 540])
		assert_between(p.x, 700.0, 1700.0)
		assert_eq(p.y, 540.0)


func test_particules_posees_au_centre_de_la_zone() -> void:
	mes.jouer({"particules": [{"type": "braises", "zone_px": [100, 200, 80, 40], "densite": 0.5}]}, decor)
	var p := mes.effets()[0] as CPUParticles2D
	assert_not_null(p)
	assert_eq(p.position, Vector2(140, 220))
	assert_true(p.emitting)
	assert_eq(p.get_parent(), decor, "un nœud enfant du décor par effet")


func test_element_conditionnel_ignore_si_faux() -> void:
	mes.drapeaux = {"choix_ep01_orvane": 2}
	mes.jouer({"particules": [{"type": "poussiere", "zone_px": [0, 0, 10, 10], "si": "choix_ep01_orvane == 1"}]}, decor)
	assert_eq(mes.effets().size(), 0)


func test_apres_ligne_attend_la_replique() -> void:
	mes.jouer({"eclairs": [{"position_px": [960, 520], "energie": 1.0, "apres_ligne": 2}]}, decor)
	assert_eq(_compter("Eclair"), 0)
	mes.ligne()
	assert_eq(_compter("Eclair"), 0, "pas à la 1re réplique")
	mes.ligne()
	assert_eq(_compter("Eclair"), 1, "à la 2e")


func test_nouveau_noeud_oublie_les_attentes() -> void:
	mes.jouer({"eclairs": [{"position_px": [0, 0], "apres_ligne": 1}]}, decor)
	mes.jouer({}, decor)
	mes.ligne()
	assert_eq(_compter("Eclair"), 0)


func test_tirs_tires_de_la_reserve() -> void:
	mes.jouer({"tirs": [{"de": [100, 100], "vers": [900, 900], "cadence_s": 0.05}]}, decor)
	assert_eq(_compter("Tirs"), 1)
	await wait_seconds(0.6)
	var traits := _compter("Trait")
	assert_gt(traits, 0, "des tirs sont partis")
	assert_lte(traits, MiseEnScene.RESERVE_TIRS * 4, "réserve bornée")


func test_arret_puis_reprise_des_tirs() -> void:
	mes.jouer({"tirs": [{"de": [1500, 500], "vers": [100, 700]}, {"de": [300, 500], "vers": [100, 700]}]}, decor)
	mes.jouer({"arret_tirs": {"duree": 0.1, "sens": "droite_vers_gauche"}}, decor)
	await wait_seconds(0.3)
	for em in mes.effets():
		if String(em.name).begins_with("Tirs"):
			assert_true(em.get_meta("arrete", false))
	mes.jouer({"reprise_tirs": {}}, decor)
	for em in mes.effets():
		if String(em.name).begins_with("Tirs"):
			assert_false(em.get_meta("arrete", false))


func test_calque_monte_puis_rendu_au_nettoyage() -> void:
	mes.jouer({"calques": [{"calque": "Calque_36_etendard", "anim": "monter", "amplitude_px": 80, "duree": 0.1}]}, decor)
	await wait_seconds(0.3)
	assert_almost_eq(image.position.y, -60.0, 0.5, "monté de 80 px")
	mes.nettoyer()
	assert_eq(image.position, Vector2(10, 20), "le décor est réutilisé : calque remis en place")


func test_calque_absent_sans_erreur() -> void:
	mes.jouer({"calques": [{"calque": "Calque_99_absent", "anim": "osciller"}]}, decor)
	assert_eq(mes.effets().size(), 0)


func test_tremblement_revient_a_zero() -> void:
	mes.jouer({"tremblement": [{"amplitude_px": 8, "duree": 0.2}]}, decor)
	await wait_seconds(0.4)
	assert_eq(mes.camera.offset, Vector2.ZERO)


func test_nettoyer_retire_tout() -> void:
	mes.jouer({"particules": [{"type": "fumee", "zone_px": [0, 0, 10, 10]}],
		"eclairs": [{"position_px": [0, 0], "jusqu_a_ligne": 3}],
		"tirs": [{"de": [0, 0], "vers": [10, 10]}]}, decor)
	assert_gt(mes.effets().size(), 0)
	mes.nettoyer()
	assert_eq(mes.effets().size(), 0)


func test_donnees_ep01_lisibles() -> void:
	# Toutes les mises en scène de l'épisode 1 se jouent sans erreur sur un décor vide.
	for c in ["c01", "c02", "c03", "c04", "c05"]:
		var z = JSON.parse_string(FileAccess.get_file_as_string("res://data/episodes/ep01/%s_jeu.json" % c))
		assert_eq(typeof(z), TYPE_DICTIONARY, c)
		for noeud in z.get("mises_en_scene", {}):
			mes.jouer(z.mises_en_scene[noeud], decor)
			for i in 14:
				mes.ligne()
			mes.nettoyer()
	assert_eq(mes.effets().size(), 0)


func test_plein_ecran_survit_au_nettoyage_et_se_retire_seul() -> void:
	mes.jouer({"plein_ecran": {"dossier": "res://assets/plans/oeil_vaskar", "image": "10_oeil_ouvert.png",
		"clignement": ["20_paupiere_mi.png", "21_paupiere_fermee.png"],
		"entree_s": 0.05, "tenue_s": 0.3, "sortie_s": 0.05}}, decor)
	assert_not_null(mes.get_node_or_null("PleinEcran"), "posé par-dessus tout")
	mes.nettoyer()
	assert_not_null(mes.get_node_or_null("PleinEcran"), "il couvre la coupe de décor : pas retiré par nettoyer()")
	await wait_seconds(0.8)
	assert_null(mes.get_node_or_null("PleinEcran"), "retiré seul à la fin")
