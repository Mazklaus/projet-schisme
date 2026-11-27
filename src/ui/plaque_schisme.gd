class_name PlaqueSchisme
extends PanelContainer
## Plaque de métal sombre de l'interface : texture brossée, filet d'or terni, coins coupés.
##   PLAQUE    : double filet (intérieur à 7 px), coins coupés à 16 px, losange et trait d'or
##               dans chaque coin (boîte de dialogue, choix, emplacements de sauvegarde).
##   CARTOUCHE : bouts en pointe (nom du locuteur, boutons de l'écran de fin).
## Le contenu se place comme dans un PanelContainer (marges : « marges »).

enum Forme { PLAQUE, CARTOUCHE }

const COIN := 16.0
const RETRAIT := 7.0
const COIN_INTERIEUR := 10.0
const POINTE := 12.0

@export var forme := Forme.PLAQUE:
	set(v):
		forme = v
		queue_redraw()
## Filet en or clair (focus) ou éteint (option grisée).
var focus := false:
	set(v):
		focus = v
		queue_redraw()
var inactif := false:
	set(v):
		inactif = v
		queue_redraw()
var opacite := 0.94:
	set(v):
		opacite = v
		queue_redraw()
var ornements := true


func _init(f := Forme.PLAQUE, marges := Vector4(64, 36, 64, 30)) -> void:
	forme = f
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var vide := StyleBoxEmpty.new()
	vide.content_margin_left = marges.x
	vide.content_margin_top = marges.y
	vide.content_margin_right = marges.z
	vide.content_margin_bottom = marges.w
	add_theme_stylebox_override("panel", vide)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


static func contour(r: Rect2, forme_: int, coin := COIN) -> PackedVector2Array:
	var a := r.position
	var b := r.end
	if forme_ == Forme.CARTOUCHE:
		var m := (a.y + b.y) / 2.0
		var p := minf(POINTE, r.size.y / 2.0)
		return PackedVector2Array([Vector2(a.x + p, a.y), Vector2(b.x - p, a.y), Vector2(b.x, m),
			Vector2(b.x - p, b.y), Vector2(a.x + p, b.y), Vector2(a.x, m)])
	return PackedVector2Array([Vector2(a.x + coin, a.y), Vector2(b.x - coin, a.y), Vector2(b.x, a.y + coin),
		Vector2(b.x, b.y - coin), Vector2(b.x - coin, b.y), Vector2(a.x + coin, b.y),
		Vector2(a.x, b.y - coin), Vector2(a.x, a.y + coin)])


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var pts := contour(r, forme)
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append(p / 256.0)
	var teinte := Color(1, 1, 1, opacite)
	draw_colored_polygon(pts, teinte, uvs, StyleSchisme.texture_plaque())
	var filet := StyleSchisme.OR_CLAIR if focus else StyleSchisme.OR_TERNI
	if inactif:
		filet = Color("#4A4335")
	var ferme := pts.duplicate()
	ferme.append(pts[0])
	draw_polyline(ferme, Color(filet, 0.95), 1.4 if focus else 1.0, true)
	if focus and forme == Forme.CARTOUCHE:
		var interieur := contour(r.grow(-4.0), forme)
		interieur.append(interieur[0])
		draw_polyline(interieur, Color(StyleSchisme.OR_CLAIR, 0.16), 3.0, true)
	if forme != Forme.PLAQUE:
		return
	var interieur := contour(r.grow(-RETRAIT), forme, COIN_INTERIEUR)
	interieur.append(interieur[0])
	draw_polyline(interieur, Color(StyleSchisme.OR_TERNI, 0.6), 1.0, true)
	if not ornements:
		return
	# Coins : trait diagonal et losange d'or (maquette : symbole « coin »).
	for c in [[Vector2(0, 0), Vector2(1, 1)], [Vector2(size.x, 0), Vector2(-1, 1)],
			[Vector2(0, size.y), Vector2(1, -1)], [Vector2(size.x, size.y), Vector2(-1, -1)]]:
		var o: Vector2 = c[0]
		var s: Vector2 = c[1]
		draw_line(o + Vector2(2, 16) * s, o + Vector2(16, 2) * s, StyleSchisme.OR, 1.5, true)
		var m := o + Vector2(11, 11) * s
		draw_colored_polygon(PackedVector2Array([m + Vector2(0, -2.8), m + Vector2(2.8, 0),
			m + Vector2(0, 2.8), m + Vector2(-2.8, 0)]), StyleSchisme.OR)
