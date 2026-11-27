extends Control
## Menu principal provisoire : nouvelle partie, continuer, choix d'épisode, quitter.

## Le raccourci de lancement ne sert qu'une fois : un retour au menu affiche le menu.
static var _raccourci_utilise := false


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
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	centre.add_child(vb)
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
