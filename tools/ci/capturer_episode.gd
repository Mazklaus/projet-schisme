extends SceneTree
## Banc de captures d'un épisode : une image par travail, rendue par le moteur du jeu (décor 2.5D,
## états, lumières, ambiance du chapitre, caméra des plans, fonds et bustes des gros plans).
## Lancé par tools/capturer_episode.py, qui écrit la liste des travaux :
##   xvfb-run -a godot --rendering-driver opengl3 -s res://tools/ci/capturer_episode.gd -- <travaux.json>
## travaux.json : {"sortie": "/chemin/absolu", "travaux": [
##   {"id": "...", "type": "decor", "decor": "orvane_rues", "etat": "nuit",
##    "camera": {"position": [x, y], "zoom": z} | null, "textures": {"Calque_x": "calques/y.png"}},
##   {"id": "...", "type": "gros_plan", "fond": "<id fond>", "scene": {...}, "perso": "VASKAR", "cote": "droite"}]}
## Chaque image : <sortie>/<id>.png. Une ligne « CAPTURE <id> » ou « ECHEC <id> : raison » par travail.

## Ambiance de la scène des chapitres jouables (scenes/chapitres/chapitre_jouable.tscn).
const AMBIANCE_CHAPITRE := Color(0.8, 0.76, 0.74, 1)
## Images d'attente avant la capture : textures chargées, tweens d'état et lumières posés.
const IMAGES_ATTENTE := 12

var _travaux: Array = []
var _sortie := ""
var _i := -1
var _attente := 0
var _scene: Node = null
var _echecs := 0
## ChapitreJouable chargé à l'exécution : il cite l'autoload Jeu, inconnu à la compilation d'un -s.
var _cj: GDScript


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or not FileAccess.file_exists(args[0]):
		printerr("ECHEC : liste de travaux introuvable (%s)" % [args])
		quit(2)
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	_cj = load("res://src/core/chapitre_jouable.gd")
	_travaux = d.get("travaux", [])
	_sortie = String(d.get("sortie", "user://captures"))
	DirAccess.make_dir_recursive_absolute(_sortie)
	_suivant.call_deferred()


func _suivant() -> void:
	if _scene:
		_scene.queue_free()
		_scene = null
	_i += 1
	if _i >= _travaux.size():
		print("Captures : %d travaux, %d échecs" % [_travaux.size(), _echecs])
		quit(1 if _echecs > 0 else 0)
		return
	var t: Dictionary = _travaux[_i]
	_scene = Node2D.new()
	_scene.name = "Banc_%d" % _i
	root.add_child(_scene)
	var raison := ""
	match String(t.get("type", "")):
		"decor":
			raison = _poser_decor(t)
		"gros_plan":
			raison = _poser_gros_plan(t)
		_:
			raison = "type inconnu « %s »" % t.get("type", "")
	if not raison.is_empty():
		_echecs += 1
		printerr("ECHEC %s : %s" % [t.get("id", "?"), raison])
		_suivant.call_deferred()
		return
	_attente = IMAGES_ATTENTE


func _process(_d: float) -> bool:
	if _attente <= 0 or _scene == null:
		return false
	_attente -= 1
	if _attente == 0:
		var t: Dictionary = _travaux[_i]
		var chemin := _sortie.path_join(String(t.id) + ".png")
		var img := root.get_texture().get_image()
		if img.get_width() != 1920:
			img.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
		img.save_png(chemin)
		print("CAPTURE %s" % t.id)
		_suivant.call_deferred()
	return false


## Décor d'une scène ou d'un plan : comme ChapitreJouable (ambiance, rebond, état, caméra).
func _poser_decor(t: Dictionary) -> String:
	var id := String(t.get("decor", ""))
	var lu := Decor25D.lire(id)
	if lu.has("erreurs"):
		return "décor %s : %s" % [id, ", ".join(PackedStringArray(lu.erreurs))]
	var decor := Decor25D.new()
	decor.name = id
	decor.id_decor = id
	_scene.add_child(decor)
	var etat := String(t.get("etat", ""))
	if not etat.is_empty():
		if not decor.etats.is_empty() and not decor.etats.has(etat):
			return "état « %s » inconnu de %s" % [etat, id]
		decor.appliquer_etat(etat, 0.0)
	for nom in t.get("textures", {}):
		var chemin := "%s/%s/%s" % [Decor25D.DOSSIER, id, t.textures[nom]]
		var trouve := false
		for c in decor.calques:
			var image := c.get_node_or_null(^"Image") as Sprite2D
			if String(c.name) == String(nom) and image and image.texture is CanvasTexture and ResourceLoader.exists(chemin):
				(image.texture as CanvasTexture).diffuse_texture = load(chemin)
				trouve = true
		if not trouve:
			push_warning("Plan : texture %s introuvable pour %s" % [chemin, nom])
	var amb := CanvasModulate.new()
	amb.color = _cj.ambiance_du_decor(decor, AMBIANCE_CHAPITRE)
	_scene.add_child(amb)
	decor.appliquer_rebond(amb.color)
	var soleil := PostSoleil.new()
	_scene.add_child(soleil)
	soleil.suivre(decor)
	var cam := Camera2D.new()
	var c = t.get("camera")
	if typeof(c) == TYPE_DICTIONARY:
		cam.position = Vector2(c.position[0], c.position[1])
		cam.zoom = Vector2.ONE * float(c.get("zoom", 1.0))
	else:
		cam.position = decor.taille / 2.0
		cam.zoom = Vector2.ONE * (Decor25D.taille_ecran().x / maxf(decor.taille.x, 1.0))
	_scene.add_child(cam)
	cam.make_current()
	return ""


## Gros plan de dialogue : fond de CA2 (couche 3) et buste de CA1 éclairé dans un SubViewport
## transparent (couche 4), comme ChapitreJouable._afficher_gros_plan.
func _poser_gros_plan(t: Dictionary) -> String:
	var id_fond := String(t.get("fond", ""))
	var scene_gp: Dictionary = t.get("scene", {})
	var perso := String(t.get("perso", ""))
	var cote := String(t.get("cote", "gauche"))
	var couche_fond := CanvasLayer.new()
	couche_fond.layer = 3
	_scene.add_child(couche_fond)
	var fond: Node2D = _cj.construire_fond_gros_plan(id_fond, scene_gp)
	if fond.get_child_count() == 0:
		return "fond de gros plan %s vide ou introuvable" % id_fond
	couche_fond.add_child(fond)
	if perso.is_empty():
		return ""
	var chemin := RegieGrosPlans.chemin_buste(perso, cote, String(t.get("expression", RegieGrosPlans.EXPRESSION_DEFAUT)))
	if not ResourceLoader.exists(chemin):
		return "buste absent pour %s (%s)" % [perso, chemin]
	var couche_buste := CanvasLayer.new()
	couche_buste.layer = 4
	_scene.add_child(couche_buste)
	var vue := SubViewport.new()
	vue.size = Vector2i(Decor25D.taille_ecran())
	vue.transparent_bg = true
	vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	couche_buste.add_child(vue)
	var ecran := Sprite2D.new()
	ecran.centered = false
	ecran.texture = vue.get_texture()
	ecran.material = _cj.materiau_premultiplie()
	couche_buste.add_child(ecran)
	var zones: Dictionary = fond.get_meta("zones", {})
	var tete: Dictionary = _cj.tete_du_fond(id_fond, cote, zones)
	var etat := String(scene_gp.get("etat", ""))
	for n in _cj.construire_eclairage_buste(RegieGrosPlans.eclairage_buste(perso, cote), id_fond, cote, etat, float(tete.x)):
		vue.add_child(n)
	var sp: Sprite2D = _cj.construire_sprite_buste(chemin, tete, cote, perso)
	sp.position.x += float(scene_gp.get("decalage_x", {}).get(perso.to_upper(), 0.0))
	vue.add_child(sp)
	return ""
