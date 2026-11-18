extends Chapitre
## Tranche verticale : Ullanor, après le Triomphe (2 min 30).
##
## Déroulé (game-design-tv.md v0.2, script-tv.md v0.3) :
##   1. ciné d'ouverture (nœud « ouverture » du .dlg, décor de la DA)       phase « cine »
##   2. le champ après la fête : déplacement, 3 points d'intérêt,           phase « jeu »
##      invite de déplacement si le joueur ne bouge pas (AIDE_DEPLACEMENT_S),
##      relance vox de Dremm après RELANCE_VOX_S d'inactivité
##   3. l'éboulement, derrière Vaskar quand il passe le poste d'Ilse         phase « eboulement »
##      (EBOULEMENT_X). Filet : après la relance, GLISSEMENT_S de plus sans
##      bouger et la caméra glisse jusqu'au poste ; l'éboulement se joue
##      toujours à l'écran. Puis « … ici » et le rappel de Dremm
##      la QTE : près de la poutre, maintenir « interagir » pour soulever   phase « libre »
##   4. le choix minuté (8 s, silence = obéir)                              phase « choix »
##      Rejoindre le rassemblement sans s'arrêter, ou ne rien faire pendant
##      SILENCE_S, vaut aussi « obéir ».
##   5. ciné de fin et ses variantes (nœuds « fin… » du .dlg)               phase « fin »
##   6. écran de fin : le choix fait, Rejouer, Quitter                       phase « ecran_fin »
##
## Commandes propres à la tranche (en plus de celles de Chapitre) :
##   @decor ullanor|bivouac    change de décor (fondu enchaîné court)
##   @jeu                      la ciné d'ouverture rend la main au joueur
##   @action sortir|auxiliaires|obeir   ce que fait Vaskar après le choix
##   @hochement                Dremm hoche la tête une fois (5a, auxiliaires et obéi)
##
## Personnages et objets : placeholders (tools/placeholders/generer_tranche_ullanor.py),
## remplacés au même nom par la chaîne d'images.

const PROPS := "res://assets/tranche_ullanor/props/"

const DEPART := Vector2(300, 900)
const ZONE_MARCHE := Rect2(100, 800, 3640, 200)
## Points d'intérêt : nœud du dialogue → position au sol.
const POI := {
	"poi_etendard": Vector2(950, 870),
	"poi_freres": Vector2(1640, 860),
	"poi_ilse": Vector2(2470, 905),
}
const POI_DISTANCE := 160.0
const POSTE := Vector2(2700, 835)
const POUTRE := Vector2(2700, 912)
## L'éboulement se produit derrière Vaskar, quand il a dépassé le poste.
const EBOULEMENT_X := 2980.0
const RASSEMBLEMENT_X := 3560.0
## Inactivité (s, sans bouger ni lire) avant la relance vox de Dremm, puis avant que la
## caméra n'aille montrer l'éboulement.
const RELANCE_VOX_S := 30.0
const GLISSEMENT_S := 30.0
## Sans mouvement après la prise en main, l'icône des touches apparaît (une seule fois).
const AIDE_DEPLACEMENT_S := 4.0
## Ce que l'écran de fin rappelle, selon choix_ullanor (texte provisoire, à valider par le GD).
const RAPPEL_CHOIX := {
	1: "Vous avez sorti la soldate des décombres.",
	2: "Vous avez appelé des auxiliaires.",
	3: "Vous avez obéi.",
}
const SILENCE_S := 20.0
const QTE_DISTANCE := 190.0
## Temps de maintien pour lever la poutre (s).
const QTE_DUREE := 1.4

@export var ullanor: Decor25D
@export var bivouac: Decor25D

var phase := "cine"
var joueur: PersonnageJoue
var temps_jeu := 0.0
var temps_libre := 0.0
## Secondes passées sans bouger ni lire (remis à zéro à chaque mouvement).
var inactif := 0.0
var relance_faite := false
## La caméra est allée montrer l'éboulement au joueur resté immobile.
var glissement_fait := false
var aide_vue := false
var _a_bouge := false
var _aide: Control
var ecran_fin: Control
var qte := 0.0
var pois_vus := {}
var choix_fait := ""
var props := {}
var _invite: Label
var _vox: Label
var _jauge: ProgressBar
var _voile_noir: ColorRect
var _vox_file: Array[String] = []
var _vox_actif := false
## Grincement de la poutre pendant la QTE et le choix (volume et hauteur suivent qte).
var _grincement: AudioStreamPlayer


func _ready() -> void:
	decor = ullanor
	_construire_ui()
	_construire_bivouac()
	_attacher_figurants_cine()
	bivouac.visible = false
	super._ready()
	# Le battement sourd du choix minuté, qui accélère avec le trait de temps (tic en attendant
	# le fichier du Sound Designer).
	boite.battement.connect(func(intensite: float):
		Son.bruitage("choix_battement" if Son.existe("sfx_choix_battement") or Son.existe("sfx_choix_battement_01") \
			else "choix_tic",
			lerpf(-8.0, 0.0, intensite)))


# --------------------------------------------------------------------------- construction

func _construire_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UIJeu"
	ui.layer = 10
	add_child(ui)
	_vox = Label.new()
	_vox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_vox.offset_top = 60
	_vox.offset_bottom = 140
	_vox.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vox.add_theme_font_size_override("font_size", 30)
	_vox.add_theme_color_override("font_outline_color", Color.BLACK)
	_vox.add_theme_constant_override("outline_size", 8)
	ui.add_child(_vox)
	_jauge = ProgressBar.new()
	_jauge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_jauge.offset_left = -200
	_jauge.offset_right = 200
	_jauge.offset_top = -140
	_jauge.offset_bottom = -122
	_jauge.show_percentage = false
	_jauge.hide()
	ui.add_child(_jauge)
	_aide = _construire_aide_deplacement()
	ui.add_child(_aide)
	_voile_noir = ColorRect.new()
	_voile_noir.color = Color.BLACK
	_voile_noir.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile_noir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voile_noir.modulate.a = 0.0
	ui.add_child(_voile_noir)


## Icône discrète des touches de déplacement, en bas de l'écran. Les lettres sont celles du
## clavier du joueur (ZQSD en AZERTY, WASD en QWERTY).
func _construire_aide_deplacement() -> Control:
	var touches := ""
	for code in [KEY_W, KEY_A, KEY_S, KEY_D]:
		var k := KEY_NONE
		if DisplayServer.get_name() != "headless":
			k = DisplayServer.keyboard_get_label_from_physical(code)
		touches += OS.get_keycode_string(k if k != KEY_NONE else code)
	var l := Label.new()
	l.name = "AideDeplacement"
	l.text = "%s  ·  ← ↑ → ↓  ·  stick gauche" % touches
	l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	l.offset_left = -300
	l.offset_right = 300
	l.offset_top = -90
	l.offset_bottom = -50
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.modulate.a = 0.0
	l.hide()
	return l


func _construire_bivouac() -> void:
	var monde := Node2D.new()
	monde.name = "Monde"
	monde.y_sort_enabled = true
	monde.z_index = 10
	bivouac.add_child(monde)
	_prop(monde, "totem", POI.poi_etendard + Vector2(0, -10))
	_prop(monde, "rhino", Vector2(1740, 830))
	_prop(monde, "frere_1", Vector2(1580, 850))
	_prop(monde, "frere_2", Vector2(1660, 846)).flip_h = true
	_prop(monde, "poste", POSTE + Vector2(-60, 0))
	_prop(monde, "carcasse", POSTE + Vector2(90, 0))
	_prop(monde, "ilse", POI.poi_ilse)
	_prop(monde, "poutre", POUTRE).visible = false
	_prop(monde, "ilse_main", POUTRE + Vector2(-150, 2)).visible = false
	_prop(monde, "banniere_27e", Vector2(RASSEMBLEMENT_X + 60, 840))
	joueur = PersonnageJoue.new()
	joueur.name = "Vaskar"
	joueur.position = DEPART
	joueur.limites = ZONE_MARCHE
	joueur.sprite = _sprite("vaskar")
	joueur.add_child(joueur.sprite)
	monde.add_child(joueur)
	_invite = Label.new()
	_invite.add_theme_font_size_override("font_size", 26)
	_invite.add_theme_color_override("font_outline_color", Color.BLACK)
	_invite.add_theme_constant_override("outline_size", 8)
	_invite.z_index = 100
	_invite.hide()
	bivouac.add_child(_invite)
	var soleil := _lumiere(Vector2(3300, 520), Color("#FFE8B0"), 10.0)
	soleil.name = "CleBivouac"
	bivouac.add_child(soleil)


## Silhouettes et objets des cinés, posés DANS le calque de leur plan de profondeur pour
## suivre sa parallaxe (coordonnées du décor de la DA).
func _attacher_figurants_cine() -> void:
	var fond := ullanor.get_node("Calque_10_fond")
	var empereur := _sprite("empereur", false)
	empereur.name = "Empereur"
	empereur.position = Vector2(906, 356)
	empereur.scale = Vector2(1, 0.3)
	fond.add_child(empereur)
	var horus := _sprite("horus_silhouette", false)
	horus.name = "HorusSilhouette"
	horus.position = Vector2(928, 362)
	horus.scale = Vector2(1, 0.55)
	fond.add_child(horus)
	var voie := ullanor.get_node("Calque_30_voie")
	for d in [["PoutreSeule", "poutre", 0.12], ["Civiere", "civiere", 0.3], ["IlsePlaque", "ilse_plaque", 0.45]]:
		var s := _sprite(d[1], false)
		s.name = d[0]
		s.position = Vector2(1180, 722)
		s.scale = Vector2.ONE * d[2]
		s.visible = false
		voie.add_child(s)
	var cle: Dictionary = Decor25D.lire(ullanor.id_decor).get("cle", {})
	if cle.has("position_px"):
		var l := _lumiere(Vector2(cle.position_px[0], cle.position_px[1]), Color(cle.get("couleur", "#FFE8B0")), 8.0)
		l.name = "CleUllanor"
		ullanor.add_child(l)


func _sprite(nom: String, normales := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = nom
	var tex := CanvasTexture.new()
	tex.diffuse_texture = load(PROPS + nom + ".png")
	if normales and ResourceLoader.exists(PROPS + nom + "_normal.png"):
		tex.normal_texture = load(PROPS + nom + "_normal.png")
	s.texture = tex
	# Origine aux pieds : le tri en profondeur (y_sort) se fait sur la ligne du sol.
	s.offset = Vector2(0, -tex.diffuse_texture.get_height() / 2.0)
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


# --------------------------------------------------------------------------- commandes

func _commande_specifique(nom: String, args: Array) -> void:
	match nom:
		"decor":
			await _changer_decor(args[0] if not args.is_empty() else "ullanor")
		"jeu":
			phase = "vers_jeu"
		"action":
			await _action(args[0] if not args.is_empty() else "obeir")
		"hochement":
			await _hochement()
		_:
			await super._commande_specifique(nom, args)


func _changer_decor(nom: String) -> void:
	if ullanor.visible == (nom == "ullanor") and bivouac.visible == (nom == "bivouac"):
		return
	await _fondu_noir(1.0, 0.35)
	ullanor.visible = nom == "ullanor"
	bivouac.visible = nom == "bivouac"
	# En jeu, la caméra ne sort pas du décor ; en ciné, les plans sont libres.
	var d: Decor25D = bivouac if nom == "bivouac" else null
	camera.limit_left = 0 if d else -10000000
	camera.limit_top = 0 if d else -10000000
	camera.limit_right = int(d.taille.x) if d else 10000000
	camera.limit_bottom = int(d.taille.y) if d else 10000000
	await _fondu_noir(0.0, 0.35)


func _fondu_noir(opacite: float, duree: float) -> void:
	var t := create_tween()
	t.tween_property(_voile_noir, "modulate:a", opacite, duree)
	await t.finished


func _dialogue_fini() -> void:
	match phase:
		"vers_jeu":
			_commencer_jeu()
		"jeu", "libre":
			joueur.actif = true
		"fin":
			_finir()


func _commencer_jeu() -> void:
	Son.ambiance("ullanor_bivouac", 2.0)
	Son.musique("stop", 6.0)
	await _changer_decor("bivouac")
	phase = "jeu"
	camera.cible = joueur
	camera.suivi_zoom = 1.0
	camera.caler_sur_cible()
	joueur.actif = true


# --------------------------------------------------------------------------- jeu

func _process(delta: float) -> void:
	match phase:
		"jeu":
			_jeu(delta)
		"libre":
			_libre(delta)
		"choix":
			_trembler_poutre()


func _jeu(delta: float) -> void:
	temps_jeu += delta
	_suivre_aide_deplacement()
	if joueur.en_mouvement or boite.visible:
		inactif = 0.0
	else:
		inactif += delta
	if not relance_faite and inactif >= RELANCE_VOX_S:
		relance_faite = true
		inactif = 0.0
		jouer_vox("vox_relance")
	elif relance_faite and inactif >= GLISSEMENT_S:
		_montrer_eboulement()
		return
	if not boite.visible and joueur.position.x >= EBOULEMENT_X:
		_eboulement()
		return
	var poi := poi_proche()
	if poi.is_empty() or boite.visible:
		_invite.hide()
		return
	_inviter(POI[poi], "E : regarder")
	if Input.is_action_just_pressed("interagir"):
		_invite.hide()
		joueur.actif = false
		pois_vus[poi] = true
		jouer_noeud(poi)


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
		create_tween().tween_property(_aide, "modulate:a", 0.85, 0.6)


## Filet de sécurité : le joueur n'a pas bougé depuis la relance. La caméra glisse doucement
## jusqu'au poste d'Ilse, et l'éboulement se joue sous ses yeux.
func _montrer_eboulement() -> void:
	phase = "eboulement"
	glissement_fait = true
	joueur.actif = false
	_invite.hide()
	camera.cible = null
	camera.jouer([{"position": [POSTE.x + 120, camera.position.y], "zoom": 1.0, "duree": 3.5, "courbe": "douce"}])
	await camera.sequence_terminee
	_eboulement()


func poi_proche() -> String:
	var meilleur := ""
	var d_min := POI_DISTANCE
	for nom in POI:
		# Ilse n'est plus sur sa caisse après l'éboulement.
		if nom == "poi_ilse" and phase != "jeu":
			continue
		var d := joueur.distance_sol(POI[nom])
		if d < d_min:
			d_min = d
			meilleur = nom
	return meilleur


func _inviter(pos: Vector2, texte: String) -> void:
	_invite.text = texte
	_invite.position = pos + Vector2(-90, -300)
	_invite.show()


func _eboulement() -> void:
	phase = "eboulement"
	_invite.hide()
	_aide.hide()
	Son.bruitage("eboulement")
	var carcasse: Sprite2D = props.carcasse
	var t := create_tween().set_parallel()
	t.tween_property(carcasse, "rotation", -0.35, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(carcasse, "position", carcasse.position + Vector2(-90, 30), 0.9)
	camera.jouer([{"position": [camera.position.x, camera.position.y], "zoom": camera.zoom.x, "duree": 1.4,
		"courbe": "lineaire", "tremblement": 18}])
	_poussiere(POSTE + Vector2(0, -40))
	props.ilse.visible = false
	await get_tree().create_timer(4.0).timeout
	props.poutre.visible = true
	props.ilse_main.visible = true
	jouer_vox("vox_eboulement")
	await get_tree().create_timer(3.0).timeout
	jouer_vox("vox_rappel")
	await get_tree().create_timer(3.0).timeout
	# Après le plan de l'éboulement, la caméra revient doucement sur Vaskar.
	camera.cible = joueur
	joueur.actif = true
	phase = "libre"
	_grincement = Son.boucle_bruitage("poutre_grince")


func _poussiere(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = 80
	p.lifetime = 3.0
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 220.0
	p.gravity = Vector2(0, 30)
	p.scale_amount_min = 8.0
	p.scale_amount_max = 22.0
	p.color = Color(0.6, 0.5, 0.4, 0.55)
	p.z_index = 50
	bivouac.get_node("Monde").add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _libre(delta: float) -> void:
	temps_libre += delta
	var proche := joueur.distance_sol(POUTRE) < QTE_DISTANCE
	if proche:
		_inviter(POUTRE, "Maintenir E : soulever")
		_jauge.show()
		if Input.is_action_pressed("interagir"):
			qte = minf(1.0, qte + delta / QTE_DUREE)
		else:
			qte = maxf(0.0, qte - delta)
	else:
		_invite.hide()
		_jauge.hide()
		qte = maxf(0.0, qte - delta)
	_jauge.value = qte * 100.0
	_trembler_poutre()
	if qte >= 1.0:
		_lancer_choix()
	elif joueur.position.x >= RASSEMBLEMENT_X:
		_decider("obeir")
	elif temps_libre >= SILENCE_S and qte <= 0.0:
		# Le joueur ne fait rien : le silence vaut « obéir ».
		_decider("obeir")


## La poutre monte de quelques centimètres et tremble pendant qu'on la tient.
func _trembler_poutre() -> void:
	var poutre: Sprite2D = props.poutre
	var ampli := 2.5 * qte
	poutre.position = POUTRE + Vector2(randf_range(-ampli, ampli), -14.0 * qte + randf_range(-ampli, ampli))
	if _grincement:
		_grincement.volume_db = linear_to_db(maxf(qte, 0.001))
		_grincement.pitch_scale = 0.9 + 0.25 * qte


func _lancer_choix() -> void:
	phase = "choix"
	joueur.actif = false
	_invite.hide()
	_jauge.hide()
	jouer_noeud("choix")


func _decider(noeud: String) -> void:
	phase = "choix"
	joueur.actif = false
	_invite.hide()
	_jauge.hide()
	jouer_noeud(noeud)


## Ce que fait Vaskar après le choix (script-tv.md, §4).
func _action(type: String) -> void:
	phase = "fin"
	choix_fait = type
	if _grincement:
		create_tween().tween_property(_grincement, "volume_db", Son.SILENCE_DB, 0.3)
		get_tree().create_timer(0.35).timeout.connect(_grincement.queue_free)
		_grincement = null
	_jauge.hide()
	_invite.hide()
	var poutre: Sprite2D = props.poutre
	# Vaskar reste dans le décor (et dans le cadre) : il s'arrête à la bannière de la 27e.
	var arrivee := minf(joueur.position.x + 450.0, RASSEMBLEMENT_X + 40.0)
	var t := create_tween()
	match type:
		"sortir":
			# Il soulève la poutre jusqu'au bout et tire Ilse de dessous.
			t.tween_property(poutre, "position", POUTRE + Vector2(0, -80), 0.7)
			t.tween_callback(func(): props.ilse_main.visible = false)
			t.tween_property(joueur, "modulate", Color("#b3a189"), 0.6)
			t.tween_interval(1.0)
		"auxiliaires":
			# Il lâche un signal sur le vox de l'Armée, pose la poutre sur une caisse et repart.
			t.tween_property(poutre, "position", POUTRE + Vector2(0, -30), 0.4)
			t.tween_callback(func(): joueur.sprite.flip_h = false)
			t.tween_property(joueur, "position:x", arrivee, 1.8)
		_:
			# Il lâche la poutre et se retourne vers la voie.
			t.tween_property(poutre, "position", POUTRE, 0.15)
			t.tween_callback(func(): joueur.sprite.flip_h = false)
			t.tween_property(joueur, "position:x", arrivee, 1.8)
	await t.finished


## Dremm hoche la tête une fois : la tête est détachée de son calque (Decor25D.detacher_tete)
## et pivote au cou, puis revient.
var _tete_dremm: Sprite2D

func _hochement() -> void:
	if _tete_dremm == null:
		_tete_dremm = ullanor.detacher_tete("Calque_48_dremm")
	if _tete_dremm == null:
		push_warning("Hochement : tête de Dremm introuvable dans son calque")
		return
	var depart := _tete_dremm.position
	var t := create_tween()
	var angle := minf(0.09, float(_tete_dremm.get_meta("rotation_max", 0.26)))
	t.tween_property(_tete_dremm, "rotation", angle, 0.28).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_tete_dremm, "position", depart + Vector2(0, 4), 0.28)
	t.tween_property(_tete_dremm, "rotation", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_tete_dremm, "position", depart, 0.35)
	await t.finished


# --------------------------------------------------------------------------- écran de fin

## Fin de la tranche : noir franc après l'écho, puis l'écran de fin (plus de rebouclage sur
## l'ouverture). La partie est sauvegardée et l'épisode marqué terminé avant l'affichage.
func _finir() -> void:
	if phase == "ecran_fin":
		return
	var suivant := Jeu.clore_chapitre()
	if not suivant.is_empty():
		Jeu.aller_au_chapitre(suivant.episode, suivant.chapitre)
		Jeu.sauver()
		return
	phase = "ecran_fin"
	Son.musique("stop", 1.5)
	Son.couper("ambiance", 2.5)
	await _fondu_noir(1.0, 0.6)
	ecran_fin = _construire_ecran_fin(RAPPEL_CHOIX.get(int(Jeu.drapeau("choix_ullanor", 3)), ""))
	$UIJeu.add_child(ecran_fin)
	ecran_fin.modulate.a = 0.0
	create_tween().tween_property(ecran_fin, "modulate:a", 1.0, 0.8)
	(ecran_fin.find_child("Rejouer", true, false) as Button).grab_focus.call_deferred()


func _construire_ecran_fin(rappel: String) -> Control:
	var centre := CenterContainer.new()
	centre.name = "EcranFin"
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	centre.add_child(vb)
	var titre := Label.new()
	titre.text = "Ullanor"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 84)
	titre.add_theme_color_override("font_color", Color("#F2EAD3"))
	vb.add_child(titre)
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
