extends Control
## Menu titre (maquette UI v0.1, écran 7, validée par la DA le 27/11) : le Triomphe d'Ullanor
## vivant en fond (calques figés de l'essai 18, sans Vaskar ni Dremm : retour DA), poussée lente
## de la caméra, poussière qui dérive, voile sombre à gauche ; titre « SCHISME » et menu en
## capitales romaines, focus au losange d'or. « Archives » ouvre les emplacements de sauvegarde.

const DECOR_FOND := "ullanor"
## Calques retirés du fond (premiers plans encore en maquette, retour DA).
const CALQUES_EXCLUS := ["vaskar", "dremm", "avant_plan"]
## Poussée de la caméra : zoom 1,00 → 1,04 en 40 s, puis retour (aller-retour sans fin).
const POUSSEE_ZOOM := 1.04
const POUSSEE_S := 40.0

## Le raccourci de lancement ne sert qu'une fois : un retour au menu affiche le menu.
static var _raccourci_utilise := false

var _ui: CanvasLayer
var _menu: VBoxContainer
var _archives: Control
var decor: Decor25D
var camera: Camera2D


func _ready() -> void:
	# Raccourci pour la QA : « -- --nouvelle-partie[=id_episode] » lance directement une partie.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--nouvelle-partie") and not _raccourci_utilise:
			_raccourci_utilise = true
			# « --chapitre=<id> » et « --importer=<emplacement> » : démarrer à un chapitre, avec
			# les drapeaux d'une sauvegarde (la tranche, l'épisode précédent).
			var ep := a.get_slice("=", 1) if a.contains("=") else ""
			var chap := ""
			var import_de := -1
			for b in OS.get_cmdline_user_args():
				if b.begins_with("--chapitre="):
					chap = b.get_slice("=", 1)
				elif b.begins_with("--importer="):
					import_de = int(b.get_slice("=", 1))
			if import_de >= 0:
				Jeu.importer(import_de, ep if not ep.is_empty() else Catalogue.ordre[0], chap)
			elif not chap.is_empty():
				Jeu.nouvelle_partie(ep)
				Jeu.aller_au_chapitre(Jeu.etat.episode, chap)
			else:
				Jeu.nouvelle_partie(ep)
			return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_construire_fond()
	_ui = CanvasLayer.new()
	_ui.name = "UI"
	_ui.layer = 10
	add_child(_ui)
	_construire_voiles()
	_construire_titre()
	_construire_menu()
	_construire_pied()
	_archives = _construire_archives()
	_archives.hide()
	_ui.add_child(_archives)
	_premier_bouton(_menu).grab_focus.call_deferred()


# --------------------------------------------------------------------------- fond vivant

func _construire_fond() -> void:
	var monde := Node2D.new()
	monde.name = "Fond"
	add_child(monde)
	decor = Decor25D.new()
	decor.name = "Ullanor"
	decor.id_decor = DECOR_FOND
	monde.add_child(decor)
	for c in decor.calques:
		var n := String(c.name).to_lower()
		for x in CALQUES_EXCLUS:
			if n.contains(x):
				c.visible = false
	var centre := decor.taille / 2.0 if decor.taille != Vector2.ZERO else Vector2(960, 540)
	camera = Camera2D.new()
	camera.position = centre
	monde.add_child(camera)
	camera.enabled = true
	camera.make_current()
	# Poussée lente vers le dais, un peu à droite du centre (le titre occupe la gauche).
	var t := create_tween().set_loops()
	t.tween_property(camera, "zoom", Vector2.ONE * POUSSEE_ZOOM, POUSSEE_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(camera, "position", centre + Vector2(40, -6), POUSSEE_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(camera, "zoom", Vector2.ONE, POUSSEE_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(camera, "position", centre, POUSSEE_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var soleil := PostSoleil.new()
	add_child(soleil)
	soleil.suivre(decor)
	# Poussière dorée qui dérive vers la gauche, en contre-jour.
	var p := CPUParticles2D.new()
	p.name = "Poussiere"
	p.amount = 90
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1100, 560)
	p.position = centre
	p.direction = Vector2(-1, -0.15)
	p.spread = 25.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 18.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.6
	p.color = Color("#FFE8B0")
	var rampe := Gradient.new()
	rampe.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	rampe.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	p.color_ramp = rampe
	p.z_index = 100
	monde.add_child(p)


func _construire_voiles() -> void:
	for d in [[Vector2(0, 0), Vector2(1, 0), [0.94, 0.75, 0.0], [0.0, 0.26, 0.52]],
			[Vector2(0, 1), Vector2(0, 0), [0.8, 0.0], [0.0, 0.22]]]:
		var g := Gradient.new()
		var cols := PackedColorArray()
		for a in d[2]:
			cols.append(Color(StyleSchisme.NOIR, a))
		g.colors = cols
		g.offsets = PackedFloat32Array(d[3])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = d[0]
		gt.fill_to = d[1]
		gt.width = 256
		gt.height = 256
		var r := TextureRect.new()
		r.texture = gt
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.add_child(r)


func _construire_titre() -> void:
	var vb := VBoxContainer.new()
	vb.name = "Titre"
	vb.position = Vector2(150, 230)
	vb.add_theme_constant_override("separation", 8)
	var t := StyleSchisme.label("SCHISME", StyleSchisme.titre(700), 132, StyleSchisme.OR_CLAIR, 0.12)
	# Gravure : lumière dessus, ombre portée profonde.
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	t.add_theme_constant_override("shadow_offset_y", 6)
	t.add_theme_constant_override("shadow_outline_size", 18)
	t.add_theme_color_override("font_outline_color", Color("#3B2E14"))
	t.add_theme_constant_override("outline_size", 2)
	vb.add_child(t)
	var st := StyleSchisme.label("L'HÉRÉSIE D'HORUS", StyleSchisme.titre(500), 26, StyleSchisme.MARBRE, 0.52)
	vb.add_child(st)
	var regle := HBoxContainer.new()
	regle.add_theme_constant_override("separation", 16)
	regle.add_child(StyleSchisme.Filet.new(180.0))
	var los := StyleSchisme.Losange.new()
	los.plein = true
	regle.add_child(los)
	regle.add_child(StyleSchisme.Filet.new(60.0))
	var marge := Control.new()
	marge.custom_minimum_size.y = 14
	vb.add_child(marge)
	vb.add_child(regle)
	_ui.add_child(vb)


func _construire_menu() -> void:
	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.position = Vector2(150, 560)
	_menu.add_theme_constant_override("separation", 6)
	_ui.add_child(_menu)
	if Sauvegarde.existe(0):
		var d := Sauvegarde.lire(0)
		var c := Catalogue.chapitre(d.get("episode", ""), d.get("chapitre", ""))
		var precision := ""
		if not c.is_empty():
			precision = "Ch. %s · %s" % [StyleSchisme.romain(_numero_chapitre(d.episode, d.chapitre)), c.get("titre", "")]
		_entree(_menu, "Continuer", func(): Jeu.charger(0), precision)
	_entree(_menu, "Nouvelle partie", func(): Jeu.nouvelle_partie())
	# Plusieurs épisodes : chacun peut se lancer depuis le menu (QA, épisodes suivants).
	if Catalogue.ordre.size() > 1:
		for id in Catalogue.ordre:
			var ep := Catalogue.episode(id)
			_entree(_menu, "Épisode %d" % ep.numero, func(): Jeu.nouvelle_partie(id), ep.titre)
	_entree(_menu, "Archives", _ouvrir_archives)
	_entree(_menu, "Quitter", func(): get_tree().quit())


func _construire_pied() -> void:
	var pied := HBoxContainer.new()
	pied.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pied.offset_left = 150
	pied.offset_right = -150
	pied.offset_top = -80
	pied.offset_bottom = -46
	var ep := Catalogue.episode(Catalogue.ordre[0]) if not Catalogue.ordre.is_empty() else {}
	var g := StyleSchisme.label(("ÉPISODE %d · %s" % [ep.get("numero", 1), String(ep.get("titre", "")).to_upper()]) if not ep.is_empty() else "",
		StyleSchisme.titre(500), 16, Color("#8C877A"), 0.24)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pied.add_child(g)
	pied.add_child(StyleSchisme.label("VERSION DE TRAVAIL", StyleSchisme.titre(500), 16, Color("#8C877A"), 0.24))
	_ui.add_child(pied)


static func _numero_chapitre(id_episode: String, id_chapitre: String) -> int:
	var chapitres: Array = Catalogue.episode(id_episode).get("chapitres", [])
	for i in chapitres.size():
		if chapitres[i].get("id", "") == id_chapitre:
			return i + 1
	return 1


func _premier_bouton(parent: Node) -> Button:
	for n in parent.find_children("*", "Button", true, false):
		if not (n as Button).disabled:
			return n
	return null


## Entrée du menu : capitales romaines espacées, losange vide → plein et filet au focus,
## précision en italique à droite (chapitre de la sauvegarde, titre d'épisode).
func _entree(parent: Node, texte: String, action: Callable, precision := "") -> Button:
	var b := EntreeMenu.new()
	b.name = texte.replace(" ", "")
	b.text = texte
	b.precision = precision
	b.pressed.connect(action)
	parent.add_child(b)
	return b


class EntreeMenu extends Button:
	var precision := ""

	func _init() -> void:
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		var vide := StyleBoxEmpty.new()
		vide.content_margin_left = 34
		vide.content_margin_top = 8
		vide.content_margin_bottom = 12
		vide.content_margin_right = 12
		for etat in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(etat, vide)
		StyleSchisme.habiller(self, StyleSchisme.titre(500), 30, Color("#C9C0AC"), 0.16)
		for c in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			add_theme_color_override(c, StyleSchisme.MARBRE)
		add_theme_color_override("font_disabled_color", Color("#6B665C"))
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		mouse_entered.connect(func(): if not disabled: grab_focus())

	func _ready() -> void:
		if not precision.is_empty():
			var l := StyleSchisme.label(precision, StyleSchisme.italique(), 22, StyleSchisme.GRIS)
			var f := get_theme_font("font")
			l.position = Vector2(34 + f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 26, 14)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(l)

	func _draw() -> void:
		var f := has_focus()
		var c := Vector2(8, size.y / 2.0 - 2)
		var r := 6.4
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		if f:
			draw_circle(c, r * 1.9, Color(StyleSchisme.OR_CLAIR, 0.2))
			draw_colored_polygon(pts, StyleSchisme.OR_CLAIR)
			var w := get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			draw_line(Vector2(34, size.y - 4), Vector2(34 + w, size.y - 4), StyleSchisme.OR_TERNI, 1.0)
		else:
			pts.append(pts[0])
			draw_polyline(pts, Color(StyleSchisme.OR_TERNI, 0.9), 1.0, true)


# --------------------------------------------------------------------------- archives

## Emplacements de sauvegarde (maquette, écran 9) : six plaques, numéro romain, chapitre, date.
## Un emplacement vide est grisé ; un emplacement plein se charge.
func _construire_archives() -> Control:
	var racine := Control.new()
	racine.name = "Archives"
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	var fond := ColorRect.new()
	fond.color = Color(StyleSchisme.NOIR, 0.82)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.add_child(fond)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_top = 92
	vb.add_theme_constant_override("separation", 14)
	racine.add_child(vb)
	var t := StyleSchisme.label("ARCHIVES", StyleSchisme.titre(600), 52, StyleSchisme.MARBRE, 0.2)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	vb.add_child(StyleSchisme.regle_fleur())
	var marge := Control.new()
	marge.custom_minimum_size.y = 50
	vb.add_child(marge)
	var centre := CenterContainer.new()
	vb.add_child(centre)
	var grille := GridContainer.new()
	grille.name = "Grille"
	grille.columns = 3
	grille.add_theme_constant_override("h_separation", 30)
	grille.add_theme_constant_override("v_separation", 30)
	centre.add_child(grille)
	return racine


func _ouvrir_archives() -> void:
	var grille := _archives.find_child("Grille", true, false) as GridContainer
	for n in grille.get_children():
		n.queue_free()
	for i in Sauvegarde.NB_EMPLACEMENTS:
		grille.add_child(_emplacement(i))
	_menu.hide()
	_ui.get_node("Titre").hide()
	_archives.show()
	var premier := _premier_bouton(grille)
	if premier:
		premier.grab_focus.call_deferred()


func _fermer_archives() -> void:
	_archives.hide()
	_menu.show()
	_ui.get_node("Titre").show()
	(_menu.find_child("Archives", true, false) as Button).grab_focus()


func _unhandled_input(e: InputEvent) -> void:
	if _archives and _archives.visible and e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_fermer_archives()


func _emplacement(i: int) -> Button:
	var b := Button.new()
	b.name = "Emplacement%d" % i
	b.custom_minimum_size = Vector2(500, 150)
	b.focus_mode = Control.FOCUS_ALL
	var n := StyleBoxPlaque.new()
	var f := StyleBoxPlaque.new()
	f.focus = true
	for etat in ["normal", "disabled"]:
		b.add_theme_stylebox_override(etat, n)
	for etat in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(etat, f)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_entered.connect(func(): b.add_theme_stylebox_override("normal", f))
	b.focus_exited.connect(func(): b.add_theme_stylebox_override("normal", n))
	var d := Sauvegarde.lire(i) if Sauvegarde.existe(i) else {}
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 30
	hb.offset_right = -24
	hb.add_theme_constant_override("separation", 26)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	var num := StyleSchisme.label(StyleSchisme.romain(i + 1), StyleSchisme.titre(600), 34, StyleSchisme.OR)
	num.custom_minimum_size.x = 56
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(num)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(col)
	if d.is_empty():
		b.disabled = true
		b.modulate.a = 0.55
		col.add_child(StyleSchisme.label("Emplacement libre", StyleSchisme.titre(600), 21, Color("#8C877A"), 0.08))
	else:
		var c := Catalogue.chapitre(d.get("episode", ""), d.get("chapitre", ""))
		var ep := Catalogue.episode(d.get("episode", ""))
		col.add_child(StyleSchisme.label(c.get("titre", d.get("chapitre", "")), StyleSchisme.titre(600), 21, StyleSchisme.MARBRE, 0.08))
		col.add_child(StyleSchisme.label("Épisode %d · chapitre %s" % [ep.get("numero", 1), StyleSchisme.romain(_numero_chapitre(d.episode, d.chapitre))],
			StyleSchisme.italique(), 22, Color("#BDB4A0")))
		var h := int(d.get("horodatage", 0))
		if h > 0:
			var dt := Time.get_datetime_dict_from_unix_time(h + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
			var mois := ["JANV.", "FÉVR.", "MARS", "AVR.", "MAI", "JUIN", "JUIL.", "AOÛT", "SEPT.", "OCT.", "NOV.", "DÉC."]
			col.add_child(StyleSchisme.label("%d %s · %02d:%02d" % [dt.day, mois[dt.month - 1], dt.hour, dt.minute],
				StyleSchisme.titre(500), 15, StyleSchisme.OR_TERNI, 0.2))
		b.pressed.connect(func(): Jeu.charger(i))
	return b


## Plaque en StyleBox (fond de bouton dessiné sous le contenu).
class StyleBoxPlaque extends StyleBox:
	var focus := false

	func _draw(ci: RID, rect: Rect2) -> void:
		var pts := PlaqueSchisme.contour(rect, PlaqueSchisme.Forme.PLAQUE)
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		for p in pts:
			uvs.append(p / 256.0)
			cols.append(Color(1, 1, 1, 0.96))
		RenderingServer.canvas_item_add_polygon(ci, pts, cols, uvs, StyleSchisme.texture_plaque().get_rid())
		var ferme := pts.duplicate()
		ferme.append(pts[0])
		RenderingServer.canvas_item_add_polyline(ci, ferme, PackedColorArray([StyleSchisme.OR_CLAIR if focus else StyleSchisme.OR_TERNI]), 1.4 if focus else 1.0, true)
		var interieur := PlaqueSchisme.contour(rect.grow(-PlaqueSchisme.RETRAIT), PlaqueSchisme.Forme.PLAQUE, PlaqueSchisme.COIN_INTERIEUR)
		interieur.append(interieur[0])
		RenderingServer.canvas_item_add_polyline(ci, interieur, PackedColorArray([Color(StyleSchisme.OR_TERNI, 0.6)]), 1.0, true)
