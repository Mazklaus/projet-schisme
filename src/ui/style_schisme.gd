class_name StyleSchisme
extends RefCounted
## Identité de l'interface (UI/UX, maquette v0.1 validée par la DA le 27/11) :
## plaques de métal sombre, double filet d'or terni, coins coupés, losange d'or comme seul
## ornement. Polices SIL OFL : Cinzel (capitales romaines) et EB Garamond (texte).
## Maquette et notes : /mnt/project-files/projet-schisme/ui/maquette-v0.1/.

const NOIR := Color("#0B0A09")
const OMBRE := Color("#1A1612")
const PLAQUE := Color("#14110E")
const OR_TERNI := Color("#8C7A4A")
const OR := Color("#B8963E")
const OR_CLAIR := Color("#D9B25A")
const MARBRE := Color("#EDE6D6")
const TEXTE := Color("#E6DECB")
const NARRATION := Color("#CFC6B2")
const OPTION := Color("#B5AC98")
const GRIS := Color("#9C9A92")
const GRIS_INACTIF := Color("#5E594F")
## Seule touche de rouge de l'interface (DA) : le sceau d'archivage.
const SCEAU := Color("#7A1E1A")

const POLICE_TITRE := "res://assets/ui/polices/Cinzel-Variable.ttf"
const POLICE_TEXTE := "res://assets/ui/polices/EBGaramond-Variable.ttf"
const POLICE_ITALIQUE := "res://assets/ui/polices/EBGaramond-Italic-Variable.ttf"
const TEXTURE_PLAQUE := "res://assets/ui/ui_plaque_metal.png"

static var _cache := {}


## Police à graisse variable (« wght »), mise en cache.
static func police(chemin: String, graisse := 400) -> Font:
	var cle := "%s:%d" % [chemin, graisse]
	if _cache.has(cle):
		return _cache[cle]
	var base: FontFile = load(chemin)
	var f := FontVariation.new()
	f.base_font = base
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): graisse}
	_cache[cle] = f
	return f


static func titre(graisse := 500) -> Font:
	return police(POLICE_TITRE, graisse)


static func texte(graisse := 400) -> Font:
	return police(POLICE_TEXTE, graisse)


static func italique(graisse := 400) -> Font:
	return police(POLICE_ITALIQUE, graisse)


## Chargée une fois, hors de tout _draw() : une texture chargée pendant le dessin sort blanche
## (Godot 4.7, Compatibility).
static var _plaque: Texture2D = preload("res://assets/ui/ui_plaque_metal.png")


static func texture_plaque() -> Texture2D:
	return _plaque


## Applique police, taille, couleur (et espacement des lettres pour Cinzel) à un Label.
static func habiller(l: Control, f: Font, taille: int, couleur: Color, espacement := 0.0) -> void:
	var fv := f
	if espacement != 0.0 and f is FontVariation:
		fv = (f as FontVariation).duplicate()
		(fv as FontVariation).spacing_glyph = int(round(taille * espacement))
	l.add_theme_font_override("font", fv)
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)


static func label(t: String, f: Font, taille: int, couleur: Color, espacement := 0.0) -> Label:
	var l := Label.new()
	l.text = t
	habiller(l, f, taille, couleur, espacement)
	return l


## Surtitre en capitales espacées entre deux filets d'or terni (« ARCHIVE », « CHAPITRE II »).
static func surtitre(t: String, taille := 20, largeur_filet := 90.0) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 22)
	hb.add_child(Filet.new(largeur_filet))
	var l := label(t, titre(600), taille, OR, 0.42)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(l)
	hb.add_child(Filet.new(largeur_filet))
	return hb


## Filet — losange — filet.
static func regle_fleur(largeur := 180.0) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	hb.add_child(Filet.new(largeur))
	var los := Losange.new()
	los.plein = true
	hb.add_child(los)
	hb.add_child(Filet.new(largeur))
	return hb


## Chiffres romains (chapitres, emplacements).
static func romain(n: int) -> String:
	var valeurs := [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"],
		[50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]
	var s := ""
	for v in valeurs:
		while n >= v[0]:
			s += v[1]
			n -= v[0]
	return s


## Filet horizontal fin, centré verticalement.
class Filet extends Control:
	var couleur := StyleSchisme.OR_TERNI

	func _init(largeur := 90.0) -> void:
		custom_minimum_size = Vector2(largeur, 12)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_line(Vector2(0, size.y / 2.0), Vector2(size.x, size.y / 2.0), couleur, 1.0)


## Le losange d'or : plein (focus, ornement) ou vide (filet seul).
class Losange extends Control:
	var plein := false:
		set(v):
			plein = v
			queue_redraw()
	var cote := 9.0
	var lueur := false:
		set(v):
			lueur = v
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(16, 16)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var r := cote * 0.71
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		if lueur:
			draw_circle(c, r * 1.9, Color(StyleSchisme.OR_CLAIR, 0.18))
		if plein:
			draw_colored_polygon(pts, StyleSchisme.OR_CLAIR if lueur else StyleSchisme.OR)
		else:
			pts.append(pts[0])
			draw_polyline(pts, Color(StyleSchisme.OR_TERNI, 0.8), 1.0, true)
