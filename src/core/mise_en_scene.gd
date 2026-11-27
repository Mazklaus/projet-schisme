class_name MiseEnScene
extends Node
## Effets de mise en scène lus dans « mises_en_scene.<nœud> » des fichiers jeu (Level Designer,
## fiches etude-heresie/episode-01/mise-en-scene/00-conventions.md). Branché par ChapitreJouable :
## jouer() à l'entrée d'un nœud, ligne() à chaque réplique affichée, nettoyer() au changement de
## décor.
##
## Clés gérées : particules, eclairs, tirs, obus, grenades, tremblement, calques, arret_tirs,
## reprise_tirs, tirs_cadence, plein_ecran (plan peint plein cadre : l'œil de Vaskar). Chaque élément peut porter :
##   "si": "choix_ep01_orvane == 1"   (conditions du .dlg, « and » pour en enchaîner plusieurs)
##   "apres_ligne": N                 (à la N-ième réplique du nœud au lieu de debut_s)
##   "debut_s": t, "duree": d         (sans durée : jusqu'au changement de décor)
##   "son": "id"                      (Son.bruitage au déclenchement)
## Une coordonnée peut être un intervalle [min, max] : tirée au hasard à chaque usage.
## Chaque effet est un nœud enfant du parent fourni (le Monde du décor), retiré par nettoyer().
## Aucune allocation par frame : les tirs sont tirés d'une réserve de Line2D, tout est animé
## par Tween ou Timer.

const LASER := Color("#FF7A3A")
const BOLT := Color("#FFE6B0")
const COEUR := Color(1.0, 0.97, 0.9)
const POINTS_TRAIT := 12
const Z_EFFETS := 80
const RESERVE_TIRS := 10
const VITESSE_TIR_PX_S := 4200.0

## Préréglages des particules (CPUParticles2D), d'après la poussière de la tranche.
const PARTICULES := {
	"poussiere": {"fondu": true, "couleur": Color(0.62, 0.55, 0.46, 0.45), "vie": 4.0, "vitesse": [8.0, 30.0], "gravite": [0, 6], "taille": [4.0, 14.0], "direction": [0, -1], "dispersion": 180.0, "quantite": 60},
	"gravats": {"couleur": Color(0.35, 0.3, 0.26, 0.9), "vie": 1.4, "vitesse": [20.0, 80.0], "gravite": [0, 600], "taille": [3.0, 9.0], "direction": [0, 1], "dispersion": 25.0, "quantite": 50},
	"fumee": {"fondu": true, "grossit": true, "couleur": Color(0.4, 0.38, 0.36, 0.42), "vie": 7.0, "vitesse": [10.0, 30.0], "gravite": [16, -14], "taille": [30.0, 70.0], "direction": [0, -1], "dispersion": 30.0, "quantite": 24},
	"braises": {"couleur": Color(1.0, 0.62, 0.25, 0.9), "vie": 2.5, "vitesse": [30.0, 90.0], "gravite": [8, -40], "taille": [1.5, 3.5], "direction": [0, -1], "dispersion": 35.0, "quantite": 30, "addition": true},
	"cendres": {"fondu": true, "couleur": Color(0.85, 0.82, 0.76, 0.6), "vie": 6.0, "vitesse": [10.0, 40.0], "gravite": [10, 8], "taille": [1.5, 4.0], "direction": [1, 0], "dispersion": 180.0, "quantite": 80},
	"etincelles": {"couleur": Color(1.0, 0.85, 0.55, 1.0), "vie": 0.5, "vitesse": [120.0, 320.0], "gravite": [0, 500], "taille": [1.5, 3.0], "direction": [0, -1], "dispersion": 70.0, "quantite": 24, "addition": true},
	"flash": {"fondu": true, "couleur": Color(1.0, 0.48, 0.23, 0.9), "vie": 0.14, "vitesse": [0.0, 4.0], "gravite": [0, 0], "taille": [26.0, 44.0], "direction": [0, -1], "dispersion": 180.0, "quantite": 4, "addition": true},
	"vitres": {"couleur": Color(0.8, 0.9, 1.0, 0.85), "vie": 1.2, "vitesse": [40.0, 160.0], "gravite": [0, 700], "taille": [2.0, 5.0], "direction": [0, 1], "dispersion": 50.0, "quantite": 90, "addition": true},
}

var decor: Node2D
var parent: Node2D
var camera: Camera2D
var drapeaux: Dictionary = {}
## Position du joueur (cible « joueur » des tirs) ; Callable qui rend un Vector2.
var position_joueur := Callable()
## Figurant posé par le chapitre, par son nom (clé « masquer ») ; Callable qui rend un Node ou null.
var figurant := Callable()

var lignes := 0
var _en_attente: Array = []  # [N, Callable] : déclenchés à la N-ième réplique du nœud
var _effets: Array[Node] = []
var _tirs: Array[Node2D] = []
var _tweens_calques: Array[Tween] = []
var _images_animees: Array[Node2D] = []
var _masques: Array[CanvasItem] = []
var _bruit := FastNoiseLite.new()
var _texture_lumiere: Texture2D
## Particules : un disque doux partagé (jamais de carrés), taille de référence 32 px.
const TAILLE_GOUTTE := 32.0
static var _goutte: Texture2D
## Traînée des tirs : transparente à la queue, pleine à la tête (teintée par self_modulate).
static var _degrade_trainee: Gradient
## Fumée qui grossit en montant ; tête de tir effilée.
static var _courbe_grossit: Curve
static var _courbe_trait: Curve


func _init() -> void:
	name = "MiseEnScene"


## Le chapitre est détruit : libérer tout de suite (pas d'attente de fin de frame à la sortie).
func _exit_tree() -> void:
	for t in _tweens_calques:
		if t.is_valid():
			t.kill()
	for n in _effets:
		if is_instance_valid(n) and not n.is_inside_tree():
			n.free()
	_effets.clear()
	_tirs.clear()


# ------------------------------------------------------------------------------------ entrée

## Entrée dans un nœud : remet le compteur de répliques à zéro et programme ses éléments.
func jouer(m: Dictionary, decor_courant: Node2D, parent_effets: Node2D = null) -> void:
	decor = decor_courant
	parent = parent_effets if parent_effets else decor_courant
	lignes = 0
	_en_attente.clear()
	if decor == null:
		return
	# « masquer » : figurants de l'exploration retirés du plan (Sefa seule), rendus à nettoyer().
	for nom in _liste(m.get("masquer")):
		var f = figurant.call(String(nom)) if figurant.is_valid() else null
		if f is CanvasItem and is_instance_valid(f) and f.visible:
			f.visible = false
			_masques.append(f)
	for e in _liste(m.get("particules")):
		_programmer(e, _particules.bind(e))
	for e in _liste(m.get("eclairs")):
		_programmer(e, _eclair.bind(e))
	for e in _liste(m.get("tirs")) + _liste(m.get("tirs_allies")):
		_programmer(e, _emetteur_tirs.bind(e))
	for e in _liste(m.get("obus")) + _liste(m.get("grenades")):
		_programmer(e, _explosions.bind(e))
	for e in _liste(m.get("tremblement")):
		_programmer(e, _trembler.bind(e))
	for e in _liste(m.get("calques")):
		_programmer(e, _animer_calque.bind(e))
	if m.has("arret_tirs"):
		_programmer(m.arret_tirs, _arreter_tirs.bind(m.arret_tirs))
	if m.has("reprise_tirs"):
		_programmer(m.reprise_tirs, _reprendre_tirs)
	if m.has("tirs_cadence"):
		_regler_cadence(float(m.tirs_cadence))
	if m.has("plein_ecran"):
		_programmer(m.plein_ecran, _plein_ecran.bind(m.plein_ecran))


## Une réplique de plus dans le nœud : lance ce qui attendait cette ligne.
func ligne() -> void:
	lignes += 1
	var restants: Array = []
	for a in _en_attente:
		if lignes >= int(a[0]):
			a[1].call()
		else:
			restants.append(a)
	_en_attente = restants


## Retire tout ce que la mise en scène a posé (changement de décor).
func nettoyer() -> void:
	for t in _tweens_calques:
		if t.is_valid():
			t.kill()
	_tweens_calques.clear()
	# Les décors sont gardés d'une scène à l'autre : on rend aux calques leur place.
	for img in _images_animees:
		if is_instance_valid(img):
			img.position = img.get_meta("position_mes")
			img.modulate.a = img.get_meta("alpha_mes", 1.0)
			img.remove_meta("position_mes")
			img.remove_meta("alpha_mes")
	_images_animees.clear()
	for f in _masques:
		if is_instance_valid(f):
			f.visible = true
	_masques.clear()
	for n in _effets:
		if is_instance_valid(n):
			n.queue_free()
	_effets.clear()
	_tirs.clear()
	_en_attente.clear()
	if camera:
		camera.offset = Vector2.ZERO


## Effets vivants (tests, moniteur).
func effets() -> Array[Node]:
	var r: Array[Node] = []
	for n in _effets:
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			r.append(n)
	return r


# ------------------------------------------------------------------------------- conditions

## « a == 1 and b » : conditions du .dlg, évaluées sur les drapeaux de la partie.
static func condition_vraie(texte: String, drapeaux_partie: Dictionary) -> bool:
	if texte.strip_edges().is_empty():
		return true
	for morceau in texte.split(" and ", false):
		var instr := FormatDialogue._avec_condition({}, morceau)
		if instr.has("erreur"):
			push_warning("Mise en scène : %s" % instr.erreur)
			return false
		if not FormatDialogue.evaluer(instr, drapeaux_partie):
			return false
	return true


## Coordonnée : un nombre, ou un intervalle [min, max] tiré au hasard.
static func valeur(v) -> float:
	if typeof(v) == TYPE_ARRAY:
		return randf_range(float(v[0]), float(v[1]))
	return float(v)


static func point(p) -> Vector2:
	return Vector2(valeur(p[0]), valeur(p[1]))


func _programmer(e: Dictionary, action: Callable) -> void:
	if typeof(e) != TYPE_DICTIONARY or not condition_vraie(String(e.get("si", "")), drapeaux):
		return
	var lancer := func():
		if e.has("son"):
			Son.bruitage(String(e.son))
		action.call()
	if e.has("apres_ligne"):
		_en_attente.append([int(e.apres_ligne), lancer])
	elif float(e.get("debut_s", 0.0)) > 0.0:
		_minuterie(float(e.debut_s), lancer)
	else:
		lancer.call()


func _minuterie(s: float, action: Callable) -> void:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = maxf(s, 0.001)
	t.timeout.connect(func():
		action.call()
		t.queue_free())
	_ajouter(t)
	t.start()


func _ajouter(n: Node) -> void:
	_effets.append(n)
	(parent if is_instance_valid(parent) else self).add_child(n)


static func _liste(v) -> Array:
	if typeof(v) == TYPE_ARRAY:
		return v
	if typeof(v) == TYPE_DICTIONARY:
		return [v]
	return []


# -------------------------------------------------------------------------------- particules

func _particules(e: Dictionary) -> void:
	if not e.has("zone_px"):
		return  # zones relatives (au joueur, à la lumière) : pas encore gérées
	var pre: Dictionary = PARTICULES.get(String(e.get("type", "poussiere")), PARTICULES.poussiere)
	var z: Array = e.zone_px
	var p := CPUParticles2D.new()
	p.name = "Particules_%s" % e.get("type", "poussiere")
	p.position = Vector2(float(z[0]) + float(z[2]) / 2.0, float(z[1]) + float(z[3]) / 2.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(float(z[2]), float(z[3])) / 2.0
	var densite := float(e.get("densite", 0.5))
	p.amount = maxi(4, int(pre.quantite * clampf(densite, 0.05, 2.0)))
	p.lifetime = pre.vie
	var d: Array = pre.direction
	if e.get("direction") == "haut":
		d = [0, -1]
	elif e.get("direction") == "droite":
		d = [1, 0]
	p.direction = Vector2(d[0], d[1])
	p.spread = pre.dispersion
	p.initial_velocity_min = pre.vitesse[0]
	p.initial_velocity_max = pre.vitesse[1]
	p.gravity = Vector2(pre.gravite[0], pre.gravite[1])
	p.texture = _texture_goutte()
	p.scale_amount_min = pre.taille[0] / TAILLE_GOUTTE * 2.0
	p.scale_amount_max = pre.taille[1] / TAILLE_GOUTTE * 2.0
	if pre.has("grossit"):
		if _courbe_grossit == null:
			_courbe_grossit = Curve.new()
			_courbe_grossit.max_value = 2.0
			_courbe_grossit.add_point(Vector2(0, 0.6))
			_courbe_grossit.add_point(Vector2(1, 1.8))
		p.scale_amount_curve = _courbe_grossit
	if pre.has("fondu"):
		# La particule s'éteint en fin de vie au lieu de disparaître d'un coup.
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color(1, 1, 1, 0)])
		g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
		p.color_ramp = g
	p.color = Color(String(e.couleur)) if e.has("couleur") else pre.couleur
	p.z_index = Z_EFFETS
	if pre.get("addition", false):
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = m
	var duree := float(e.get("duree", 0.0))
	if duree > 0.0 and duree < 1.0:
		p.one_shot = true
		p.explosiveness = 0.85
	_ajouter(p)
	p.emitting = true
	if duree > 0.0 and not e.get("persiste", false):
		_minuterie(duree, func():
			if is_instance_valid(p):
				p.emitting = false
				get_tree().create_timer(p.lifetime).timeout.connect(p.queue_free))


static func _texture_goutte() -> Texture2D:
	if _goutte == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1, 0.5)
		t.width = int(TAILLE_GOUTTE)
		t.height = int(TAILLE_GOUTTE)
		_goutte = t
	return _goutte


# ---------------------------------------------------------------------------------- lumières

func _lumiere(pos: Vector2, couleur: Color, rayon_px: float) -> PointLight2D:
	if _texture_lumiere == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1, 0.5)
		t.width = 256
		t.height = 256
		_texture_lumiere = t
	var l := PointLight2D.new()
	l.texture = _texture_lumiere
	l.texture_scale = rayon_px / 128.0
	l.position = pos
	l.color = couleur
	l.energy = 0.0
	l.height = 80.0
	l.range_item_cull_mask = Decor25D.MASQUE_LUMIERE | Decor25D.MASQUE_HALO
	return l


## Éclair (bouche, explosion, impact) : monte vite, retombe ; répété si demandé. Une entrée
## avec « jusqu_a_ligne » ou sans durée reste allumée (lumière d'ambiance de la scène).
func _eclair(e: Dictionary) -> void:
	if not e.has("position_px"):
		return  # éclairs nommés (lumières du décor) : pas encore gérés
	var l := _lumiere(point(e.position_px), Color(String(e.get("couleur", "#FFE6B0"))),
		float(e.get("rayon_px", 500)))
	l.name = "Eclair"
	_ajouter(l)
	var energie := float(valeur(e.get("energie", 1.5)))
	var n := int(e.get("repetitions", 1))
	var intervalle := float(e.get("intervalle_s", 0.3))
	if e.has("jusqu_a_ligne"):
		l.create_tween().tween_property(l, "energy", energie, 0.6)
		_en_attente.append([int(e.jusqu_a_ligne), func():
			if is_instance_valid(l):
				var tw := l.create_tween()
				tw.tween_property(l, "energy", 0.0, 0.6)
				tw.tween_callback(l.queue_free)])
		return
	var t := l.create_tween()
	for i in n:
		t.tween_property(l, "energy", energie, 0.05)
		t.tween_property(l, "energy", 0.0, 0.25)
		if i < n - 1:
			t.tween_interval(maxf(intervalle - 0.3, 0.0))
	t.tween_callback(l.queue_free)


# -------------------------------------------------------------------------------------- tirs

## Émetteur de tirs : une minuterie qui lance un trace lumineux tiré de la réserve, avec un
## éclair de bouche au départ et des étincelles à l'arrivée. S'arrête à « duree » (ou jamais).
func _emetteur_tirs(e: Dictionary) -> void:
	if not e.has("de") or not e.has("vers") or typeof(e.de) != TYPE_ARRAY:
		return  # origines nommées (fenêtres tireuses, frères) : à relever sur la peinture
	var em := Node2D.new()
	em.name = "Tirs"
	em.set_meta("cadence", float(e.get("cadence_s", 0.8)))
	em.set_meta("cadence_base", float(e.get("cadence_s", 0.8)))
	em.set_meta("x", valeur(e.de[0]))
	_ajouter(em)
	var bouche := _lumiere(Vector2.ZERO, BOLT if e.get("type") == "bolter" else LASER, 140)
	em.add_child(bouche)
	var t := Timer.new()
	t.wait_time = float(e.get("decalage_s", 0.0)) + 0.05
	em.add_child(t)
	t.timeout.connect(func():
		if not em.get_meta("arrete", false):
			_tirer(e, bouche)
		t.wait_time = float(em.get_meta("cadence")) * randf_range(0.7, 1.3))
	t.start()
	if e.has("nombre"):
		# Salve : n tirs répartis sur la durée, puis fin.
		em.set_meta("cadence", float(e.get("duree", 1.0)) / maxf(float(e.nombre), 1.0))
	if float(e.get("duree", 0.0)) > 0.0:
		_minuterie(float(e.duree), func():
			if is_instance_valid(em):
				em.queue_free())


func _tirer(e: Dictionary, bouche: PointLight2D) -> void:
	var de := point(e.de)
	var vers: Vector2
	if typeof(e.vers) == TYPE_STRING and e.vers == "joueur" and position_joueur.is_valid():
		vers = position_joueur.call() + Vector2(0, -90)
	elif typeof(e.vers) == TYPE_ARRAY:
		vers = point(e.vers)
	else:
		return
	var disp := float(e.get("dispersion_px", 0.0))
	vers += Vector2(randf_range(-disp, disp), randf_range(-disp, disp) * 0.4)
	var bolter: bool = e.get("type") == "bolter"
	var trace := _trait_libre()
	var couleur := Color(String(e.couleur)) if e.has("couleur") else (BOLT if bolter else LASER)
	(trace.get_child(0) as Line2D).self_modulate = couleur
	# Bolter : halo chaud large. Laser : halo #FF7A3A doux autour d'un cœur blanc épais.
	(trace.get_child(0) as Line2D).width = 11.0 if bolter else 14.0
	(trace.get_child(0) as Line2D).self_modulate.a = 1.0 if bolter else 0.55
	(trace.get_child(1) as Line2D).width = 1.8 if bolter else 3.2
	trace.visible = true
	trace.modulate.a = 1.0
	var longueur := 160.0 if bolter else 140.0
	var duree := maxf(de.distance_to(vers) / VITESSE_TIR_PX_S, 0.06)
	var ancien: Tween = trace.get_meta("tween") if trace.has_meta("tween") else null
	if ancien and ancien.is_valid():
		ancien.kill()  # réserve pleine : le trait est repris en vol
	var tw := trace.create_tween()
	trace.set_meta("tween", tw)
	tw.tween_method(_poser_trait.bind(trace, de, vers, longueur), 0.0, 1.0, duree)
	tw.tween_callback(_impact.bind(vers, bolter))
	# La traînée chaude reste un instant derrière la tête, puis s'éteint.
	tw.tween_property(trace, "modulate:a", 0.0, 0.18 if bolter else 0.08)
	tw.tween_callback(trace.hide)
	if bouche and is_instance_valid(bouche) and e.get("eclair_bouche", bolter):
		bouche.position = de
		_particules({"type": "etincelles", "zone_px": [de.x - 4, de.y - 4, 8, 8], "duree": 0.1,
			"densite": 0.25, "couleur": "#FFF2D0"})
		var tb := bouche.create_tween()
		tb.tween_property(bouche, "energy", 1.4, 0.03)
		tb.tween_property(bouche, "energy", 0.0, 0.12)


func _poser_trait(k: float, trace: Node2D, de: Vector2, vers: Vector2, longueur: float) -> void:
	var tete := de.lerp(vers, k)
	var queue := tete - (vers - de).normalized() * longueur
	if de.distance_to(queue) > de.distance_to(tete):
		queue = de
	# La largeur suit width_curve point par point : la ligne a POINTS_TRAIT sommets.
	for l in trace.get_children():
		for i in POINTS_TRAIT:
			(l as Line2D).set_point_position(i, queue.lerp(tete, float(i) / (POINTS_TRAIT - 1)))


func _trait_libre() -> Node2D:
	for t in _tirs:
		if is_instance_valid(t) and not t.visible:
			return t
	if _tirs.size() >= RESERVE_TIRS * 4:
		return _tirs[randi() % _tirs.size()]
	var t := Node2D.new()
	t.name = "Trait"
	t.z_index = Z_EFFETS
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in 2:
		var l := Line2D.new()
		var pts := PackedVector2Array()
		pts.resize(POINTS_TRAIT)
		l.points = pts
		l.gradient = _gradient_trainee()
		l.self_modulate = COEUR
		l.material = add
		l.width_curve = _courbe_tete()  # tête effilée, pas de bout rond
		t.add_child(l)
	_tirs.append(t)
	_ajouter(t)
	return t


static func _gradient_trainee() -> Gradient:
	if _degrade_trainee == null:
		_degrade_trainee = Gradient.new()
		_degrade_trainee.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.6), Color.WHITE])
		_degrade_trainee.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	return _degrade_trainee


static func _courbe_tete() -> Curve:
	if _courbe_trait == null:
		_courbe_trait = Curve.new()
		_courbe_trait.add_point(Vector2(0.0, 0.3))
		_courbe_trait.add_point(Vector2(0.8, 1.0))
		_courbe_trait.add_point(Vector2(1.0, 0.2))
	return _courbe_trait


func _impact(pos: Vector2, bolter: bool) -> void:
	_particules({"type": "etincelles", "zone_px": [pos.x - 6, pos.y - 6, 12, 12], "duree": 0.3,
		"densite": 0.6 if bolter else 0.35})
	if bolter:
		# Le bolt explose à l'impact : un petit nuage de poussière en plus des étincelles.
		_particules({"type": "poussiere", "zone_px": [pos.x - 10, pos.y - 10, 20, 20], "duree": 0.2,
			"densite": 0.15})
	else:
		# Le laser brûle : un bref flash rouge-orange.
		_particules({"type": "flash", "zone_px": [pos.x - 3, pos.y - 3, 6, 6], "duree": 0.1, "densite": 0.5})


func _emetteurs() -> Array[Node]:
	var r: Array[Node] = []
	for n in effets():
		if String(n.name).begins_with("Tirs"):
			r.append(n)
	return r


func _arreter_tirs(e: Dictionary) -> void:
	var duree := float(e.get("duree", 1.5))
	var liste := _emetteurs()
	# « droite_vers_gauche » : l'émetteur le plus à droite s'arrête le premier (la lumière de
	# l'Unification passe de droite à gauche) ; sinon, au hasard sur la durée.
	var ordonne := String(e.get("sens", "")) == "droite_vers_gauche"
	if ordonne:
		liste.sort_custom(func(a, b): return float(a.get_meta("x", 0.0)) > float(b.get_meta("x", 0.0)))
	for i in liste.size():
		var em := liste[i]
		var d := duree * float(i) / maxf(liste.size() - 1, 1) if ordonne else randf() * duree
		_minuterie(maxf(d, 0.001), func():
			if is_instance_valid(em):
				em.set_meta("arrete", true))


func _reprendre_tirs() -> void:
	for em in _emetteurs():
		em.set_meta("arrete", false)


## « tirs_cadence » : toutes les cadences de la scène ramenées à cette valeur (le choix minuté
## fige les tirs à une toutes les 2 s, Ilse les ralentit).
func _regler_cadence(c: float) -> void:
	for em in _emetteurs():
		em.set_meta("cadence", maxf(c, float(em.get_meta("cadence_base", c))))


# -------------------------------------------------------------------------------- explosions

## Obus et grenades : éclair, gerbe de gravats, fumée qui reste, tremblement. « intervalle_s »
## [min, max] les répète jusqu'au changement de décor.
func _explosions(e: Dictionary) -> void:
	var pos: Vector2
	if e.has("position_px"):
		pos = point(e.position_px)
	elif e.has("zone_px"):
		var z: Array = e.zone_px
		pos = Vector2(randf_range(z[0], z[0] + z[2]), randf_range(z[1], z[1] + z[3]))
	else:
		return
	_eclair({"position_px": [pos.x, pos.y], "couleur": e.get("couleur", "#FFD8A0"),
		"energie": e.get("energie", 2.0), "rayon_px": 700})
	_particules({"type": "gravats", "zone_px": [pos.x - 60, pos.y - 30, 120, 60], "duree": 0.6, "densite": 1.0})
	_particules({"type": "fumee", "zone_px": [pos.x - 50, pos.y - 40, 100, 60], "duree": 6.0, "densite": 0.4})
	if float(e.get("tremblement_px", 0.0)) > 0.0:
		_trembler({"amplitude_px": e.tremblement_px, "duree": 0.5})
	if e.has("intervalle_s"):
		var iv: Array = e.intervalle_s if typeof(e.intervalle_s) == TYPE_ARRAY else [e.intervalle_s, e.intervalle_s]
		_minuterie(randf_range(float(iv[0]), float(iv[1])), _explosions.bind(e))


# ------------------------------------------------------------------------------- tremblement

func _trembler(e: Dictionary) -> void:
	if camera == null:
		return
	var amp := float(e.get("amplitude_px", 4.0))
	var duree := float(e.get("duree", 0.5))
	var graine := randf() * 1000.0
	var t := create_tween()
	t.tween_method(func(k: float):
		if is_instance_valid(camera):
			var a := amp * (1.0 - k)
			camera.offset = Vector2(_bruit.get_noise_2d(graine + k * duree * 60.0, 0.0),
				_bruit.get_noise_2d(0.0, graine + k * duree * 60.0)) * a * 2.0, 0.0, 1.0, duree)
	t.tween_callback(func():
		if is_instance_valid(camera):
			camera.offset = Vector2.ZERO)


# ----------------------------------------------------------------------------------- calques

## Le Sprite2D « Image » d'un calque du décor (Calque_NN_nom), ou null.
func image_du_calque(nom: String) -> Node2D:
	if decor == null:
		return null
	var c := decor.get_node_or_null(NodePath(nom))
	if c == null and "calques" in decor:
		for k in decor.calques:
			if String(k.name) == nom:
				c = k
	if c == null:
		return null
	var img := c.get_node_or_null(^"Image") as Node2D
	return img if img else c as Node2D


func _animer_calque(e: Dictionary) -> void:
	var img := image_du_calque(String(e.get("calque", "")))
	if img == null:
		return  # calque pas encore détaché par CA2 : rien à animer
	var amp := float(e.get("amplitude_px", 4.0))
	var periode := float(e.get("periode_s", 2.0))
	var duree := float(e.get("duree", 1.0))
	if not img.has_meta("position_mes"):
		img.set_meta("position_mes", img.position)
		img.set_meta("alpha_mes", img.modulate.a)
		_images_animees.append(img)
	var depart: Vector2 = img.position
	var t := create_tween()
	_tweens_calques.append(t)
	match String(e.get("anim", "")):
		"osciller", "flotter":
			var axe := Vector2.RIGHT if e.anim == "osciller" else Vector2.DOWN
			t.set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t.tween_property(img, "position", depart + axe * amp, periode / 2.0)
			t.tween_property(img, "position", depart - axe * amp, periode / 2.0)
		"defiler":
			# amplitude_px par seconde, en aller-retour lent (20 s) pour ne jamais découvrir le bord.
			t.set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t.tween_property(img, "position", depart + Vector2(amp * 20.0, 0), 20.0)
			t.tween_property(img, "position", depart, 20.0)
		"monter", "descendre":
			var sens := -1.0 if e.anim == "monter" else 1.0
			t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t.tween_property(img, "position", depart + Vector2(0, sens * amp), duree)
			if e.get("puis") == "disparaitre":
				t.tween_property(img, "modulate:a", 0.0, 0.4)
			elif e.get("puis") == "osciller":
				t.tween_callback(_animer_calque.bind({"calque": e.calque, "anim": "osciller", "amplitude_px": 3, "periode_s": 1.6}))
		"apparaitre":
			img.modulate.a = 0.0
			t.tween_property(img, "modulate:a", 1.0, maxf(duree, 0.01))
		"disparaitre":
			t.tween_property(img, "modulate:a", 0.0, maxf(duree, 0.01))
		_:
			t.kill()  # « clignoter » et autres : shader du Lead, pas encore


# ------------------------------------------------------------------------------ plein écran

## Plan peint plein cadre posé par-dessus tout (raccord par le regard Cthonia → Ullanor, CA1) :
## entrée depuis une couleur (le blanc chaud), tenue avec un clignement, sortie en fondu sur ce
## qui joue dessous. Il survit au changement de décor (il couvre justement la coupe) et se
## retire seul.
##   {"dossier": "res://assets/plans/oeil_vaskar", "image": "10_oeil_ouvert.png",
##    "clignement": ["20_paupiere_mi.png", "21_paupiere_fermee.png"], "clignement_s": 0.7,
##    "couleur_entree": "#FFE8C0", "entree_s": 0.35, "tenue_s": 1.4, "sortie_s": 0.6}
func _plein_ecran(e: Dictionary) -> void:
	var dossier := String(e.get("dossier", ""))
	var chemin := dossier.path_join(String(e.get("image", "")))
	if not ResourceLoader.exists(chemin):
		push_warning("Mise en scène : plan plein écran introuvable : %s" % chemin)
		return
	var couche := CanvasLayer.new()
	couche.name = "PleinEcran"
	couche.layer = 40
	add_child(couche)
	var fond := ColorRect.new()
	fond.color = Color(String(e.get("couleur_entree", "#FFE8C0")))
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	couche.add_child(fond)
	var image := _texture_plein_ecran(load(chemin))
	image.modulate.a = 0.0
	couche.add_child(image)
	var paupieres: Array[TextureRect] = []
	for f in e.get("clignement", []):
		var c := dossier.path_join(String(f))
		if ResourceLoader.exists(c):
			var p := _texture_plein_ecran(load(c))
			p.visible = false
			couche.add_child(p)
			paupieres.append(p)
	var entree := float(e.get("entree_s", 0.35))
	var tenue := float(e.get("tenue_s", 1.4))
	var sortie := float(e.get("sortie_s", 0.6))
	var t := couche.create_tween()
	t.tween_property(image, "modulate:a", 1.0, entree)
	t.tween_callback(func(): fond.visible = false)
	if paupieres.size() >= 2:
		# Rythme de CA1 : mi 40 ms, fermée 70 ms, mi 50 ms.
		var avant := clampf(float(e.get("clignement_s", tenue * 0.45)), 0.0, tenue)
		t.tween_interval(avant)
		t.tween_callback(func(): paupieres[0].visible = true)
		t.tween_interval(0.04)
		t.tween_callback(func():
			paupieres[0].visible = false
			paupieres[1].visible = true)
		t.tween_interval(0.07)
		t.tween_callback(func():
			paupieres[1].visible = false
			paupieres[0].visible = true)
		t.tween_interval(0.05)
		t.tween_callback(func(): paupieres[0].visible = false)
		t.tween_interval(maxf(tenue - avant - 0.16, 0.0))
	else:
		t.tween_interval(tenue)
	t.tween_property(image, "modulate:a", 0.0, sortie)
	t.tween_callback(couche.queue_free)


func _texture_plein_ecran(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
