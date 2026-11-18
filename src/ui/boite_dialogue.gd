class_name BoiteDialogue
extends Control
## Affiche un LecteurDialogue : nom, réplique en machine à écrire, menu de choix.
##
## La boîte ne sait rien des cinés : chaque commande (@…) est émise par le signal `commande`.
## La scène l'exécute puis appelle reprendre(). Visuel provisoire (placeholder).

signal commande(nom: String, args: Array)
signal fini

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
var _barre: ProgressBar


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panneau = PanelContainer.new()
	_panneau.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panneau.offset_top = -260
	_panneau.offset_left = 160
	_panneau.offset_right = -160
	_panneau.offset_bottom = -40
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
	_barre = ProgressBar.new()
	_barre.show_percentage = false
	_barre.custom_minimum_size.y = 6
	_barre.hide()
	vb.add_child(_barre)
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
		_delai_restant -= delta
		_barre.value = 100.0 * maxf(_delai_restant, 0.0) / _delai_total
		if _delai_restant <= 0.0:
			_arreter_delai()
			lecteur.expirer()
			_suivant()
			return
	if visible and _texte.visible_ratio < 1.0:
		var n := maxi(_texte.get_total_character_count(), 1)
		_texte.visible_ratio = minf(1.0, _texte.visible_ratio + delta * caracteres_par_seconde / n)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _en_attente or _choix.get_child_count() > 0:
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
			_nom.text = e.personnage.capitalize() if not e.personnage.is_empty() else ""
			_texte.text = e.texte if not e.personnage.is_empty() else "[i]%s[/i]" % e.texte
			_texte.visible_ratio = 0.0
		"choix":
			_texte.visible_ratio = 1.0
			for o in e.options:
				var b := Button.new()
				b.text = o.texte
				b.pressed.connect(_choisir.bind(o.index))
				_choix.add_child(b)
			(_choix.get_child(0) as Button).grab_focus.call_deferred()
			if e.delai > 0.0:
				_delai_total = e.delai
				_delai_restant = e.delai
				_barre.value = 100.0
				_barre.show()
		"commande":
			_en_attente = true
			_panneau.hide()
			commande.emit(e.nom, e.args)
		"fin":
			hide()
			fini.emit()


func _arreter_delai() -> void:
	_delai_total = 0.0
	_barre.hide()


func _choisir(index: int) -> void:
	_arreter_delai()
	lecteur.choisir(index)
	_suivant()
