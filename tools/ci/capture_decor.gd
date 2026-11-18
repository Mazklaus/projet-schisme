extends SceneTree
## Capture d'un décor tel que le moteur le rend, caméra au cadre de référence.
##   xvfb-run godot --rendering-driver opengl3 -s res://tools/ci/capture_decor.gd -- <id_decor> <sortie.png>
## La clé du plan (« cle » du <plan>.json : position_px, couleur) devient une PointLight2D, avec
## une ambiance sombre (CanvasModulate). Sert à comparer avec l'assemblage de la DA.

var _n := 0
var _sortie := ""


func _initialize() -> void:
	# Mise en place à la première image : avant, la fenêtre n'a pas encore sa taille.
	_preparer.call_deferred()


func _preparer() -> void:
	var args := OS.get_cmdline_user_args()
	_sortie = args[1]
	var decor = load("res://src/decor/decor_25d.gd").new()
	decor.id_decor = args[0]
	root.add_child(decor)
	var d: Dictionary = decor.lire(args[0])
	var cam := Camera2D.new()
	cam.position = decor.taille / 2.0
	cam.zoom = Vector2.ONE * (1920.0 / decor.taille.x)
	root.add_child(cam)
	cam.enabled = true
	var amb := CanvasModulate.new()
	amb.color = Color(0.62, 0.58, 0.62)
	root.add_child(amb)
	var cle: Dictionary = d.get("cle", {})
	if cle.has("position_px"):
		var g := Gradient.new()
		g.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1, 0.5)
		t.width = 512
		t.height = 512
		var l := PointLight2D.new()
		l.texture = t
		l.texture_scale = 8.0
		l.position = Vector2(cle.position_px[0], cle.position_px[1])
		l.color = Color(cle.get("couleur", "#ffffff"))
		l.energy = 1.4
		l.height = 60.0
		root.add_child(l)


func _process(_d: float) -> bool:
	_n += 1
	if _n == 10:
		root.get_texture().get_image().save_png(_sortie)
		print("Capture : ", _sortie)
		quit()
	return false
