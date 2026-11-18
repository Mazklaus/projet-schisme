class_name CameraCine
extends Camera2D
## Caméra de cinématique : enchaîne des plans (position, zoom, durée, courbe, tremblement).
##
## Un plan est un dictionnaire, écrit à la main ou chargé d'un JSON :
##   {"position": [x, y], "zoom": 1.0, "duree": 2.0, "courbe": "douce", "tremblement": 0.0}
## - durée 0 : coupe franche (la caméra saute au plan) ;
## - courbe : "lineaire", "douce" (entrée et sortie), "entree", "sortie" ;
## - tremblement : amplitude en pixels (explosions, pas des Titans…), décroît sur le plan.
## Le calcul est une fonction pure du temps (echantillonner), ce qui permet de sauter, de
## revenir en arrière et de tester sans attendre.

signal plan_commence(index: int)
signal sequence_terminee

const COURBES := {
	"lineaire": [Tween.TRANS_LINEAR, Tween.EASE_IN_OUT],
	"douce": [Tween.TRANS_SINE, Tween.EASE_IN_OUT],
	"entree": [Tween.TRANS_CUBIC, Tween.EASE_IN],
	"sortie": [Tween.TRANS_CUBIC, Tween.EASE_OUT],
}

var plans: Array = []
var temps := 0.0
var en_cours := false
var _plan_courant := -1
var _bruit := FastNoiseLite.new()


func _init() -> void:
	_bruit.frequency = 2.0
	ignore_rotation = true


func jouer(nouveaux_plans: Array) -> void:
	plans = nouveaux_plans
	temps = 0.0
	_plan_courant = -1
	en_cours = not plans.is_empty()
	enabled = true
	make_current()
	_appliquer()


## Passe directement à la fin de la séquence (touche « passer » du joueur).
func passer() -> void:
	if en_cours:
		temps = duree_totale(plans)
		_appliquer()


func _process(delta: float) -> void:
	if not en_cours:
		return
	temps += delta
	_appliquer()


func _appliquer() -> void:
	var e := echantillonner(plans, temps)
	if e.is_empty():
		return
	position = e.position + _secousse(e.tremblement)
	zoom = Vector2(e.zoom, e.zoom)
	if e.index != _plan_courant:
		_plan_courant = e.index
		plan_commence.emit(e.index)
	if temps >= duree_totale(plans):
		en_cours = false
		sequence_terminee.emit()


func _secousse(amplitude: float) -> Vector2:
	if amplitude <= 0.0:
		return Vector2.ZERO
	return Vector2(_bruit.get_noise_2d(temps * 60.0, 0.0), _bruit.get_noise_2d(0.0, temps * 60.0)) * amplitude


static func duree_totale(p: Array) -> float:
	var t := 0.0
	for plan in p:
		t += float(plan.get("duree", 0.0))
	return t


## État de la caméra au temps t : {"position", "zoom", "tremblement", "index"}.
## Chaque plan part de l'état final du plan précédent (le premier part de lui-même).
static func echantillonner(p: Array, t: float) -> Dictionary:
	if p.is_empty():
		return {}
	var depart := _cible(p[0])
	var debut := 0.0
	for i in p.size():
		var plan: Dictionary = p[i]
		var arrivee := _cible(plan)
		var d := float(plan.get("duree", 0.0))
		var dernier := i == p.size() - 1
		if t < debut + d or dernier:
			var k := 1.0 if d <= 0.0 else clampf((t - debut) / d, 0.0, 1.0)
			var c: Array = COURBES.get(plan.get("courbe", "douce"), COURBES.douce)
			var f := Tween.interpolate_value(0.0, 1.0, k, 1.0, c[0], c[1]) as float
			return {
				"position": depart.position.lerp(arrivee.position, f),
				"zoom": lerpf(depart.zoom, arrivee.zoom, f),
				"tremblement": float(plan.get("tremblement", 0.0)) * (1.0 - k),
				"index": i,
			}
		depart = arrivee
		debut += d
	return {}


static func _cible(plan: Dictionary) -> Dictionary:
	var pos = plan.get("position", [0, 0])
	return {"position": Vector2(pos[0], pos[1]), "zoom": float(plan.get("zoom", 1.0))}
