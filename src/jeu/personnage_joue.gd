class_name PersonnageJoue
extends Node2D
## Personnage joué dans les phases d'exploration : déplacement sur le plan du sol (2.5D).
## Touches : ZQSD / WASD (position physique, valable en AZERTY comme en QWERTY) ou flèches.
## Plus haut sur l'écran = plus loin : le personnage rapetisse un peu (profondeur).

@export var vitesse := 300.0
var actif := false
## Zone de marche, en pixels du décor (x, y du sol).
var limites := Rect2(100, 800, 3640, 200)
var sprite: Sprite2D
## Vrai pendant une image où le joueur a bougé (invite de déplacement, inactivité).
var en_mouvement := false
var _temps := 0.0


func _process(delta: float) -> void:
	var v := Input.get_vector("gauche", "droite", "haut", "bas") if actif else Vector2.ZERO
	en_mouvement = v != Vector2.ZERO
	if en_mouvement:
		position += Vector2(v.x, v.y * 0.6) * vitesse * delta
		position = position.clamp(limites.position, limites.end)
		if v.x != 0.0 and sprite:
			sprite.flip_h = v.x < 0.0
		_temps += delta
	elif sprite:
		_temps = 0.0
	if sprite:
		sprite.position.y = -absf(sin(_temps * 9.0)) * 5.0
	var k := inverse_lerp(limites.position.y, limites.end.y, position.y)
	scale = Vector2.ONE * lerpf(0.9, 1.05, clampf(k, 0.0, 1.0))


## Distance « au sol » : l'écart vertical compte moins (plan du sol vu de biais).
func distance_sol(p: Vector2) -> float:
	var d := p - position
	return Vector2(d.x, d.y * 1.6).length()
