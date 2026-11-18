extends GutTest
## Critères QA de la tranche verticale (game-design-tv.md) et fidélité au script figé
## (script-tv.md v0.3). Le parcours complet, branche par branche, est joué par
## tools/ci/parcours_ullanor.gd dans la CI.

const DLG := "res://data/dialogues/ep01/ullanor.dlg"
const SCENE := "res://scenes/ullanor/tranche_ullanor.tscn"

var d: Dictionary


func before_all() -> void:
	d = FormatDialogue.charger(DLG)


## Joue un nœud jusqu'à la fin, en exécutant les commandes « à blanc ».
func _jouer(noeud: String, drapeaux: Dictionary, expirer := false) -> Dictionary:
	var l := LecteurDialogue.new(d, drapeaux)
	l.demarrer(noeud)
	var commandes: Array[String] = []
	var textes: Array[String] = []
	for i in 500:
		var e := l.avancer()
		match e.type:
			"fin":
				break
			"commande":
				commandes.append(("%s %s" % [e.nom, " ".join(e.args)]).strip_edges())
			"replique":
				textes.append(e.texte)
			"choix":
				assert_true(expirer, "menu inattendu")
				l.expirer()
	return {"commandes": commandes, "textes": textes}


func test_dialogue_valide_et_complet() -> void:
	assert_eq(d.erreurs, [] as Array[String])
	for n in ["ouverture", "poi_etendard", "poi_freres", "poi_ilse", "vox_relance", "vox_eboulement",
			"vox_rappel", "choix", "sortir", "auxiliaires", "obeir", "fin"]:
		assert_true(d.noeuds.has(n), "nœud " + n)


func test_choix_minute_8_s_et_silence_vaut_obeir() -> void:
	var menu: Dictionary = d.noeuds.choix[0]
	assert_eq(menu.type, "menu")
	assert_eq(menu.options.map(func(o): return o.texte), ["La sortir", "Appeler des auxiliaires", "Obéir"])
	assert_eq(menu.delai, 8.0)
	assert_eq(menu.cible_delai, "obeir")
	var dr := {}
	_jouer("choix", dr, true)
	assert_eq(dr.choix_ullanor, 3, "le silence mène à « obéir »")
	assert_false(dr.soldate_vivante)


func _verifier_branche(noeud: String, attendu: Dictionary, echo: String, variante: String) -> void:
	var dr := {}
	var r := _jouer(noeud, dr)
	for cle in attendu:
		assert_eq(dr.get(cle), attendu[cle], "%s : %s" % [noeud, cle])
	assert_has(r.commandes, "carton 3 " + echo, "écho de " + noeud)
	assert_has(r.commandes, "montrer Ullanor/Calque_30_voie/" + variante, "variante 5e de " + noeud)
	assert_has(r.commandes, "sauver")
	# La sauvegarde contient le drapeau et les deux relations (critère QA).
	var etat := Sauvegarde.etat_vierge()
	etat.drapeaux = dr
	assert_eq(Sauvegarde.ecrire(5, etat), OK)
	var lu: Dictionary = Sauvegarde.lire(5).drapeaux
	for cle in ["soldate_vivante", "relation_dremm", "relation_ilse"]:
		assert_true(lu.has(cle), "%s sauvegardé (%s)" % [cle, noeud])


func test_branche_sortir() -> void:
	_verifier_branche("sortir", {"soldate_vivante": true, "relation_dremm": -1, "relation_ilse": 2,
		"trait_compassion": 1, "soldate_connait_sauveur": true}, "Elle s'en souviendra.", "IlsePlaque")
	assert_has(_jouer("sortir", {}).commandes, "plan 5a_retard", "5a : il arrive en retard")


func test_branche_auxiliaires() -> void:
	_verifier_branche("auxiliaires", {"soldate_vivante": true, "relation_dremm": 0, "relation_ilse": 0,
		"soldate_connait_sauveur": false}, "Personne ne saura qui l'a sauvée.", "Civiere")
	assert_has(_jouer("auxiliaires", {}).commandes, "plan 5a_rang", "5a : il est à sa place")


func test_branche_obeir() -> void:
	_verifier_branche("obeir", {"soldate_vivante": false, "relation_dremm": 1, "trait_obeissance": 1},
		"Le capitaine s'en souviendra.", "PoutreSeule")


func test_relations_bornees() -> void:
	var dr := {"relation_ilse": 2}
	_jouer("sortir", dr)
	assert_eq(dr.relation_ilse, 3, "relation de -3 à +3")


func test_texte_fidele_au_script() -> void:
	var fin: Array = _jouer("fin_5b", {"choix_ullanor": 3}).textes
	assert_eq(fin, ["Ce titre, vous l'avez gagné avec moi.", "Il vous appartient autant qu'à moi.",
		"Gardez-le, et rien ne nous arrêtera."])
	assert_eq(_jouer("vox_relance", {}).textes, ["Hol. Tu te perds encore dans les tunnels ?"])
	assert_eq(_jouer("vox_rappel", {}).textes, ["Rassemblement. Le Maître de Guerre parle. Maintenant."])
	var ouverture: Array = _jouer("ouverture", {}).commandes
	assert_has(ouverture, "titre 4 Ullanor. 000.M31.")
	assert_has(ouverture, "titre 3 Maître de Guerre.")
	assert_eq(ouverture[-1], "jeu", "l'ouverture rend la main au joueur")
	# « Environ 15 lignes de texte » : compte des répliques et narrations.
	var n := 0
	for nom in d.noeuds:
		for i in d.noeuds[nom]:
			if i.type == "replique":
				n += 1
	assert_between(n, 12, 18)


func test_scene_et_reglages() -> void:
	var s: Node = load(SCENE).instantiate()
	assert_eq(s.POI.size(), 3, "3 points d'intérêt")
	assert_eq(s.RELANCE_VOX_S, 30.0, "relance vox après 30 s")
	assert_gt(s.EBOULEMENT_X, s.POI.poi_ilse.x, "l'éboulement a lieu derrière Vaskar")
	assert_gt(s.RASSEMBLEMENT_X, s.EBOULEMENT_X)
	s.free()


func test_hochement_de_dremm() -> void:
	assert_has(_jouer("auxiliaires", {}).commandes, "hochement", "5a : Dremm hoche la tête")
	assert_does_not_have(_jouer("sortir", {}).commandes, "hochement", "5a sauvée : il ne dit rien")
	var dec := Decor25D.new()
	dec.id_decor = "ullanor"
	add_child_autofree(dec)
	var tete := dec.detacher_tete("Calque_48_dremm")
	assert_not_null(tete)
	var zone := Rect2i(tete.region_rect)
	assert_between(zone.size.y, 60, 160, "la tête s'arrête aux épaules")
	assert_between(zone.size.x, 120, 260)
	var masque: Vector4 = (dec.get_node("Calque_48_dremm/Image").material as ShaderMaterial).get_shader_parameter("masque")
	assert_gt(masque.z, 0.0, "le calque d'origine masque la tête")
	assert_eq((tete.material as ShaderMaterial).get_shader_parameter("masque"), Vector4.ZERO)


func test_decors_complets() -> void:
	var u := Decor25D.lire("ullanor")
	assert_false(u.has("erreurs"))
	assert_eq(u.calques.size(), 11, "tous les calques de la DA sont livrés")
	assert_false(Decor25D.lire("ullanor_bivouac").has("erreurs"))
