class_name StyleBoxCartouche
extends StyleBox
## Fond de bouton de l'interface : cartouche de métal sombre à bouts en pointe, filet d'or terni
## (or clair au focus, éteint si inactif). Dessiné sous le texte du bouton (StyleBox).

enum Etat { NORMAL, FOCUS, INACTIF }

var etat := Etat.NORMAL


static func creer(e: int, marge_x := 34.0, marge_y := 12.0) -> StyleBoxCartouche:
	var s := StyleBoxCartouche.new()
	s.etat = e
	s.content_margin_left = marge_x
	s.content_margin_right = marge_x
	s.content_margin_top = marge_y
	s.content_margin_bottom = marge_y
	return s


func _draw(ci: RID, rect: Rect2) -> void:
	var pts := PlaqueSchisme.contour(rect, PlaqueSchisme.Forme.CARTOUCHE)
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append(p / 256.0)
	var tex := StyleSchisme.texture_plaque()
	var cols := PackedColorArray()
	for p in pts:
		cols.append(Color(1, 1, 1, 0.96))
	RenderingServer.canvas_item_add_polygon(ci, pts, cols, uvs, tex.get_rid())
	var filet := StyleSchisme.OR_TERNI
	var ep := 1.0
	match etat:
		Etat.FOCUS:
			filet = StyleSchisme.OR_CLAIR
			ep = 1.4
		Etat.INACTIF:
			filet = Color("#4A4335")
	var ferme := pts.duplicate()
	ferme.append(pts[0])
	RenderingServer.canvas_item_add_polyline(ci, ferme, PackedColorArray([filet]), ep, true)
	if etat == Etat.FOCUS:
		var interieur := PlaqueSchisme.contour(rect.grow(-4.0), PlaqueSchisme.Forme.CARTOUCHE)
		interieur.append(interieur[0])
		RenderingServer.canvas_item_add_polyline(ci, interieur, PackedColorArray([Color(StyleSchisme.OR_CLAIR, 0.18)]), 3.0, true)


## Habille un bouton en cartouche : Cinzel 22 espacé, états normal / focus / inactif.
static func habiller(b: Button, taille := 22) -> void:
	var n := creer(Etat.NORMAL)
	var f := creer(Etat.FOCUS)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", f)
	b.add_theme_stylebox_override("pressed", f)
	b.add_theme_stylebox_override("hover_pressed", f)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", creer(Etat.INACTIF))
	StyleSchisme.habiller(b, StyleSchisme.titre(500), taille, Color("#C9C0AC"), 0.2)
	b.add_theme_color_override("font_hover_color", StyleSchisme.MARBRE)
	b.add_theme_color_override("font_focus_color", StyleSchisme.MARBRE)
	b.add_theme_color_override("font_pressed_color", StyleSchisme.MARBRE)
	b.add_theme_color_override("font_disabled_color", StyleSchisme.GRIS_INACTIF)
	# Le focus clavier prend le style « focus » du cartouche (le style focus de Godot se
	# dessine par-dessus le texte : on échange plutôt le fond).
	b.focus_entered.connect(func(): b.add_theme_stylebox_override("normal", f))
	b.focus_exited.connect(func(): b.add_theme_stylebox_override("normal", n))
