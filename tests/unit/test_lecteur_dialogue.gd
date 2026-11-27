extends GutTest


func _lecteur(texte: String, drapeaux := {}) -> LecteurDialogue:
	var d := FormatDialogue.analyser(texte)
	assert_eq(d.erreurs, [] as Array[String])
	var l := LecteurDialogue.new(d, drapeaux)
	l.demarrer(d.ordre[0])
	return l


func test_repliques_puis_fin() -> void:
	var l := _lecteur("=== a\nA: un\n> deux\n-> FIN")
	assert_eq(l.avancer().texte, "un")
	assert_eq(l.avancer().texte, "deux")
	assert_eq(l.avancer().type, "fin")
	assert_true(l.termine())


func test_choix_et_drapeaux() -> void:
	var dr := {}
	var l := _lecteur("=== a\n* x -> b\n* y -> c [si cle]\n=== b\n~ vu = true\n~ n += 1\n~ n += 1\nA: b\n=== c\nA: c", dr)
	var e := l.avancer()
	assert_eq(e.type, "choix")
	assert_eq(e.options.size(), 1, "l'option conditionnelle est masquée")
	l.choisir(0)
	assert_eq(l.avancer().texte, "b")
	assert_eq(dr, {"vu": true, "n": 2})


func test_comparaison_et_negation() -> void:
	var l := _lecteur("=== a\n-> b [si n >= 2]\n-> c [si non n]\nA: rien\n=== b\nA: b\n=== c\nA: c", {"n": 3})
	assert_eq(l.avancer().texte, "b")
	l = _lecteur("=== a\n-> b [si n >= 2]\n-> c [si non n]\nA: rien\n=== b\nA: b\n=== c\nA: c", {})
	assert_eq(l.avancer().texte, "c")


func test_choix_minute_expire() -> void:
	var l := _lecteur("=== a\n* aider -> b\n* obeir -> c\n*! 8 -> c\n=== b\nA: b\n=== c\nA: c")
	var e := l.avancer()
	assert_eq(e.delai, 8.0)
	l.expirer()
	assert_eq(l.avancer().texte, "c")


func test_menu_sans_option_visible_suit_le_delai() -> void:
	var l := _lecteur("=== a\n* x -> b [si cle]\n*! 8 -> b\n=== b\nA: b")
	assert_eq(l.avancer().texte, "b")


func test_commande_puis_reprise() -> void:
	var l := _lecteur("=== a\n@plan ouverture\nA: apres")
	var e := l.avancer()
	assert_eq([e.type, e.nom, e.args], ["commande", "plan", ["ouverture"]])
	assert_eq(l.avancer().texte, "apres")


func test_boucle_de_sauts_interrompue() -> void:
	var l := _lecteur("=== a\n-> b\n=== b\n-> a")
	assert_eq(l.avancer().type, "fin")
	assert_push_error("Boucle de sauts")


func test_noeud_entre_est_signale() -> void:
	var l := _lecteur("=== a\n-> b\n=== b\nA: b")
	watch_signals(l)
	l.avancer()
	assert_signal_emitted_with_parameters(l, "noeud_entre", ["b"])


func test_boite_compte_les_secondes_du_choix_minute() -> void:
	var d := FormatDialogue.analyser("=== a\n* x -> b\n*! 3 -> b\n=== b\nA: b")
	var boite := BoiteDialogue.new()
	add_child_autofree(boite)
	watch_signals(boite)
	boite.lancer(LecteurDialogue.new(d), "a")
	for i in 40:
		boite._process(0.1)
	assert_signal_emit_count(boite, "delai_seconde", 3, "3, 2, 1")
	assert_signal_emitted(boite, "delai_expire")


func test_choix_sans_preselection_et_battement_qui_accelere() -> void:
	var d := FormatDialogue.analyser("=== a\n* x -> b\n* y -> b\n*! 8 -> b\n=== b\nA: b")
	var boite := BoiteDialogue.new()
	add_child_autofree(boite)
	var instants: Array[float] = []
	var t := [0.0]
	boite.battement.connect(func(_i: float): instants.append(t[0]))
	boite.lancer(LecteurDialogue.new(d), "a")
	await get_tree().process_frame
	assert_null(get_viewport().gui_get_focus_owner(), "aucune option présélectionnée : le silence reste un choix")
	for i in 79:
		t[0] += 0.1
		boite._process(0.1)
	assert_gt(instants.size(), 8, "battements pendant 8 s")
	var debut := instants[1] - instants[0]
	var fin := instants[-1] - instants[-2]
	assert_lt(fin, debut * 0.6, "le battement accélère (%.2f s → %.2f s)" % [debut, fin])
	# Première direction : la première option prend le focus.
	var e := InputEventAction.new()
	e.action = "bas"
	e.pressed = true
	boite._unhandled_input(e)
	assert_eq(get_viewport().gui_get_focus_owner(), boite._choix.get_child(0))
