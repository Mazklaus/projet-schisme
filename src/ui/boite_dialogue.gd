class_name BoiteDialogue
extends Control
## Affiche un LecteurDialogue : nom, réplique en machine à écrire, menu de choix.
##
## La boîte ne sait rien des cinés : chaque commande (@…) est émise par le signal `commande`.
## La scène l'exécute puis appelle reprendre(). Visuel provisoire (placeholder).

signal commande(nom: String, args: Array)
signal fini
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
const COULEUR_PANNEAU := Color(0.05, 0.045, 0.04, 0.92)
const COULEUR_BORD := Color(0.62, 0.5, 0.3, 0.6)

@export var caracteres_par_seconde := 45.0

var lecteur: LecteurDialogue
var _nom: Label
var _texte: RichTextLabel
var _choix: VBoxContainer
var _panneau: PanelContainer
var _en_attente := false
## Choix minuté : temps restant (s) ; la barre se vide, puis le lecteur expire.
var _delai_restant := 0.0
var _delai_total := 0.0
var _trait: TraitTemps
var _prochain_battement := 0.0
## Indicateur « continuer » (▼ clignotant) quand la réplique est entièrement affichée.
var _suite: Label
var _clignote := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panneau = PanelContainer.new()
	_panneau.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panneau.offset_top = -260
	_panneau.offset_left = 160
	_panneau.offset_right = -160
	_panneau.offset_bottom = -40
	# Panneau presque opaque : le décor (silhouettes du premier plan) ne doit pas transparaître.
	var style := StyleBoxFlat.new()
	style.bg_color = COULEUR_PANNEAU
	style.border_color = COULEUR_BORD
	style.border_width_top = 2
	style.set_content_margin_all(22)
	style.content_margin_left = 36
	style.content_margin_right = 36
	_panneau.add_theme_stylebox_override("panel", style)
	add_child(_panneau)
	var vb := VBoxContainer.new()
	_panneau.add_child(vb)
	_nom = Label.new()
	_nom.add_theme_font_size_override("font_size", 30)
	vb.add_child(_nom)
	_texte = RichTextLabel.new()
	_texte.fit_content = true
	_texte.bbcode_enabled = true
	_texte.add_theme_font_size_override("normal_font_size", 28)
	_texte.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_texte)
	_choix = VBoxContainer.new()
	vb.add_child(_choix)
	_trait = TraitTemps.new()
	_trait.custom_minimum_size.y = 14
	_trait.hide()
	vb.add_child(_trait)
	_suite = Label.new()
	_suite.text = "▼"
	_suite.add_theme_font_size_override("font_size", 22)
	_suite.add_theme_color_override("font_color", COULEUR_BORD.lightened(0.4))
	_suite.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_suite.offset_left = -40
	_suite.offset_top = -40
	_suite.offset_right = -14
	_suite.offset_bottom = -10
	_suite.hide()
	_panneau.add_child(_suite)
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
		_panneau.show()
		_suivant()


func _process(delta: float) -> void:
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
	_suite.visible = attend_suite and fmod(_clignote, 1.0) < 0.65


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
	match e.type:
		"replique":
			_nom.text = BoiteDialogue.nom_affiche(e)
			_texte.text = BoiteDialogue.texte_affiche(e)
			_texte.visible_ratio = 0.0
		"choix":
			# La question est la réplique précédente ou la situation : le menu s'affiche seul.
			_nom.text = ""
			_texte.text = ""
			_texte.visible_ratio = 1.0
			for o in e.options:
				var b := Button.new()
				b.text = o.texte
				b.add_theme_font_size_override("font_size", 30)
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
			_panneau.hide()
			commande.emit(e.nom, e.args)
		"fin":
			hide()
			fini.emit()


## « FRÈRE 1 » → « Frère 1 » ; une réplique au vox est signalée et en italique.
static func nom_affiche(e: Dictionary) -> String:
	if e.personnage.is_empty():
		return ""
	var n: String = e.personnage.substr(0, 1) + e.personnage.substr(1).to_lower()
	return n + " (vox)" if e.humeur == "vox" else n


static func texte_affiche(e: Dictionary) -> String:
	return "[i]%s[/i]" % e.texte if e.personnage.is_empty() or e.humeur == "vox" else e.texte


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
	const TRAIT := Color(0.95, 0.88, 0.72)
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
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(TRAIT, 0.12), 2.0)
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
