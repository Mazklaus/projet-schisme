class_name VieFigure
extends Node
## Vie d'une figure immobile : respiration (étirement vertical depuis les pieds) et léger
## balancement (cisaillement horizontal, pieds fixes). S'ajoute en enfant d'un Sprite2D dont
## l'origine est aux pieds (voir ChapitreJouable._sprite) et anime son parent.
## Chaque figure a sa propre phase et sa propre période, tirées de son nom : une foule de
## figurants ne respire jamais à l'unisson, et la même figure bouge pareil d'une partie à l'autre.

## Étirement vertical maximal à l'inspiration (0.012 = 1,2 % : ~3 px sur un Astartes).
@export var respiration := 0.012
## Cisaillement maximal (tan de l'angle) : ~2 px au sommet d'une figure de 230 px.
@export var balancement := 0.008
## 0 : figée, 1 : pleine vie. Le joueur la baisse quand il marche (le pas prend le relais).
var intensite := 1.0
## Échelle de repos du parent, relevée à la première image (voir reprendre()).
var echelle_base := Vector2.ZERO

var _phase := 0.0
var _periode_souffle := 4.2
var _periode_balancement := 6.0
var _temps := 0.0


## Ajoute la vie à une figure (ou renvoie celle qu'elle a déjà).
static func animer(figure: Node2D, graine := "") -> VieFigure:
	var v := de(figure)
	if v:
		return v
	v = VieFigure.new()
	v.name = "Vie"
	v.regler_graine(graine if not graine.is_empty() else String(figure.name))
	figure.add_child(v)
	return v


static func de(figure: Node) -> VieFigure:
	return figure.get_node_or_null(^"Vie") as VieFigure if figure else null


## Phase et périodes propres à une graine (le nom du figurant).
func regler_graine(graine: String) -> void:
	var h := absi(hash(graine))
	_phase = float(h % 1000) / 1000.0 * TAU
	_periode_souffle = 3.6 + float((h / 1000) % 100) / 100.0 * 1.4
	_periode_balancement = 5.0 + float((h / 100000) % 100) / 100.0 * 2.5
	_temps = 0.0


## L'échelle du parent a changé de l'extérieur (échelle du joueur selon le chapitre).
## À appeler juste après avoir posé la nouvelle échelle : elle devient l'échelle de repos.
func reprendre() -> void:
	echelle_base = Vector2.ZERO


func _process(delta: float) -> void:
	_temps += delta
	appliquer(_temps)


## Pose la figure à l'instant t (secondes) : appelée chaque image, et par les tests.
func appliquer(t: float) -> void:
	var p := get_parent() as Node2D
	if p == null:
		return
	if echelle_base == Vector2.ZERO:
		echelle_base = p.scale
	# Inspiration un peu plus courte que l'expiration : sinus déformé, entre 0 et 1.
	var s := 0.5 + 0.5 * sin(TAU * t / _periode_souffle + _phase)
	s = s * s * (3.0 - 2.0 * s)
	p.scale = Vector2(echelle_base.x, echelle_base.y * (1.0 + respiration * intensite * s))
	p.skew = balancement * intensite * sin(TAU * t / _periode_balancement + _phase * 1.3)
