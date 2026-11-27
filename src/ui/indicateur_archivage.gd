class_name IndicateurArchivage
extends CanvasLayer
## « ARCHIVAGE… » en bas à droite à chaque sauvegarde (signal Sauvegarde.sauvegardee) : le sceau
## (seule touche de rouge de l'interface, DA) tourne 1,5 s puis s'efface.

const DUREE := 1.5

var _boite: HBoxContainer
var _sceau: Sceau
var _tween: Tween


func _ready() -> void:
	layer = 60
	_boite = HBoxContainer.new()
	_boite.name = "Archivage"
	_boite.add_theme_constant_override("separation", 14)
	_boite.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_boite.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_boite.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_boite.offset_right = -56
	_boite.offset_bottom = -52
	_boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sceau = Sceau.new()
	_boite.add_child(_sceau)
	var l := StyleSchisme.label("ARCHIVAGE…", StyleSchisme.titre(500), 18, StyleSchisme.OR_CLAIR, 0.28)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_outline_size", 6)
	_boite.add_child(l)
	_boite.modulate.a = 0.0
	add_child(_boite)
	if not Sauvegarde.sauvegardee.is_connected(montrer):
		Sauvegarde.sauvegardee.connect(montrer)


func montrer(_emplacement := 0) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_boite, "modulate:a", 1.0, 0.2)
	_tween.parallel().tween_property(_sceau, "angle", _sceau.angle + TAU * 0.75, DUREE)
	_tween.tween_property(_boite, "modulate:a", 0.0, 0.4)


class Sceau extends Control:
	var angle := 0.0:
		set(v):
			angle = v
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(40, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		# Anneau en tirets qui tourne, disque de cire, croix d'or.
		for i in 14:
			var a0 := angle + TAU * i / 14.0
			draw_arc(c, 16.0, a0, a0 + TAU / 14.0 * 0.55, 4, StyleSchisme.OR, 1.5, true)
		draw_circle(c, 10.0, StyleSchisme.SCEAU)
		draw_line(c + Vector2(-7, 0), c + Vector2(7, 0), StyleSchisme.OR_CLAIR, 1.5, true)
		draw_line(c + Vector2(0, -7), c + Vector2(0, 7), StyleSchisme.OR_CLAIR, 1.5, true)
