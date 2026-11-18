extends Control
## Menu principal provisoire : nouvelle partie, continuer, choix d'épisode, quitter.

func _ready() -> void:
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.add_theme_constant_override("separation", 12)
	add_child(vb)
	var titre := Label.new()
	titre.text = ProjectSettings.get_setting("application/config/name")
	titre.add_theme_font_size_override("font_size", 64)
	vb.add_child(titre)
	_bouton(vb, "Nouvelle partie", func(): Jeu.nouvelle_partie())
	if Sauvegarde.existe(0):
		_bouton(vb, "Continuer", func(): Jeu.charger(0))
	for id in Catalogue.ordre:
		var ep := Catalogue.episode(id)
		_bouton(vb, "Épisode %d : %s" % [ep.numero, ep.titre], func(): Jeu.nouvelle_partie(id))
	_bouton(vb, "Quitter", func(): get_tree().quit())
	(vb.get_child(1) as Button).grab_focus.call_deferred()


func _bouton(parent: Node, texte: String, action: Callable) -> void:
	var b := Button.new()
	b.text = texte
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(action)
	parent.add_child(b)
