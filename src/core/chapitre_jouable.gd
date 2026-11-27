class_name ChapitreJouable
extends Chapitre
## Chapitre avec des phases de jeu, pour tous les chapitres des épisodes :
##   - décors à la demande : « @decor <id> » montre un décor de la scène (nœud Decor25D, par son
##     id ou son nom en minuscules), charge assets/decors/<id>/, ou, tant que la DA ne l'a pas
##     livré, construit un décor provisoire qui porte son nom ;
##   - exploration : « @jeu [zone] » rend la main au joueur à la fin du dialogue en cours, dans
##     la zone décrite par le fichier « jeu » du chapitre (par défaut, la zone porte le nom du
##     nœud qui a appelé @jeu) ;
##   - répliques au vox en surimpression, invite de déplacement, écran de fin d'épisode.
##
## Fichier « jeu » (JSON, champ "jeu" du chapitre dans episode.json), une entrée par zone :
##   "cthonia": {
##     "decor": "cthonia_tunnel",            décor de la zone (par défaut : le décor courant)
##     "depart": [300, 900],                 position du joueur au début
##     "personnage": "vaskar", "echelle": 0.6,
##     "limites": [100, 800, 3640, 200],     zone de marche (x, y, largeur, hauteur)
##     "pois": {"poi_lampe": [900, 880]},    points d'intérêt (nœud → position) ; E pour lire
##     "figurants": {"poi_lampe": "frere_1"},  sprite posé sur un point (placeholder sinon)
##     "obligatoires": ["poi_lampe"],
##     "declencheurs": [{"x": 2400, "noeud": "cthonia_proche", "apres": ["poi_lampe"],
##                       "max_s": 300}],     passer x (ou attendre max_s secondes après avoir vu
##                                           les points « apres ») lance le nœud
##     "relance": {"s": 30, "noeud": "vox_relance"}   réplique au vox après s d'inactivité
##   }
## Un déclencheur termine l'exploration : son dialogue mène la suite (un autre @jeu, ou la fin
## du chapitre).

const POI_DISTANCE := 160.0
const AIDE_DEPLACEMENT_S := 4.0
const ZONE_MARCHE_DEFAUT := Rect2(100, 800, 3640, 200)
const DEPART_DEFAUT := Vector2(300, 900)
const PROPS := "res://assets/tranche_ullanor/props/"
const DOSSIER_DECORS := "res://assets/decors"
const TAILLE_PROVISOIRE := Vector2(3840, 1080)

var phase := "cine"
## Zones d'exploration du chapitre (fichier « jeu »), zone courante et sa configuration.
var zones: Dictionary = {}
var zone := ""
var config: Dictionary = {}
var pois: Dictionary = {}
var pois_vus := {}
var joueur: PersonnageJoue
var decors: Dictionary = {}
var decor_courant := ""
var temps_jeu := 0.0
## Secondes passées sans bouger ni lire (remis à zéro à chaque mouvement).
var inactif := 0.0
var relance_faite := false
var aide_vue := false
var ecran_fin: Control
var props := {}
var _a_bouge := false
var _zone_demandee := ""
var _declenches := {}
## Temps de jeu au moment où les points « apres » d'un déclencheur ont été vus.
var _vus_depuis := {}
var _ui: CanvasLayer
var _invite: Label
var _vox: Label
var _aide: Control
var _voile_noir: ColorRect
var _vox_file: Array[String] = []
var _vox_actif := false


func _ready() -> void:
	_construire_ui()
	for n in get_children():
		if n is Decor25D:
			decors[n.id_decor] = n
			decors[String(n.name).to_lower()] = n
	if decor == null:
		for n in get_children():
			if n is Decor25D:
				decor = n
				break
	joueur = PersonnageJoue.new()
	joueur.name = "Joueur"
	joueur.position = DEPART_DEFAUT
	joueur.limites = ZONE_MARCHE_DEFAUT
	joueur.sprite = _sprite("vaskar")
	joueur.add_child(joueur.sprite)
	joueur.visible = false
	super._ready()


func _avant_dialogue() -> void:
	if infos.has("jeu"):
		var z = JSON.parse_string(FileAccess.get_file_as_string(infos.jeu))
		if typeof(z) == TYPE_DICTIONARY:
			zones = z
		else:
			push_error("Fichier jeu illisible : %s" % infos.jeu)
	lecteur.noeud_entre.connect(_mise_en_scene_du_noeud)


# --------------------------------------------------------------------------- mise en scène

## « mises_en_scene » du fichier jeu : ce que fait l'entrée dans un nœud, sans toucher au .dlg
## de la narration (ambiance, musique, effets animés). « ambiances » : l'ambiance de chaque décor.
func _mise_en_scene_du_noeud(noeud: String) -> void:
	var m = zones.get("mises_en_scene", {}).get(noeud)
	if typeof(m) != TYPE_DICTIONARY:
		return
	if m.has("musique"):
		Son.musique(m.musique[0], float(m.musique[1]) if m.musique.size() > 1 else 2.0)
	if m.has("ambiance"):
		Son.ambiance(m.ambiance[0], float(m.ambiance[1]) if m.ambiance.size() > 1 else 2.0)
	if m.has("lumiere_montante"):
		_lumiere_montante(m.lumiere_montante)
	# « etats » : [[nom, durée], …] enchaînés sur le décor affiché (l'aube pendant le C7).
	if m.has("etats") and decor_par_id(decor_courant) is Decor25D:
		_enchainer_etats(decor_par_id(decor_courant), m.etats)


func _enchainer_etats(d: Decor25D, liste: Array) -> void:
	for e in liste:
		d.appliquer_etat(String(e[0]), float(e[1]))
		await get_tree().create_timer(float(e[1])).timeout


## Une lumière qui monte (l'Empereur à l'Unification, DA) : un calque de 0 à 1 avec une montée
## d'échelle, une PointLight2D qui monte en même temps, l'ambiance qui blanchit un instant.
func _lumiere_montante(e: Dictionary) -> void:
	var d := decor_par_id(decor_courant)
	var duree := float(e.get("duree", 2.5))
	var t := create_tween().set_parallel()
	var calque := d.get_node_or_null(String(e.get("calque", ""))) as Node2D
	if calque:
		var image := calque.get_node_or_null(^"Image") as Node2D
		var cible: Node2D = image if image else calque
		var ech: Array = e.get("echelle", [1.0, 1.0])
		calque.visible = true
		cible.modulate.a = 0.0
		var centre := Vector2(e.get("centre_px", [960, 540])[0], e.get("centre_px", [960, 540])[1])
		# Échelle autour du centre de la lumière, pas du coin du calque.
		cible.scale = Vector2.ONE * float(ech[0])
		cible.position = centre - centre * float(ech[0])
		t.tween_property(cible, "modulate:a", 1.0, duree)
		t.tween_property(cible, "scale", Vector2.ONE * float(ech[1]), duree)
		t.tween_property(cible, "position", centre - centre * float(ech[1]), duree)
	if e.has("lumiere"):
		var L: Dictionary = e.lumiere
		var l := _lumiere(Vector2(L.position_px[0], L.position_px[1]), Color(L.get("couleur", "#FFF1D0")),
			float(L.get("rayon_px", 900)) / 128.0)
		l.energy = 0.0
		l.height = 300.0
		d.add_child(l)
		t.tween_property(l, "energy", float(L.get("energie", 2.5)), duree)
	var amb := get_node_or_null(^"Ambiance") as CanvasModulate
	if amb and e.has("ambiance"):
		var avant := amb.color
		var t2 := create_tween()
		t2.tween_property(amb, "color", Color(e.ambiance), duree * 0.6)
		t2.tween_property(amb, "color", avant, duree)


## Plan objet : changer de décor si besoin, puis remplacer des textures de calques (extérieur de
## la galerie : croisade, warp, Orvane).
func _preparer_plan(p: Dictionary) -> void:
	if p.has("decor") and p.decor != decor_courant:
		await _changer_decor(p.decor)
	var d := decor_par_id(p.get("decor", decor_courant))
	for nom in p.get("textures", {}):
		var image := d.get_node_or_null(NodePath(String(nom) + "/Image")) as Sprite2D
		var chemin := "%s/%s/%s" % [DOSSIER_DECORS, p.get("decor", decor_courant), p.textures[nom]]
		if image and ResourceLoader.exists(chemin) and image.texture is CanvasTexture:
			(image.texture as CanvasTexture).diffuse_texture = load(chemin)
		else:
			push_warning("Plan : texture %s introuvable pour %s" % [chemin, nom])


# --------------------------------------------------------------------------- interface

func _construire_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "UIJeu"
	_ui.layer = 10
	add_child(_ui)
	_vox = Label.new()
	_vox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_vox.offset_top = 60
	_vox.offset_bottom = 140
	_vox.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vox.add_theme_font_size_override("font_size", 30)
	_vox.add_theme_color_override("font_outline_color", Color.BLACK)
	_vox.add_theme_constant_override("outline_size", 8)
	_ui.add_child(_vox)
	_aide = _construire_aide_deplacement()
	_ui.add_child(_aide)
	_voile_noir = ColorRect.new()
	_voile_noir.color = Color.BLACK
	_voile_noir.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile_noir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voile_noir.modulate.a = 0.0
	_ui.add_child(_voile_noir)
	_invite = Label.new()
	_invite.add_theme_font_size_override("font_size", 26)
	_invite.add_theme_color_override("font_outline_color", Color.BLACK)
	_invite.add_theme_constant_override("outline_size", 8)
	_invite.z_index = 100
	_invite.hide()
	add_child(_invite)


## Invite des touches de déplacement (jamais de touche en dur : règle GD), en bas de l'écran. Les lettres sont celles du
## clavier du joueur (ZQSD en AZERTY, WASD en QWERTY).
func _construire_aide_deplacement() -> Control:
	var touches: PackedStringArray = []
	for a in ["haut", "gauche", "bas", "droite"]:
		touches.append(touche(a))
	var l := Label.new()
	l.name = "AideDeplacement"
	l.text = "Se déplacer :  %s   ·   ← ↑ → ↓   ·   stick gauche" % "  ".join(touches)
	l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.offset_top = -150
	l.offset_bottom = -70
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color("#F2EAD3"))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	var plaque := StyleBoxFlat.new()
	plaque.bg_color = Color(0.04, 0.03, 0.02, 0.82)
	plaque.border_color = Color("#C9A44C")
	plaque.set_border_width_all(2)
	plaque.set_corner_radius_all(6)
	plaque.content_margin_left = 28
	plaque.content_margin_right = 28
	plaque.content_margin_top = 12
	plaque.content_margin_bottom = 12
	l.add_theme_stylebox_override("normal", plaque)
	l.modulate.a = 0.0
	l.hide()
	return l


## Libellé de la première touche clavier d'une action, selon la disposition du clavier du
## joueur (touche physique traduite par le système : Z en AZERTY pour le W physique).
## Aucun texte du jeu ne doit écrire une touche en dur.
static func touche(action: String) -> String:
	for e in InputMap.action_get_events(action) if InputMap.has_action(action) else []:
		if e is InputEventKey:
			var code: Key = e.physical_keycode
			if code == KEY_NONE:
				return OS.get_keycode_string(e.keycode)
			var k := KEY_NONE
			if DisplayServer.get_name() != "headless":
				k = DisplayServer.keyboard_get_label_from_physical(code)
			return OS.get_keycode_string(k if k != KEY_NONE else code)
	return ""


func _inviter(pos: Vector2, texte: String) -> void:
	if _invite.get_parent() != joueur.get_parent() and joueur.get_parent() != null:
		_invite.reparent(joueur.get_parent(), false)
	_invite.text = texte
	_invite.position = pos + Vector2(-90, -300)
	_invite.show()


func _fondu_noir(opacite: float, duree: float) -> void:
	var t := create_tween()
	t.tween_property(_voile_noir, "modulate:a", opacite, duree)
	await t.finished


# --------------------------------------------------------------------------- sprites

func _sprite(nom: String, normales := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = nom
	var chemin := PROPS + nom + ".png"
	if not ResourceLoader.exists(chemin):
		return _sprite_provisoire(nom)
	var tex := CanvasTexture.new()
	tex.diffuse_texture = load(chemin)
	if normales and ResourceLoader.exists(PROPS + nom + "_normal.png"):
		tex.normal_texture = load(PROPS + nom + "_normal.png")
	s.texture = tex
	# Origine aux pieds : le tri en profondeur (y_sort) se fait sur la ligne du sol.
	s.offset = Vector2(0, -tex.diffuse_texture.get_height() / 2.0)
	return s


## Silhouette grise étiquetée, pour un figurant que la chaîne d'images n'a pas encore livré.
func _sprite_provisoire(nom: String) -> Sprite2D:
	var img := Image.create(120, 260, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(30, 70, 60, 190), Color(0.55, 0.52, 0.48))
	img.fill_rect(Rect2i(40, 20, 40, 50), Color(0.62, 0.58, 0.52))
	var s := Sprite2D.new()
	s.name = nom
	s.texture = ImageTexture.create_from_image(img)
	s.offset = Vector2(0, -130)
	var l := Label.new()
	l.text = nom
	l.position = Vector2(-60, -300)
	l.add_theme_font_size_override("font_size", 20)
	s.add_child(l)
	return s


func _prop(parent: Node, nom: String, pos: Vector2) -> Sprite2D:
	var s := _sprite(nom)
	s.position = pos
	parent.add_child(s)
	props[nom] = s
	return s


func _lumiere(pos: Vector2, couleur: Color, echelle: float) -> PointLight2D:
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
	l.texture_scale = echelle
	l.position = pos
	l.color = couleur
	l.energy = 1.3
	l.height = 60.0
	return l


# --------------------------------------------------------------------------- décors

## Décor par son id (ou alias) : celui de la scène, celui des assets, ou un décor provisoire.
func decor_par_id(id_demande: String) -> Node2D:
	var id: String = resoudre_decor(id_demande).decor
	if decors.has(id):
		return decors[id]
	var d: Node2D
	if FileAccess.file_exists(Decor25D.chemin_json(id, DOSSIER_DECORS)) or \
			FileAccess.file_exists("%s/%s/%s.json" % [DOSSIER_DECORS, id, id]):
		var dec := Decor25D.new()
		dec.id_decor = id
		# Changement d'état (aube pendant le C7) : l'ambiant de la scène suit le décor affiché.
		dec.etat_change.connect(func(_nom, duree):
			var amb := get_node_or_null(^"Ambiance") as CanvasModulate
			if amb and dec.visible and dec.ambiant.a > 0.0:
				if duree > 0.0:
					create_tween().tween_property(amb, "color", dec.ambiant, duree)
				else:
					amb.color = dec.ambiant)
		d = dec
	else:
		d = _decor_provisoire(id)
	d.name = id.to_pascal_case()
	d.visible = false
	add_child(d)
	move_child(d, 0)
	decors[id] = d
	# « decors » du fichier jeu : calques cachés au départ (ceux qu'une mise en scène révèle).
	for nom in zones.get("decors", {}).get(id, {}).get("caches", []):
		var c := d.get_node_or_null(String(nom)) as CanvasItem
		if c:
			c.visible = false
	return d


## Décor provisoire nommé : ciel et sol d'une couleur tirée du nom, et le nom en grand. Il est
## remplacé sans rien coder quand la DA livre assets/decors/<id>/.
func _decor_provisoire(id: String) -> Node2D:
	var n := Node2D.new()
	n.set_meta("taille", TAILLE_PROVISOIRE)
	n.set_meta("provisoire", true)
	var teinte := float(hash(id) % 360) / 360.0
	var ciel := ColorRect.new()
	ciel.size = TAILLE_PROVISOIRE
	ciel.color = Color.from_hsv(teinte, 0.25, 0.32)
	ciel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_child(ciel)
	var sol := ColorRect.new()
	sol.position = Vector2(0, 780)
	sol.size = Vector2(TAILLE_PROVISOIRE.x, TAILLE_PROVISOIRE.y - 780)
	sol.color = Color.from_hsv(teinte, 0.3, 0.2)
	sol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_child(sol)
	for x in range(0, int(TAILLE_PROVISOIRE.x), 1920):
		var l := Label.new()
		l.text = "décor provisoire : %s" % id
		l.position = Vector2(x + 520, 160)
		l.add_theme_font_size_override("font_size", 56)
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		n.add_child(l)
	return n


static func taille_decor(d: Node2D) -> Vector2:
	if d is Decor25D:
		return (d as Decor25D).taille
	return d.get_meta("taille", TAILLE_PROVISOIRE)


## Plan où poser le joueur et les figurants d'un décor (créé au besoin, trié en profondeur).
func monde_de(d: Node2D) -> Node2D:
	var m := d.get_node_or_null("Monde") as Node2D
	if m == null:
		m = Node2D.new()
		m.name = "Monde"
		m.y_sort_enabled = true
		m.z_index = 10
		d.add_child(m)
	return m


## Alias de décors (data/decors_alias.json) : nom du .dlg → {decor, etat}.
static var _alias: Dictionary = {}


static func resoudre_decor(id: String) -> Dictionary:
	if _alias.is_empty():
		var a = JSON.parse_string(FileAccess.get_file_as_string("res://data/decors_alias.json")) \
			if FileAccess.file_exists("res://data/decors_alias.json") else {}
		_alias = a if typeof(a) == TYPE_DICTIONARY else {"_vide": true}
	var r = _alias.get(id)
	if typeof(r) == TYPE_DICTIONARY:
		return {"decor": r.get("decor", id), "etat": r.get("etat", "")}
	return {"decor": id, "etat": ""}


## État d'un décor à son entrée : alias (orvane_matin), sinon « decors » du fichier jeu
## ({"etat": "nuit"} ou {"etat_selon": {"drapeau": "choix_ep01_orvane", "valeurs": {"1": "a_l_heure"},
## "defaut": "en_retard"}}).
func _etat_a_l_entree(id: String, etat_alias: String) -> String:
	if not etat_alias.is_empty():
		return etat_alias
	var c = zones.get("decors", {}).get(id, {})
	if typeof(c) != TYPE_DICTIONARY:
		return ""
	if c.has("etat_selon"):
		var e: Dictionary = c.etat_selon
		var v = Jeu.etat.drapeaux.get(e.get("drapeau", ""))
		var cle := str(int(v)) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else str(v)
		return String(e.get("valeurs", {}).get(cle, e.get("defaut", "")))
	return String(c.get("etat", ""))


func _changer_decor(id_demande: String) -> void:
	var r := resoudre_decor(id_demande)
	var id: String = r.decor
	var cible := decor_par_id(id)
	var etat := _etat_a_l_entree(id, r.etat)
	if cible.visible and decor_courant == id:
		if cible is Decor25D and not etat.is_empty() and cible.etat != etat:
			cible.appliquer_etat(etat, 1.5)
		return
	await _fondu_noir(1.0, 0.35)
	for d in decors.values():
		d.visible = d == cible
	decor_courant = id
	if cible is Decor25D:
		decor = cible
		if not etat.is_empty():
			cible.appliquer_etat(etat, 0.0)
	var son_decor = zones.get("ambiances", {}).get(id)
	if typeof(son_decor) == TYPE_STRING:
		Son.ambiance(son_decor, 1.5)
	# Plans éclairés en Light2D (DA) : leur CanvasModulate très sombre ; sinon celui de la scène.
	var amb := get_node_or_null(^"Ambiance") as CanvasModulate
	if amb:
		if not amb.has_meta("defaut"):
			amb.set_meta("defaut", amb.color)
		amb.color = cible.ambiant if cible is Decor25D and cible.ambiant.a > 0.0 else amb.get_meta("defaut")
	# En ciné, les plans sont libres ; les limites de la caméra sont posées au début du jeu.
	_limiter_camera(null)
	# Nouveau lieu : la caméra repart du cadre de référence du décor (centrée, zoom 1), pas de
	# l'endroit où était le joueur ; sinon les calques en parallaxe se décalent les uns des autres.
	# Un @plan qui suit reprend la main.
	if phase != "jeu" and phase != "vers_jeu":
		camera.cible = null
		camera.en_cours = false
		camera.position = cible.global_position + taille_decor(cible) / 2.0
		camera.zoom = Vector2.ONE
	await _fondu_noir(0.0, 0.35)


func _limiter_camera(d: Node2D) -> void:
	var t := taille_decor(d) if d else Vector2.ZERO
	camera.limit_left = 0 if d else -10000000
	camera.limit_top = 0 if d else -10000000
	camera.limit_right = int(t.x) if d else 10000000
	camera.limit_bottom = int(t.y) if d else 10000000


# --------------------------------------------------------------------------- commandes

func _commande_specifique(nom: String, args: Array) -> void:
	match nom:
		"decor":
			# Un changement de décor pendant l'exploration (un point d'intérêt qui ouvre une
			# autre scène) termine l'exploration.
			if phase == "jeu":
				_quitter_jeu()
			await _changer_decor(args[0] if not args.is_empty() else decor_courant)
		"jeu":
			phase = "vers_jeu"
			_zone_demandee = args[0] if not args.is_empty() else lecteur.noeud
		"sauver_episode":
			Jeu.sauver()
		"effet":
			# Effets de mise en scène encore sans rendu (yeux voilés…) : sans effet pour l'instant.
			pass
		_:
			await super._commande_specifique(nom, args)


func _dialogue_fini() -> void:
	match phase:
		"vers_jeu":
			_commencer_jeu(_zone_demandee)
		"jeu":
			joueur.actif = true
		_:
			_finir()


# --------------------------------------------------------------------------- exploration

## Configuration d'une zone (surchargeable : une scène peut fournir ses zones par défaut).
func config_zone(nom: String) -> Dictionary:
	return zones.get(nom, {})


func _commencer_jeu(nom: String) -> void:
	zone = nom
	config = config_zone(nom)
	if config.is_empty():
		push_warning("Zone de jeu « %s » sans configuration (fichier jeu du chapitre)" % nom)
	await _changer_decor(config.get("decor", decor_courant if not decor_courant.is_empty() else "provisoire"))
	var d := decor_par_id(decor_courant)
	_placer_joueur(d)
	pois = {}
	for k in config.get("pois", {}):
		# « conditions » : {"poi_ilse": "vivant_ilse"} : le point (et son figurant) n'existe que
		# si le drapeau est vrai.
		var si = config.get("conditions", {}).get(k)
		if typeof(si) == TYPE_STRING and not Jeu.etat.drapeaux.get(si, false):
			continue
		var p: Array = config.pois[k]
		pois[k] = Vector2(p[0], p[1])
	for k in config.get("figurants", {}):
		if pois.has(k) and not props.has(config.figurants[k]):
			_prop(monde_de(d), config.figurants[k], pois[k] + Vector2(0, -10))
	_declenches = {}
	_vus_depuis = {}
	temps_jeu = 0.0
	inactif = 0.0
	relance_faite = false
	phase = "jeu"
	camera.cible = joueur
	camera.suivi_zoom = 1.0
	camera.caler_sur_cible()
	_limiter_camera(d)
	joueur.actif = true


func _placer_joueur(d: Node2D) -> void:
	var m := monde_de(d)
	if joueur.get_parent() != m:
		if joueur.get_parent():
			joueur.reparent(m, false)
		else:
			m.add_child(joueur)
	var p: Array = config.get("depart", [DEPART_DEFAUT.x, DEPART_DEFAUT.y])
	joueur.position = Vector2(p[0], p[1])
	var l: Array = config.get("limites", [])
	joueur.limites = Rect2(l[0], l[1], l[2], l[3]) if l.size() == 4 else ZONE_MARCHE_DEFAUT
	var perso: String = config.get("personnage", "vaskar")
	if joueur.sprite.name != perso:
		joueur.sprite.queue_free()
		joueur.sprite = _sprite(perso)
		joueur.add_child(joueur.sprite)
	joueur.sprite.scale = Vector2.ONE * float(config.get("echelle", 1.0))
	joueur.visible = true


func _quitter_jeu() -> void:
	phase = "cine"
	# Les limites ne bornent que l'affichage : on reprend le centre réellement montré, sinon la
	# caméra saute hors du décor (bord visible) dès que les limites sont levées.
	camera.position = camera.get_screen_center_position()
	joueur.actif = false
	_invite.hide()
	camera.cible = null


func _process(delta: float) -> void:
	if phase == "jeu":
		_jeu(delta)


## Une image d'exploration : invite de déplacement, inactivité et relance, déclencheurs,
## points d'intérêt.
func _jeu(delta: float) -> void:
	temps_jeu += delta
	_suivre_inactivite(delta)
	if _suivre_declencheurs():
		return
	_interagir_pois()


func _suivre_inactivite(delta: float) -> void:
	_suivre_aide_deplacement()
	if joueur.en_mouvement or boite.visible:
		inactif = 0.0
	else:
		inactif += delta
	var r: Dictionary = config.get("relance", {})
	if not relance_faite and not r.is_empty() and inactif >= float(r.get("s", 30.0)):
		relance_faite = true
		inactif = 0.0
		jouer_vox(r.noeud)


func obligatoires_vus(liste: Array = config.get("obligatoires", [])) -> bool:
	return liste.all(func(p): return pois_vus.has(p))


func _suivre_declencheurs() -> bool:
	if boite.visible:
		return false
	var liste: Array = config.get("declencheurs", [])
	for i in liste.size():
		var d: Dictionary = liste[i]
		if _declenches.has(i) or not obligatoires_vus(d.get("apres", [])):
			continue
		if not _vus_depuis.has(i):
			_vus_depuis[i] = temps_jeu
		var par_temps: bool = d.has("max_s") and temps_jeu - _vus_depuis[i] >= float(d.max_s)
		if joueur.position.x >= float(d.get("x", INF)) or par_temps:
			_declenches[i] = true
			_quitter_jeu()
			jouer_noeud(d.noeud)
			return true
	return false


func _interagir_pois() -> void:
	var poi := poi_proche()
	if poi.is_empty() or boite.visible:
		_invite.hide()
		return
	_inviter(pois[poi], "%s : regarder" % touche("interagir"))
	if Input.is_action_just_pressed("interagir"):
		_invite.hide()
		joueur.actif = false
		pois_vus[poi] = true
		inactif = 0.0
		jouer_noeud(poi)


## Un point d'intérêt peut-il être lu ? (Surchargeable : un personnage qui a quitté la scène.)
func poi_disponible(nom: String) -> bool:
	return not pois_vus.has(nom) or config.get("relisibles", false)


func poi_proche() -> String:
	var meilleur := ""
	var d_min := POI_DISTANCE
	for nom in pois:
		if not poi_disponible(nom):
			continue
		var d := joueur.distance_sol(pois[nom])
		if d < d_min:
			d_min = d
			meilleur = nom
	return meilleur


## L'icône des touches apparaît si le joueur n'a pas bougé AIDE_DEPLACEMENT_S après la prise
## en main, et disparaît au premier mouvement pour ne plus revenir.
func _suivre_aide_deplacement() -> void:
	if _a_bouge:
		return
	if joueur.en_mouvement:
		_a_bouge = true
		if _aide.visible:
			var t := create_tween()
			t.tween_property(_aide, "modulate:a", 0.0, 0.4)
			t.tween_callback(_aide.hide)
	elif not aide_vue and temps_jeu >= AIDE_DEPLACEMENT_S and not boite.visible:
		aide_vue = true
		_aide.show()
		create_tween().tween_property(_aide, "modulate:a", 1.0, 0.6)


# --------------------------------------------------------------------------- écran de fin

## Fin du chapitre. En fin d'épisode : noir franc, puis l'écran de fin (plus de rebouclage).
## La partie est sauvegardée et l'épisode marqué terminé avant l'affichage.
func _finir() -> void:
	if phase == "ecran_fin":
		return
	var suivant := Jeu.clore_chapitre()
	if not suivant.is_empty() and suivant.episode == Jeu.etat.episode:
		Jeu.aller_au_chapitre(suivant.episode, suivant.chapitre)
		Jeu.sauver()
		return
	phase = "ecran_fin"
	joueur.actif = false
	Son.musique("stop", 1.5)
	Son.couper("ambiance", 2.5)
	# Le dernier carton est resté noir : on passe sous le voile sans revoir la scène.
	if is_instance_valid(carton_final):
		_voile_noir.modulate.a = 1.0
	await _fondu_noir(1.0, 0.6)
	liberer_carton_final()
	ecran_fin = _construire_ecran_fin(titre_fin(), rappel_fin())
	_ui.add_child(ecran_fin)
	ecran_fin.modulate.a = 0.0
	create_tween().tween_property(ecran_fin, "modulate:a", 1.0, 0.8)
	# Aucun bouton en focus, et rien n'est pris pendant ECRAN_FIN_VERROU_S : un Espace donné
	# par réflexe à la fin du dialogue ne relance pas la partie (décision GD, QA v2).
	get_viewport().gui_release_focus()
	_ecran_fin_ouvert_a = Time.get_ticks_msec()
	for b in ecran_fin.find_children("*", "Button", true, false):
		b.disabled = true
	get_tree().create_timer(ECRAN_FIN_VERROU_S, true, false, true).timeout.connect(func():
		if is_instance_valid(ecran_fin):
			for b in ecran_fin.find_children("*", "Button", true, false):
				b.disabled = false)


const ECRAN_FIN_VERROU_S := 1.0
var _ecran_fin_ouvert_a := 0


## Écran de fin sans focus : la première direction (clavier ou manette) sélectionne Rejouer.
func _unhandled_input(e: InputEvent) -> void:
	if phase != "ecran_fin" or ecran_fin == null or get_viewport().gui_get_focus_owner() != null:
		return
	if Time.get_ticks_msec() - _ecran_fin_ouvert_a < ECRAN_FIN_VERROU_S * 1000.0:
		return
	for a in ["ui_up", "ui_down", "ui_left", "ui_right", "haut", "bas", "gauche", "droite"]:
		if InputMap.has_action(a) and e.is_action_pressed(a):
			(ecran_fin.find_child("Rejouer", true, false) as Button).grab_focus()
			get_viewport().set_input_as_handled()
			return


## Titre et ligne de rappel de l'écran de fin (surchargeables par épisode).
func titre_fin() -> String:
	return Catalogue.episode(Jeu.etat.episode).get("titre", "")


func rappel_fin() -> String:
	return ""


func _construire_ecran_fin(titre: String, rappel: String) -> Control:
	var centre := CenterContainer.new()
	centre.name = "EcranFin"
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	centre.add_child(vb)
	var l_titre := Label.new()
	l_titre.text = titre
	l_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_titre.add_theme_font_size_override("font_size", 84)
	l_titre.add_theme_color_override("font_color", Color("#F2EAD3"))
	vb.add_child(l_titre)
	var ligne := Label.new()
	ligne.name = "Rappel"
	ligne.text = rappel
	ligne.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ligne.add_theme_font_size_override("font_size", 30)
	ligne.add_theme_color_override("font_color", Color("#C9A44C"))
	vb.add_child(ligne)
	var espace := Control.new()
	espace.custom_minimum_size.y = 40
	vb.add_child(espace)
	for d in [["Rejouer", func(): Jeu.nouvelle_partie(Jeu.etat.episode)], ["Quitter", func(): get_tree().quit()]]:
		var b := Button.new()
		b.name = d[0]
		b.text = d[0]
		b.custom_minimum_size = Vector2(320, 0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", 30)
		b.pressed.connect(d[1])
		vb.add_child(b)
	return centre


# --------------------------------------------------------------------------- vox

## Affiche les répliques d'un nœud en surimpression, sans arrêter le jeu.
func jouer_vox(noeud: String) -> void:
	var l := LecteurDialogue.new(lecteur.dialogue, Jeu.etat.drapeaux)
	l.demarrer(noeud)
	var e := l.avancer()
	while e.type == "replique":
		var nom := BoiteDialogue.nom_affiche(e)
		_vox_file.append(("%s : %s" % [nom, e.texte]) if not nom.is_empty() else e.texte)
		e = l.avancer()
	if not _vox_actif:
		_vox_suivant()


func _vox_suivant() -> void:
	if _vox_file.is_empty():
		_vox_actif = false
		_vox.hide()
		return
	_vox_actif = true
	var texte: String = _vox_file.pop_front()
	if texte.contains("(vox)"):
		Son.bruitage("vox_crepite")
	_vox.text = texte
	_vox.show()
	await get_tree().create_timer(maxf(2.5, texte.length() * 0.06)).timeout
	_vox_suivant()
