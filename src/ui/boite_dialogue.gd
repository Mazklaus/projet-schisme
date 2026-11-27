class_name BoiteDialogue
extends Control
## Affiche un LecteurDialogue : nom, réplique en machine à écrire, menu de choix.
##
## La boîte ne sait rien des cinés : chaque commande (@…) est émise par le signal `commande`.
## La scène l'exécute puis appelle reprendre(). Visuel provisoire (placeholder).

signal commande(nom: String, args: Array)
signal fini
## Chaque réplique ou choix affiché (régie des gros plans).
signal evenement(e: Dictionary)
## Choix minuté : émis à l'ouverture (secondes entières restantes) puis à chaque seconde
## écoulée, jusqu'à 1. Sert au son (tic) et à tout effet calé sur la barre de temps.
signal delai_seconde(restant: int)
## Choix minuté : émis quand le temps est écoulé sans réponse (le silence).
signal delai_expire
## Choix minuté : une pulsation du battement sourd (son et trait de temps). Les pulsations
## accélèrent de BATTEMENT_LENT à BATTEMENT_RAPIDE (s) ; intensite va de 0 (début) à 1 (fin).
signal battement(intensite: float)

const BATTEMENT_LENT := 1.0
const BATTEMENT_RAPIDE := 0.35
## Plaque : marges latérales et bas (1080p), hauteur ; le cartouche du nom chevauche le bord haut.
const MARGE_X := 160.0
const MARGE_BAS := 40.0
## Hauteur minimale : deux lignes (aucune réplique de l'ép. 1 ne dépasse 100 caractères, relecture
## Narrative v2) ; la plaque grandit vers le haut au besoin (choix).
const HAUTEUR := 168.0
const CHEVAUCHEMENT := 24.0

@export var caracteres_par_seconde := 45.0

var lecteur: LecteurDialogue
var _nom: Label
var _vox: Label
var _cartouche: PlaqueSchisme
var _texte: RichTextLabel
var _choix: VBoxContainer
var _panneau: PlaqueSchisme
## Voile sombre derrière la boîte (lisibilité sur les fonds clairs, retour DA du 27/11).
var _voile: TextureRect
var _en_attente := false
## Choix minuté : temps restant (s) ; la barre se vide, puis le lecteur expire.
var _delai_restant := 0.0
var _delai_total := 0.0
var _trait: TraitTemps
var _prochain_battement := 0.0
## Indicateur « continuer » (chevron d'or qui descend en boucle) quand la réplique est affichée.
var _suite: Chevron
var _clignote := 0.0
## Type de l'événement précédent : un choix qui suit une réplique la garde au-dessus des options.
var _precedent := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voile = TextureRect.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.04, 0.035, 0.03, 0.62)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 128
	_voile.texture = gt
	_voile.stretch_mode = TextureRect.STRETCH_SCALE
	_voile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voile.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_voile.offset_top = -470
	add_child(_voile)
	_panneau = PlaqueSchisme.new(PlaqueSchisme.Forme.PLAQUE, Vector4(64, 40, 64, 26))
	_panneau.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panneau.offset_top = -(MARGE_BAS + HAUTEUR)
	_panneau.offset_left = MARGE_X
	_panneau.offset_right = -MARGE_X
	_panneau.offset_bottom = -MARGE_BAS
	# Un choix à quatre options (et son fil de temps) dépasse la hauteur : la plaque grandit vers le haut.
	_panneau.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Plaque presque opaque : le décor (silhouettes du premier plan) ne doit pas transparaître.
	_panneau.opacite = 0.94
	add_child(_panneau)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	_panneau.add_child(vb)
	_texte = RichTextLabel.new()
	_texte.fit_content = true
	_texte.bbcode_enabled = true
	_texte.scroll_active = false
	_texte.add_theme_font_override("normal_font", StyleSchisme.texte())
	_texte.add_theme_font_override("italics_font", StyleSchisme.italique())
	_texte.add_theme_font_size_override("normal_font_size", 33)
	_texte.add_theme_font_size_override("italics_font_size", 33)
	_texte.add_theme_font_size_override("bold_font_size", 33)
	_texte.add_theme_font_size_override("bold_italics_font_size", 33)
	_texte.add_theme_color_override("default_color", StyleSchisme.TEXTE)
	_texte.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_texte.add_theme_constant_override("shadow_offset_y", 1)
	_texte.add_theme_constant_override("shadow_offset_x", 0)
	_texte.add_theme_constant_override("line_separation", 4)
	_texte.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_texte)
	_choix = VBoxContainer.new()
	_choix.add_theme_constant_override("separation", 0)
	vb.add_child(_choix)
	_trait = TraitTemps.new()
	_trait.custom_minimum_size.y = 16
	_trait.hide()
	vb.add_child(_trait)
	_suite = Chevron.new()
	# Dans le coin bas droit de la plaque, à l'intérieur du double filet.
	_suite.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_suite.offset_left = -MARGE_X - 80
	_suite.offset_top = -MARGE_BAS - 56
	_suite.offset_right = -MARGE_X - 52
	_suite.offset_bottom = -MARGE_BAS - 30
	_suite.hide()
	add_child(_suite)
	# Cartouche du locuteur, à cheval sur le bord haut de la plaque.
	_cartouche = PlaqueSchisme.new(PlaqueSchisme.Forme.CARTOUCHE, Vector4(26, 4, 30, 4))
	_cartouche.opacite = 1.0
	_cartouche.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_cartouche.offset_left = MARGE_X + 60.0
	_cartouche.offset_bottom = -(MARGE_BAS + HAUTEUR - CHEVAUCHEMENT)
	_cartouche.offset_top = _cartouche.offset_bottom - 46.0
	_cartouche.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_cartouche.custom_minimum_size.y = 46
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	_cartouche.add_child(hb)
	var los := StyleSchisme.Losange.new()
	los.plein = true
	hb.add_child(los)
	_nom = StyleSchisme.label("", StyleSchisme.titre(600), 25, StyleSchisme.OR_CLAIR, 0.14)
	_nom.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(_nom)
	_vox = StyleSchisme.label("VOX", StyleSchisme.titre(500), 17, StyleSchisme.OR_TERNI, 0.2)
	_vox.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_vox.hide()
	hb.add_child(_vox)
	_cartouche.hide()
	add_child(_cartouche)
	hide()


func lancer(l: LecteurDialogue, noeud := "debut") -> void:
	lecteur = l
	show()
	lecteur.demarrer(noeud)
	_suivant()


## La scène a fini d'exécuter la commande : on continue.
func reprendre() -> void:
	if _en_attente:
		_en_attente = false
		_montrer_plaque(true)
		_suivant()


func _process(delta: float) -> void:
	# Le cartouche suit le bord haut de la plaque, qui grandit vers le haut.
	_cartouche.position.y = _panneau.position.y - _cartouche.size.y + CHEVAUCHEMENT
	if _delai_total > 0.0:
		var avant := ceili(_delai_restant)
		_delai_restant -= delta
		var ecoule := 1.0 - maxf(_delai_restant, 0.0) / _delai_total
		_trait.reste = 1.0 - ecoule
		var apres := ceili(_delai_restant)
		if apres < avant and apres >= 1:
			delai_seconde.emit(apres)
		_prochain_battement -= delta
		if _prochain_battement <= 0.0 and _delai_restant > 0.0:
			_prochain_battement = lerpf(BATTEMENT_LENT, BATTEMENT_RAPIDE, ecoule)
			_trait.pulser()
			battement.emit(ecoule)
		if _delai_restant <= 0.0:
			_arreter_delai()
			delai_expire.emit()
			lecteur.expirer()
			_suivant()
			return
	if visible and _texte.visible_ratio < 1.0:
		var n := maxi(_texte.get_total_character_count(), 1)
		_texte.visible_ratio = minf(1.0, _texte.visible_ratio + delta * caracteres_par_seconde / n)
	var attend_suite := visible and not _en_attente and _choix.get_child_count() == 0 \
		and _texte.visible_ratio >= 1.0 and not _texte.text.is_empty()
	_clignote = _clignote + delta if attend_suite else 0.0
	_suite.visible = attend_suite
	_suite.temps = _clignote


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _en_attente:
		return
	if _choix.get_child_count() > 0:
		_selection_initiale(event)
		return
	if event.is_action_pressed("avancer"):
		get_viewport().set_input_as_handled()
		if _texte.visible_ratio < 1.0:
			_texte.visible_ratio = 1.0
		else:
			_suivant()


func _suivant() -> void:
	for b in _choix.get_children():
		b.queue_free()
	var e := lecteur.avancer()
	if e.type == "replique" or e.type == "choix":
		evenement.emit(e)
	var precedent := _precedent
	_precedent = e.type
	match e.type:
		"replique":
			_poser_nom(e)
			_texte.text = BoiteDialogue.texte_affiche(e)
			# Narration (sans locuteur) : italique gris chaud ; répliques et vox : texte clair.
			_texte.add_theme_color_override("default_color",
				StyleSchisme.NARRATION if e.personnage.is_empty() else StyleSchisme.TEXTE)
			_texte.visible_ratio = 0.0
		"choix":
			# La question est la réplique précédente : elle reste au-dessus des options (relecture
			# Narrative v2). Après une commande ou une narration lointaine, le menu s'affiche seul.
			if precedent != "replique":
				_nom.text = ""
				_cartouche.hide()
				_texte.text = ""
			_texte.visible_ratio = 1.0
			for o in e.options:
				var b := OptionChoix.new()
				b.text = BoiteDialogue.typographie(o.texte)
				b.pressed.connect(_choisir.bind(o.index))
				_choix.add_child(b)
			# Aucune option présélectionnée : le silence reste un vrai choix, et un appui
			# réflexe sur Entrée ne choisit rien. La première direction sélectionne.
			get_viewport().gui_release_focus()
			if e.delai > 0.0:
				_delai_total = e.delai
				_delai_restant = e.delai
				_prochain_battement = 0.0
				_trait.reste = 1.0
				_trait.show()
				delai_seconde.emit(ceili(e.delai))
		"commande":
			_en_attente = true
			_montrer_plaque(false)
			commande.emit(e.nom, e.args)
		"fin":
			hide()
			fini.emit()


const SUFFIXE_VOX := ", au vox"


## « FRÈRE 1 » → « Frère » (numéro caché) ; au vox : « Dremm, au vox » (relecture Narrative v2).
static func nom_affiche(e: Dictionary) -> String:
	if e.personnage.is_empty():
		return ""
	var brut := RegEx.create_from_string("\\s+[0-9]+$").sub(String(e.personnage).strip_edges(), "")
	var n: String = brut.substr(0, 1) + brut.substr(1).to_lower()
	return n + SUFFIXE_VOX if e.humeur == "vox" else n


## Typographie française à l'affichage : espace insécable avant ? ! : ; et à l'intérieur des
## guillemets. (Espace insécable normale U+00A0 : Cinzel et EB Garamond n'ont pas la fine U+202F.)
static func typographie(t: String) -> String:
	const ESP := "\u00A0"
	var r := RegEx.create_from_string("([^\\s?!:;\u00A0«])[ \u00A0\u202F]?([?!:;»])")
	t = r.sub(t, "$1" + ESP + "$2", true)
	t = RegEx.create_from_string("«[ \u00A0\u202F]?").sub(t, "«" + ESP, true)
	return t


func _poser_nom(e: Dictionary) -> void:
	var vox: bool = e.humeur == "vox"
	var n := BoiteDialogue.nom_affiche(e)
	_nom.text = n.trim_suffix(SUFFIXE_VOX) if vox else n
	_vox.visible = vox
	_cartouche.visible = not n.is_empty() and _panneau.visible
	# Le cartouche se recale sur la largeur du nom.
	_cartouche.reset_size()


func _montrer_plaque(v: bool) -> void:
	_panneau.visible = v
	_voile.visible = v
	_cartouche.visible = v and not _nom.text.is_empty()


static func texte_affiche(e: Dictionary) -> String:
	var t := typographie(e.texte)
	return "[i]%s[/i]" % t if e.personnage.is_empty() or e.humeur == "vox" else t


func _arreter_delai() -> void:
	_delai_total = 0.0
	_trait.hide()


## Tant qu'aucune option n'a le focus, la première direction (touches ou stick) en
## sélectionne une : la première vers le bas, la dernière vers le haut.
func _selection_initiale(event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() != null:
		return
	var bas := event.is_action_pressed("ui_down") or event.is_action_pressed("bas") \
		or event.is_action_pressed("ui_right") or event.is_action_pressed("droite")
	var haut := event.is_action_pressed("ui_up") or event.is_action_pressed("haut") \
		or event.is_action_pressed("ui_left") or event.is_action_pressed("gauche")
	if not (bas or haut):
		return
	get_viewport().set_input_as_handled()
	var i := 0 if bas else _choix.get_child_count() - 1
	(_choix.get_child(i) as Button).grab_focus()


## Trait fin qui se consume sous les options du choix minuté, des deux bouts vers le centre,
## avec une braise à chaque extrémité qui s'avive à chaque battement.
class TraitTemps extends Control:
	const BRAISE := Color(1.0, 0.62, 0.25)
	const TRAIT := Color("#E6D3A4")
	var reste := 1.0:
		set(v):
			reste = clampf(v, 0.0, 1.0)
			queue_redraw()
	var _pouls := 0.0

	func pulser() -> void:
		_pouls = 1.0

	func _process(delta: float) -> void:
		if _pouls > 0.0:
			_pouls = maxf(0.0, _pouls - delta * 4.0)
			queue_redraw()

	func _draw() -> void:
		var y := size.y / 2.0
		var demi := size.x / 2.0 * reste
		var a := Vector2(size.x / 2.0 - demi, y)
		var b := Vector2(size.x / 2.0 + demi, y)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(StyleSchisme.OR_TERNI, 0.3), 1.0)
		if reste <= 0.0:
			return
		draw_line(a, b, Color(TRAIT, 0.85 + 0.15 * _pouls), 3.0 + 2.0 * _pouls)
		for p in [a, b]:
			draw_circle(p, 9.0 + 6.0 * _pouls, Color(BRAISE, 0.25 + 0.25 * _pouls))
			draw_circle(p, 4.0 + 2.0 * _pouls, BRAISE)


func _choisir(index: int) -> void:
	_arreter_delai()
	lecteur.choisir(index)
	_suivant()


## Option d'un choix : texte en Garamond, losange vide qui s'emplit d'or au focus, filet et
## reflet chaud sous l'option focalisée (maquette v0.1, écran 3).
class OptionChoix extends Button:
	static var _reflet: StyleBoxTexture
	var _vide := StyleBoxEmpty.new()

	func _init() -> void:
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Texte des options aligné sur celui des répliques ; le losange est dans la marge de la plaque.
		_vide.content_margin_left = 0
		_vide.content_margin_right = 18
		_vide.content_margin_top = 9
		_vide.content_margin_bottom = 11
		for etat in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(etat, _vide)
		add_theme_font_override("font", StyleSchisme.texte())
		add_theme_font_size_override("font_size", 31)
		add_theme_color_override("font_color", StyleSchisme.OPTION)
		add_theme_color_override("font_hover_color", StyleSchisme.TEXTE)
		add_theme_color_override("font_focus_color", StyleSchisme.MARBRE)
		add_theme_color_override("font_pressed_color", StyleSchisme.MARBRE)
		add_theme_color_override("font_hover_pressed_color", StyleSchisme.MARBRE)
		focus_entered.connect(_focus.bind(true))
		focus_exited.connect(_focus.bind(false))
		mouse_entered.connect(func(): grab_focus())

	## Reflet chaud sous le texte, qui s'éteint vers la droite : posé en fond (normal, hover).
	static func reflet() -> StyleBoxTexture:
		if _reflet == null:
			var g := Gradient.new()
			g.colors = PackedColorArray([Color(0.227, 0.188, 0.133, 0.55), Color(0.227, 0.188, 0.133, 0.0)])
			g.offsets = PackedFloat32Array([0.0, 0.7])
			var t := GradientTexture2D.new()
			t.gradient = g
			t.width = 256
			t.height = 4
			_reflet = StyleBoxTexture.new()
			_reflet.texture = t
			_reflet.content_margin_left = 0
			_reflet.expand_margin_left = 44
			_reflet.content_margin_right = 18
			_reflet.content_margin_top = 9
			_reflet.content_margin_bottom = 11
		return _reflet

	func _focus(f: bool) -> void:
		for etat in ["normal", "hover", "pressed", "hover_pressed"]:
			add_theme_stylebox_override(etat, reflet() if f else _vide)
		queue_redraw()

	func _draw() -> void:
		var f := has_focus()
		var cy := size.y / 2.0
		if f:
			var largeur := minf(size.x * 0.6, get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 31).x + 20)
			draw_line(Vector2(-36, size.y - 3), Vector2(largeur, size.y - 3), StyleSchisme.OR_TERNI, 1.0)
		var c := Vector2(-26, cy)
		var r := 6.4
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		if f:
			draw_circle(c, r * 1.9, Color(StyleSchisme.OR_CLAIR, 0.18))
			draw_colored_polygon(pts, StyleSchisme.OR_CLAIR)
		else:
			pts.append(pts[0])
			draw_polyline(pts, Color(StyleSchisme.OR_TERNI, 0.75), 1.0, true)


## Indicateur de suite : chevron d'or double qui descend de 4 px et remonte (1,2 s), sans clignoter.
class Chevron extends Control:
	var temps := 0.0:
		set(v):
			temps = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var dy := 4.0 * (0.5 - 0.5 * cos(TAU * temps / 1.2))
		var o := Vector2(0, dy)
		draw_polyline(PackedVector2Array([o + Vector2(3, 4), o + Vector2(14, 15), o + Vector2(25, 4)]), StyleSchisme.OR_CLAIR, 2.4, true)
		draw_polyline(PackedVector2Array([o + Vector2(8, 4), o + Vector2(14, 10), o + Vector2(20, 4)]), StyleSchisme.OR_TERNI, 1.4, true)
