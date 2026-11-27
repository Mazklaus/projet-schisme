class_name RigPersonnage
extends Node2D
## Personnage découpé en pièces (contrat de découpe v1, animation/contrat-rig-personnages.md) :
## un Skeleton2D d'os (Bone2D) bâti depuis rig.json, et les pièces peintes à plat sous la racine,
## dans l'ordre z du contrat, chacune suivant son os par un RemoteTransform2D. Pas de z_index :
## la figure se trie dans le monde (y_sort) comme un seul sprite, origine aux pieds.
## Animations procédurales : respiration, clignement, marche, tête, gestes de data/anim/gestes.json.
## Les gestes se lancent depuis les dialogues : « @geste <perso> <geste> » (voir jouer_geste).

## Événements pour le son et la mise en scène : &"pas" à chaque appui, &"geste_<nom>" au début
## d'un geste. perso : l'identifiant du personnage (rig.json « perso »).
signal evenement_anim(nom: StringName, perso: StringName)
signal geste_termine(nom: StringName)

const GESTES := "res://data/anim/gestes.json"
## Ordre z du contrat, du fond vers l'avant (les variantes suivent leur pièce de base).
const ORDRE := [
	"bras_arriere", "avant_bras_arriere", "main_arriere", "epauliere_arriere", "cuisse_arriere",
	"jambe_arriere", "pied_arriere", "cape", "bassin", "arme_fourreau", "torse", "tete", "tete_face",
	"yeux_fermes", "yeux_fermes_face", "cuisse_avant", "jambe_avant", "pied_avant", "bras_avant",
	"avant_bras_avant", "main_avant", "main_avant_pointe", "main_avant_poing", "bras_croises", "arme_main",
	"epauliere_avant",
]
## Variantes : même os que leur pièce de base pour les angles, une seule visible à la fois.
const VARIANTES := {"main_avant_pointe": "main_avant", "main_avant_poing": "main_avant", "tete_face": "tete"}
## Fréquence de la marche (rad/s) : un appui toutes les 0,35 s, comme le pas de PersonnageJoue.
const PAS_RAD_S := 9.0

var perso: StringName = &""
var type_rig := "humain"
var squelette: Skeleton2D
var os: Dictionary = {}       # nom -> Bone2D
var pieces: Dictionary = {}   # nom -> Sprite2D
var repos: Dictionary = {}    # nom -> position de repos de l'os
## Vitesse de marche normalisée (0 : arrêt, 1 : pas normal). Posée par le joueur ou un script.
var marche := 0.0
## Tête : rotation supplémentaire (degrés) et vue de face.
var regard_deg := 0.0

var _gestes: Dictionary = {}
var _entree := 0.35
var _sortie := 0.45
var _geste := ""
var _poids := 0.0
var _temps_geste := 0.0
var _pose_geste: Dictionary = {}
var _bassin_y := 0.0
var _depart_geste: Dictionary = {}
var _cible_geste: Dictionary = {}
var _depart_bassin := 0.0
var _cible_bassin := 0.0
var _depart_poids := 0.0
var _t_transition := 1.0
var _transition_vers_geste := false
var _relancer := false
## Pièces dédiées à un geste (« montre » dans gestes.json) : cachées hors de leur geste.
var _pieces_de_geste: Array = []
var _hauteur := 0.0
var _phase_marche := 0.0
var _poids_marche := 0.0
var _temps := 0.0
var _souffle_phase := 0.0
var _prochain_clignement := 2.0
var _fin_clignement := -1.0


## Construit le rig depuis un dossier « pied » (rig.json + pièces). null si rig.json manque.
static func charger(dossier: String) -> RigPersonnage:
	var chemin := dossier.path_join("rig.json")
	if not FileAccess.file_exists(chemin):
		return null
	var donnees = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	if typeof(donnees) != TYPE_DICTIONARY or not donnees.has("pieces"):
		push_error("Rig : %s illisible" % chemin)
		return null
	var r := RigPersonnage.new()
	r.construire(donnees, dossier)
	return r


func construire(d: Dictionary, dossier: String) -> void:
	perso = StringName(d.get("perso", ""))
	name = String(perso) if perso != &"" else "Rig"
	type_rig = String(d.get("type", "humain"))
	var pieds := _vec(d.get("pieds", [0, 0]))
	var P: Dictionary = d.pieces
	_hauteur = 0.0
	for n in P:
		_hauteur = maxf(_hauteur, pieds.y - float(P[n].pose[1]))
	squelette = Skeleton2D.new()
	squelette.name = "Squelette"
	add_child(squelette)
	# Os : position du pivot dans la planche, relative à l'os parent (aux pieds pour la racine).
	var restants := P.keys()
	while not restants.is_empty():
		var avance := false
		for n in restants.duplicate():
			var parent = P[n].get("parent")
			if parent != null and not os.has(parent):
				if not P.has(parent):
					push_warning("Rig %s : parent inconnu %s pour %s" % [perso, parent, n])
					P[n].parent = null
				continue
			var b := Bone2D.new()
			b.name = n
			b.set_autocalculate_length_and_angle(false)
			b.set_length(8.0)
			var pos := _pivot_planche(P[n])
			b.position = pos - (_pivot_planche(P[parent]) if parent != null else pieds)
			b.rest = b.transform
			(os[parent] if parent != null else squelette).add_child(b)
			os[n] = b
			repos[n] = b.position
			restants.erase(n)
			avance = true
		if not avance:
			push_error("Rig %s : boucle de parents" % perso)
			break
	# Pièces à plat dans l'ordre z (celles hors contrat à la fin, dans l'ordre du fichier).
	var noms: Array = ORDRE.filter(func(n): return P.has(n))
	for n in P:
		if not n in noms:
			noms.append(n)
	for n in noms:
		var s := Sprite2D.new()
		s.name = "Piece_" + n
		s.centered = false
		s.offset = -_vec(P[n].pivot)
		var tex := CanvasTexture.new()
		var f := dossier.path_join(String(P[n].fichier))
		tex.diffuse_texture = _texture(f)
		var fn := f.get_basename() + "_normal.png"
		if ResourceLoader.exists(fn) or FileAccess.file_exists(fn):
			tex.normal_texture = _texture(fn)
		s.texture = tex
		add_child(s)
		var rt := RemoteTransform2D.new()
		rt.name = "Suivi"
		rt.update_scale = true
		os[n].add_child(rt)
		s.set_meta("suivi", rt)
		pieces[n] = s
	_gestes = _lire_gestes()
	for g in _gestes.get("gestes", {}).values():
		for n in g.get("montre", []):
			if not n in _pieces_de_geste:
				_pieces_de_geste.append(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(perso))
	_souffle_phase = rng.randf() * TAU
	_prochain_clignement = rng.randf_range(1.5, 4.0)
	_variantes("", "")
	_pieces_geste({})
	_clignement(false)


func _ready() -> void:
	# Les chemins des RemoteTransform2D ne se résolvent qu'une fois dans l'arbre.
	for n in pieces:
		var rt: RemoteTransform2D = pieces[n].get_meta("suivi")
		rt.remote_path = rt.get_path_to(pieces[n])


static func _vec(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func _pivot_planche(p: Dictionary) -> Vector2:
	return _vec(p.pose) + _vec(p.pivot)


## Texture importée si possible, sinon lue à la volée (pièces hors res:// : aperçus, tests).
static func _texture(chemin: String) -> Texture2D:
	if ResourceLoader.exists(chemin):
		return load(chemin)
	var img := Image.load_from_file(chemin)
	return ImageTexture.create_from_image(img) if img else null


static func _lire_gestes() -> Dictionary:
	if not FileAccess.file_exists(GESTES):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(GESTES))
	return d if typeof(d) == TYPE_DICTIONARY else {}


func gestes_connus() -> Array:
	return _gestes.get("gestes", {}).keys()


## Lance un geste (nom de data/anim/gestes.json). « repos » relâche un geste tenu.
## Renvoie false si le geste est inconnu.
func jouer_geste(nom: String) -> bool:
	var g: Dictionary = _gestes.get("gestes", {}).get(nom, {})
	if g.is_empty():
		push_warning("Rig %s : geste inconnu « %s »" % [perso, nom])
		return false
	_entree = float(_gestes.get("entree_s", 0.35))
	_sortie = float(_gestes.get("sortie_s", 0.45))
	_geste = nom
	_temps_geste = 0.0
	# Un nouveau geste (ou « repos ») repart de la pose courante, même si un autre était posé.
	_relancer = true
	evenement_anim.emit(StringName("geste_" + nom), perso)
	_son_geste(String(g.get("son", "")))
	return true


## Temps avant que le geste soit lisible (posé) : l'entrée, plus la durée s'il ne se tient pas.
func duree_visible(nom: String) -> float:
	var g: Dictionary = _gestes.get("gestes", {}).get(nom, {})
	return float(_gestes.get("entree_s", 0.35)) + (0.0 if g.get("tenir", false) else float(g.get("duree", 0.0)))


func geste_en_cours() -> String:
	return _geste


func _son_geste(ampleur: String) -> void:
	var son := get_node_or_null(^"/root/Son")
	if son == null or ampleur.is_empty():
		return
	# Bruitages de l'ép. 1 (Sound Designer) : céramite pour un geste ample, servo pour un fin.
	if type_rig == "astartes":
		son.bruitage("geste_armure" if ampleur == "ample" else "servo")
	elif ampleur == "ample":
		son.bruitage("geste_armure")


func _process(delta: float) -> void:
	avancer(delta)


## Avance l'animation de delta secondes (appelée chaque image, et par les tests).
func avancer(delta: float) -> void:
	_temps += delta
	var angles := {}
	# Respiration : le torse s'étire un peu (bras et tête suivent, portés par lui).
	var s := 0.5 + 0.5 * sin(TAU * _temps / 4.2 + _souffle_phase)
	s = s * s * (3.0 - 2.0 * s)
	if os.has("torse"):
		os.torse.scale = Vector2(1.0, 1.0 + 0.012 * s)
	# Marche : cycle des jambes et des bras, appui à chaque extrême.
	_poids_marche = move_toward(_poids_marche, 1.0 if marche > 0.05 else 0.0, delta * 5.0)
	var bob := 0.0
	if _poids_marche > 0.0:
		var avant := cos(_phase_marche)
		_phase_marche += delta * PAS_RAD_S * clampf(marche, 0.5, 1.6) * (1.0 if marche > 0.05 else 0.6)
		if signf(cos(_phase_marche)) != signf(avant) and marche > 0.05:
			_appui()
		var m := angles_marche(_phase_marche)
		for k in m:
			angles[k] = float(m[k]) * _poids_marche
		bob = poids_marche(_phase_marche) * _poids_marche
	# Geste : la pose part de la pose courante vers celle du geste (entrée), y reste (durée, ou
	# tant qu'un geste « tenir » n'est pas relâché), puis revient au repos (sortie). Chaque
	# transition suit une courbe avec anticipation (léger contre-mouvement), dépassement à
	# l'arrivée et ease-in-out : jamais de saut, même d'un geste à l'autre.
	var g: Dictionary = _gestes.get("gestes", {}).get(_geste, {})
	_temps_geste += delta
	var actif: bool = not g.is_empty() and _geste != "repos" \
		and (g.get("tenir", false) or _temps_geste < _entree + float(g.get("duree", 1.0)))
	if actif != _transition_vers_geste or _relancer:
		_relancer = false
		_lancer_transition(g.get("os", {}) if actif else {}, float(g.get("bassin_y", 0.0)) if actif else 0.0, actif)
	_t_transition = minf(1.0, _t_transition + delta / (_entree if actif else _sortie))
	var f := courbe_geste(_t_transition)
	for n in _cible_geste:
		_pose_geste[n] = lerpf(float(_depart_geste.get(n, 0.0)), float(_cible_geste[n]), f)
	_bassin_y = lerpf(_depart_bassin, _cible_bassin, f)
	_poids = clampf(lerpf(_depart_poids, 1.0 if actif else 0.0, f), 0.0, 1.0)
	if not actif and _geste != "" and _t_transition >= 1.0:
		var fini := _geste
		_geste = ""
		_pose_geste.clear()
		geste_termine.emit(StringName(fini))
	for n in _pose_geste:
		angles[n] = float(angles.get(n, 0.0)) * (1.0 - _poids) + _pose_geste[n]
	angles["tete"] = float(angles.get("tete", 0.0)) + regard_deg
	for n in os:
		var base: String = VARIANTES.get(n, n)
		os[n].rotation = deg_to_rad(float(angles.get(base, 0.0)))
		os[n].position = repos[n]
	for racine in squelette.get_children():
		racine.position = repos[String(racine.name)] + Vector2(0, bob + _bassin_y)
	var montre: bool = actif and _poids > 0.5
	_variantes(String(g.get("main", "")) if montre else "", String(g.get("tete", "")) if montre else "")
	_pieces_geste(g if montre else {})
	# Clignement : 0,12 s toutes les 2 à 6 s.
	if _temps >= _prochain_clignement and _fin_clignement < 0.0:
		_fin_clignement = _temps + 0.12
		_clignement(true)
	elif _fin_clignement >= 0.0 and _temps >= _fin_clignement:
		_fin_clignement = -1.0
		_prochain_clignement = _temps + randf_range(2.0, 6.0)
		_clignement(false)


## Fige la pose courante comme départ d'une transition vers « cible » (os -> degrés).
func _lancer_transition(cible: Dictionary, bassin_y: float, vers_geste: bool) -> void:
	_depart_geste = _pose_geste.duplicate()
	_cible_geste = {}
	for n in _pose_geste:
		_cible_geste[n] = 0.0
	for n in cible:
		_cible_geste[n] = float(cible[n])
		if not _pose_geste.has(n):
			_pose_geste[n] = 0.0
	_depart_bassin = _bassin_y
	_cible_bassin = bassin_y
	_depart_poids = _poids
	_t_transition = 0.0
	_transition_vers_geste = vers_geste


## Courbe des gestes (« back » ease-in-out adouci) : part en arrière d'environ 4 %, dépasse
## d'environ 4 % avant de se poser. u et le résultat vont de 0 à 1.
static func courbe_geste(u: float) -> float:
	const C2 := 1.0 * 1.525
	var x := clampf(u, 0.0, 1.0) * 2.0
	if x < 1.0:
		return x * x * ((C2 + 1.0) * x - C2) / 2.0
	x -= 2.0
	return (x * x * ((C2 + 1.0) * x + C2) + 2.0) / 2.0


## Angles de la marche à la phase phi (degrés, négatif = vers l'avant).
static func angles_marche(phi: float) -> Dictionary:
	var s := sin(phi)
	var c := cos(phi)
	var a := {
		"cuisse_avant": -22.0 * s, "cuisse_arriere": 22.0 * s,
		"jambe_avant": 32.0 * maxf(0.0, c), "jambe_arriere": 32.0 * maxf(0.0, -c),
		"bras_avant": 15.0 * s, "bras_arriere": -15.0 * s,
		"avant_bras_avant": -8.0 - 6.0 * maxf(0.0, -s), "avant_bras_arriere": -8.0 - 6.0 * maxf(0.0, s),
		# Épaules en opposition du bassin : le bassin suit la jambe avant, le torse contre.
		"bassin": 2.5 * s, "torse": -2.0 - 4.5 * s, "tete": 2.0 * s,
	}
	a["pied_avant"] = -0.6 * (a.cuisse_avant + a.jambe_avant)
	a["pied_arriere"] = -0.6 * (a.cuisse_arriere + a.jambe_arriere)
	return a


## Poids de la marche : le bassin descend au contact du pied (px source, + = vers le bas),
## remonte au passage de la jambe.
static func poids_marche(phi: float) -> float:
	var s := absf(sin(phi))
	return 8.0 * s * s * s - 3.0


func _appui() -> void:
	evenement_anim.emit(&"pas", perso)
	var son := get_node_or_null(^"/root/Son")
	if son:
		son.bruitage("pas_armure" if type_rig == "astartes" else "pas_civil")


func _variantes(main: String, tete: String) -> void:
	for n in ["main_avant", "main_avant_pointe", "main_avant_poing"]:
		if pieces.has(n):
			var voulu := "main_avant" + ("_" + main if not main.is_empty() else "")
			pieces[n].visible = n == voulu if pieces.has(voulu) else n == "main_avant"
	var face: bool = tete == "face" and pieces.has("tete_face")
	if pieces.has("tete"):
		pieces.tete.visible = not face
	if pieces.has("tete_face"):
		pieces.tete_face.visible = face
	_clignement(_fin_clignement >= 0.0)


## Pièces dédiées (bras croisés…) : montrées pendant leur geste, à la place des pièces
## « cache ». Sans la pièce livrée, le geste garde le rig ordinaire.
func _pieces_geste(g: Dictionary) -> void:
	var montre: Array = g.get("montre", []).filter(func(n): return pieces.has(n))
	for n in _pieces_de_geste:
		if pieces.has(n):
			pieces[n].visible = n in montre
	if not montre.is_empty():
		for n in g.get("cache", []):
			if pieces.has(n):
				pieces[n].visible = false


func _clignement(ferme: bool) -> void:
	var face: bool = pieces.has("tete_face") and pieces.tete_face.visible
	if pieces.has("yeux_fermes"):
		pieces.yeux_fermes.visible = ferme and not face
	if pieces.has("yeux_fermes_face"):
		pieces.yeux_fermes_face.visible = ferme and face


## Hauteur de la figure au repos (px source), pour l'échelle en jeu.
func hauteur() -> float:
	return _hauteur
