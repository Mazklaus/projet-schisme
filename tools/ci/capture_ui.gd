extends SceneTree
## Captures de contrôle de l'interface (UI/UX), sur un fond de décor réel :
##   xvfb-run godot --rendering-driver opengl3 -s res://tools/ci/capture_ui.gd -- <dossier>
## Produit menu.png, archives.png, dialogue.png, vox.png, narration.png, choix.png, titre.png,
## archive.png, chapitre.png, fin.png dans <dossier>.

var _dossier := ""
var _etapes: Array = []
var _attente := 0
var _scene: Node


func _initialize() -> void:
	_dossier = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://captures_ui"
	DirAccess.make_dir_recursive_absolute(_dossier)
	_preparer.call_deferred()


func _preparer() -> void:
	var dlg: Dictionary = load("res://src/dialogue/format_dialogue.gd").analyser("""=== a
DREMM (assurance): Vers ses tours et ses conseils. Nous, on part vers tout le reste ! Et toi ?
VASKAR (vox): Vingt-septième, rassemblement au pont d'embarquement.
> La flotte blanche s'arrache à Ullanor.
DREMM: Et quand il n'y aura plus de mondes ?
* « Il nous a menés jusqu'ici. Cela suffit. » -> b
* « Et quand il n'y aura plus de mondes à conquérir ? » -> b
* Ne rien dire. Regarder la flotte. -> b
*! 8 -> b
=== b
A: fin""")
	_etapes = [
		["menu", func(): _changer(load("res://scenes/ui/menu_principal.tscn").instantiate()), 90],
		["archives", func(): _scene._ouvrir_archives(), 20],
		["dialogue", func(): _fond_et_boite(dlg), 120],
		["vox", func(): _boite()._texte.visible_ratio = 1.0; _boite()._suivant(), 30],
		["narration", func(): _boite()._texte.visible_ratio = 1.0; _boite()._suivant(), 30],
		["replique_avant_choix", func(): _boite()._texte.visible_ratio = 1.0; _boite()._suivant(), 30],
		["choix", func():
			_boite()._suivant()
			(_boite()._choix.get_child(1) as Button).grab_focus()
			for i in 20:
				_boite()._process(0.1), 20],
		["titre", func():
			_boite().hide()
			_scene.afficher_carton("Ullanor. 000.M31.", 30.0, false), 60],
		["archive", func(): _scene.afficher_carton("Il disait qu'il l'avait vu, une fois. De près.", 30.0, true), 40],
		["chapitre", func(): _scene.afficher_carton_chapitre(2, "Le Vengeful Spirit", "Épisode 1 · Le Maître de Guerre", 30.0), 50],
		["fin", func():
			for c in _scene.get_children():
				if c is CanvasLayer and c.layer >= 50:
					c.queue_free()
			_jeu().etat.episode = "ep01"
			var e: Control = load("res://src/core/chapitre_jouable.gd").new()._construire_ecran_fin("Le Maître de Guerre", "Il ne m'a rien dit. Je l'ai gardé aussi.")
			var voile := ColorRect.new()
			voile.color = Color(0.043, 0.039, 0.035, 0.9)
			voile.set_anchors_preset(Control.PRESET_FULL_RECT)
			_ui.add_child(voile)
			_ui.add_child(e)
			var ind = load("res://src/ui/indicateur_archivage.gd").new()
			_scene.add_child(ind)
			ind.montrer(), 40],
	]
	_suivante()


func _changer(n: Node) -> void:
	if _scene:
		_scene.queue_free()
	_scene = n
	root.add_child(n)


func _boite() -> Node:
	return _scene.boite


## Scène de chapitre minimale : le Triomphe d'Ullanor (décor réel, passe soleil) et la boîte.
var _ui: CanvasLayer


func _fond_et_boite(dlg: Dictionary) -> void:
	_jeu().changer_de_scene = false
	_jeu().etat.episode = ""
	_jeu().etat.chapitre = ""
	var s = load("res://src/core/chapitre.gd").new()
	var d = load("res://src/decor/decor_25d.gd").new()
	d.id_decor = "ullanor"
	s.add_child(d)
	s.decor = d
	var cam := Camera2D.new()
	cam.position = Vector2(960, 540)
	s.add_child(cam)
	_ui = CanvasLayer.new()
	_ui.layer = 20
	s.add_child(_ui)
	var b = load("res://src/ui/boite_dialogue.gd").new()
	_ui.add_child(b)
	s.boite = b
	_changer(s)
	var soleil = load("res://src/decor/post_soleil.gd").new()
	s.add_child(soleil)
	soleil.suivre(d)
	b.lancer(load("res://src/dialogue/lecteur_dialogue.gd").new(dlg), "a")
	# Hors d'une scène .tscn, la boîte n'a pas de taille : on la cale sur le cadre 1080p.
	b.set_anchors_preset(Control.PRESET_TOP_LEFT)
	b.position = Vector2.ZERO
	b.size = Vector2(1920, 1080)


func _suivante() -> void:
	if _etapes.is_empty():
		quit()
		return
	var e: Array = _etapes[0]
	e[1].call()
	_attente = e[2]


func _process(_d: float) -> bool:
	if _etapes.is_empty():
		return false
	_attente -= 1
	if _attente <= 0:
		var e: Array = _etapes.pop_front()
		var chemin := _dossier.path_join("%s.png" % e[0])
		root.get_texture().get_image().save_png(chemin)
		print("Capture : ", chemin)
		_suivante()
	return false


func _jeu() -> Node:
	return root.get_node("Jeu")
