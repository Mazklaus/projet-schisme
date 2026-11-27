extends ChapitreJouable
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
## Décors, exploration, vox, invite de déplacement et écran de fin : ChapitreJouable. La zone
## « ouverture » (le champ après la fête) a ses réglages par défaut ici ; un chapitre qui
## réutilise la scène (épisode 1, chapitre 1) les complète dans son fichier « jeu » : points
## d'intérêt en plus, « obligatoires » avant l'éboulement, « relance », « eboulement_max_s »
## (secondes après les obligatoires), « disparait_apres » (figurants qui quittent la scène).
## Champ « suite » du chapitre : nœud joué après la ciné de fin au lieu de finir le chapitre.
##
## Commandes propres à la tranche (en plus de celles de ChapitreJouable) :
##   @action sortir|auxiliaires|obeir   ce que fait Vaskar après le choix
##   @hochement                Dremm hoche la tête une fois (5a, auxiliaires et obéi)
##
## Personnages et objets : placeholders (tools/placeholders/generer_tranche_ullanor.py),
## remplacés au même nom par la chaîne d'images.

## Zone d'exploration de la tranche : celle du nœud « ouverture » qui appelle @jeu.
const ZONE_CAMPEMENT := "ouverture"

const DEPART := Vector2(300, 900)
const ZONE_MARCHE := Rect2(100, 800, 3640, 200)
## Points d'intérêt : nœud du dialogue → position au sol.
const POI := {
	"poi_etendard": Vector2(950, 870),
	"poi_freres": Vector2(1640, 860),
	"poi_ilse": Vector2(2470, 905),
}
const POSTE := Vector2(2700, 835)
const POUTRE := Vector2(2700, 912)
## L'éboulement se produit derrière Vaskar, quand il a dépassé le poste.
const EBOULEMENT_X := 2980.0
const RASSEMBLEMENT_X := 3560.0
## Inactivité (s, sans bouger ni lire) avant la relance vox de Dremm, puis avant que la
## caméra n'aille montrer l'éboulement.
const RELANCE_VOX_S := 30.0
const GLISSEMENT_S := 30.0
## Ce que l'écran de fin rappelle, selon choix_ep01_ullanor (textes du GD, 27/11).
const RAPPEL_CHOIX := {
	1: "Vaskar Hol a tiré Ilse Varga des décombres.",
	2: "Vaskar Hol a appelé des auxiliaires et rejoint les rangs.",
	3: "Vaskar Hol a rejoint les rangs sans se retourner.",
}
const SILENCE_S := 20.0
const QTE_DISTANCE := 190.0
## Temps de maintien pour lever la poutre (s).
const QTE_DUREE := 1.4
@export var ullanor: Decor25D
@export var bivouac: Decor25D

var temps_libre := 0.0
## La caméra est allée montrer l'éboulement au joueur resté immobile.
var glissement_fait := false
var qte := 0.0
var choix_fait := ""
var _jauge: ProgressBar
## Grincement de la poutre pendant la QTE et le choix (volume et hauteur suivent qte).
var _grincement: AudioStreamPlayer
## Temps de jeu où les points obligatoires ont tous été vus (-1 : pas encore).
var _obligatoires_depuis := -1.0


func _ready() -> void:
	decor = ullanor
	_construire_bivouac()
	_attacher_figurants_cine()
	bivouac.visible = false
	super._ready()
	joueur.name = "Vaskar"
	_jauge = ProgressBar.new()
	_jauge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_jauge.offset_left = -200
	_jauge.offset_right = 200
	_jauge.offset_top = -140
	_jauge.offset_bottom = -122
	_jauge.show_percentage = false
	_jauge.hide()
	_ui.add_child(_jauge)
	# Le battement sourd du choix minuté, qui accélère avec le trait de temps (tic en attendant
	# le fichier du Sound Designer).
	boite.battement.connect(func(intensite: float):
		Son.bruitage("choix_battement" if Son.existe("sfx_choix_battement") or Son.existe("sfx_choix_battement_01") \
			else "choix_tic",
			lerpf(-8.0, 0.0, intensite)))


# --------------------------------------------------------------------------- construction

func _construire_bivouac() -> void:
	var monde := monde_de(bivouac)
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
	# IlsePlaque : même hauteur à l'écran que l'ancienne image (70 px × 0,45) avec la v2 de CA1 (340 px).
	for d in [["PoutreSeule", "poutre", 0.12], ["Civiere", "civiere", 0.3], ["IlsePlaque", "ilse_plaque", 0.093]]:
		var s := _sprite(d[1], false)
		s.name = d[0]
		s.position = Vector2(1180, 722)
		s.scale = Vector2.ONE * d[2]
		s.visible = false
		voie.add_child(s)
	# Plus de lumière de clé ajoutée : la lumière d'Ullanor est peinte (retour DA), le halo et
	# les rais viennent de la passe PostSoleil.
	_monter_gros_plan_horus()


## Gros plan 5b (validé GD) : couleur _fin, une seule carte de normales (armure et cou de TP2,
## tête de CA1) et une seule Light2D pour tout le buste, sinon le visage se décolle. L'orgueil
## (menton levé, déjà peint) passe en fondu sur le neutre.
const HORUS_5B := "res://assets/personnages/horus_5b/horus_5b_%s_large%s.png"


func _monter_gros_plan_horus() -> void:
	var couche := get_node_or_null(^"GrosPlanHorus") as CanvasLayer
	if couche == null or not ResourceLoader.exists(HORUS_5B % ["neutre", ""]):
		return
	# Compensation du CanvasModulate propre à la couche, pour ce qui ne doit pas être assombri.
	var neutre_amb := Color(1.0 / AMB_GROS_PLAN.r, 1.0 / AMB_GROS_PLAN.g, 1.0 / AMB_GROS_PLAN.b)
	# Fond : le vrai décor d'Ullanor au crépuscule, peint par CA2 pour ce plan (ciel, citadelle
	# dans le voile, arrière du dais), déjà voilé et flou comme une faible profondeur de champ.
	var fond := couche.get_node(^"Image") as Sprite2D
	fond.name = "Fond"
	fond.position = Vector2(960, 540)
	fond.scale = Vector2.ONE
	var ordre := 0
	for calque in FOND_GROS_PLAN:
		var sp := fond if ordre == 0 else Sprite2D.new()
		sp.texture = load(DOSSIER_FOND_GROS_PLAN.path_join(calque[0] + ".png"))
		sp.light_mask = 0
		sp.self_modulate = neutre_amb
		if calque[1]:
			var add := CanvasItemMaterial.new()
			add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
			sp.material = add
		if sp != fond:
			sp.name = "Fond_" + calque[0]
			sp.position = fond.position
			couche.add_child(sp)
			couche.move_child(sp, fond.get_index() + ordre)
		ordre += 1
	for expr in ["neutre", "orgueil"]:
		var s := Sprite2D.new()
		s.name = "Image" if expr == "neutre" else "Orgueil"
		var t := CanvasTexture.new()
		t.diffuse_texture = load(HORUS_5B % [expr, ""])
		t.normal_texture = load(HORUS_5B % [expr, "_normal"])
		s.texture = t
		# Version 16:9 de TP2 (épaulières complètes, fourrure) : plein cadre, sur le fond de CA2.
		s.position = Vector2(960, 540)
		if expr == "orgueil":
			s.modulate.a = 0.0
		var ombre := Sprite2D.new()
		ombre.name = "Ombre"
		ombre.texture = load(HORUS_5B % [expr, "_ombre"])
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		ombre.material = m
		# Multiplication après le CanvasModulate de la couche : compensé pour rester neutre.
		ombre.self_modulate = neutre_amb
		s.add_child(ombre)
		# Lumière de contour chaude venue du soleil bas à droite : fine bande additive (retour GD : -30 %).
		if ResourceLoader.exists(HORUS_5B % [expr, "_contour"]):
			var liseret := Sprite2D.new()
			liseret.name = "Contour"
			liseret.texture = load(HORUS_5B % [expr, "_contour"])
			var ma := CanvasItemMaterial.new()
			ma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			ma.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
			liseret.material = ma
			var c := Color("#FFE8B0")
			liseret.self_modulate = Color(c.r * neutre_amb.r, c.g * neutre_amb.g, c.b * neutre_amb.b, 0.42)
			s.add_child(liseret)
		couche.add_child(s)
	# Lumière peinte = clé du soleil couchant, à droite ; la Light2D module légèrement le relief
	# sous un CanvasModulate propre à la couche (ne touche pas la scène).
	var amb := CanvasModulate.new()
	amb.color = AMB_GROS_PLAN
	couche.add_child(amb)
	var l := _lumiere(Vector2(1500, 300), Color("#FFE8B0"), 9.0)
	l.name = "CleHorus"
	l.energy = 0.45
	l.height = 400.0
	couche.add_child(l)
	couche.visibility_changed.connect(_animer_gros_plan_horus.bind(couche))


const AMB_GROS_PLAN := Color(0.78, 0.76, 0.76)
const DOSSIER_FOND_GROS_PLAN := "res://assets/decors/ullanor_gros_plan_horus/calques"
## [calque, additif] dans l'ordre du JSON de CA2.
const FOND_GROS_PLAN := [["00_fond_flou", false], ["30_dais_flou", false], ["31_dais_lisere", true], ["46_braseros", true]]
## Respiration (0,5 % sur ~4 s) et lente poussée de caméra (×1,04) tant que le gros plan est à l'écran.
const RESPIRATION := 0.005
const POUSSEE := 1.04
const POUSSEE_S := 14.0
var _tweens_gros_plan: Array[Tween] = []


func _animer_gros_plan_horus(couche: CanvasLayer) -> void:
	for t in _tweens_gros_plan:
		if t and t.is_valid():
			t.kill()
	_tweens_gros_plan.clear()
	var centre := Vector2(960, 540)
	var buste: Array[Sprite2D] = []
	for n in [^"Image", ^"Orgueil"]:
		var s := couche.get_node_or_null(n) as Sprite2D
		if s:
			s.scale = Vector2.ONE
			buste.append(s)
	_poser_poussee(1.0, couche, centre)
	if not couche.visible:
		return
	var feu := couche.get_node_or_null(^"Fond_46_braseros") as CanvasItem
	if feu:
		var v := create_tween().set_loops()
		for a in [0.82, 1.0, 0.9, 1.0]:
			v.tween_property(feu, "modulate:a", a, randf_range(0.12, 0.28))
		_tweens_gros_plan.append(v)
	var p := create_tween()
	p.tween_method(_poser_poussee.bind(couche, centre), 1.0, POUSSEE, POUSSEE_S) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tweens_gros_plan.append(p)
	if buste.is_empty():
		return
	var r := create_tween().set_loops()
	r.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in buste.size():
		var etape := r.parallel() if i > 0 else r
		etape.tween_property(buste[i], "scale", Vector2.ONE * (1.0 + RESPIRATION), 2.0)
	for i in buste.size():
		var etape := r.parallel() if i > 0 else r
		etape.tween_property(buste[i], "scale", Vector2.ONE, 2.0)
	_tweens_gros_plan.append(r)


func _poser_poussee(f: float, couche: CanvasLayer, centre: Vector2) -> void:
	couche.scale = Vector2.ONE * f
	couche.offset = centre * (1.0 - f)


# --------------------------------------------------------------------------- commandes

func _commande_specifique(nom: String, args: Array) -> void:
	match nom:
		"action":
			await _action(args[0] if not args.is_empty() else "obeir")
		"hochement":
			await _hochement()
		"expression":
			# « @expression orgueil [durée] » : fondu du gros plan d'Horus vers l'expression.
			var o := get_node_or_null(^"GrosPlanHorus/Orgueil") as CanvasItem
			if o:
				var cible := 1.0 if (args[0] if not args.is_empty() else "neutre") == "orgueil" else 0.0
				var t := create_tween()
				t.tween_property(o, "modulate:a", cible, float(args[1]) if args.size() > 1 else 0.5)
				await t.finished
		_:
			await super._commande_specifique(nom, args)


func _dialogue_fini() -> void:
	match phase:
		"libre":
			joueur.actif = true
		"fin":
			# Un chapitre qui continue après la ciné de fin (la nuit, l'aube…).
			if infos.has("suite"):
				phase = "epilogue"
				jouer_noeud(infos.suite)
			else:
				_finir()
		_:
			super._dialogue_fini()


## Réglages par défaut de la zone de la tranche, complétés par le fichier « jeu » du chapitre.
func config_zone(nom: String) -> Dictionary:
	var c := super.config_zone(nom)
	if nom != ZONE_CAMPEMENT:
		return c
	var defaut := {"decor": "bivouac", "depart": [DEPART.x, DEPART.y], "relisibles": true,
		"limites": [ZONE_MARCHE.position.x, ZONE_MARCHE.position.y, ZONE_MARCHE.size.x, ZONE_MARCHE.size.y],
		"relance": {"s": RELANCE_VOX_S, "noeud": "vox_relance"}, "pois": {}}
	for k in POI:
		defaut.pois[k] = [POI[k].x, POI[k].y]
	for k in c:
		if k == "pois":
			defaut.pois.merge(c.pois, true)
		else:
			defaut[k] = c[k]
	return defaut


func _commencer_jeu(nom: String) -> void:
	if nom == ZONE_CAMPEMENT:
		Son.ambiance("ullanor_bivouac", 2.0)
		Son.musique("stop", 6.0)
	await super._commencer_jeu(nom)
	# Figurants des points d'intérêt ajoutés par le chapitre (placeholders tant que la chaîne
	# d'images ne les a pas livrés).
	if nom == ZONE_CAMPEMENT:
		for k in pois:
			if not POI.has(k) and not config.get("figurants", {}).has(k):
				_prop(monde_de(bivouac), k.trim_prefix("poi_"), pois[k] + Vector2(0, -10))


# --------------------------------------------------------------------------- jeu

func _process(delta: float) -> void:
	match phase:
		"jeu":
			_jeu(delta)
		"libre":
			_libre(delta)
		"choix":
			_trembler_poutre()


func poi_disponible(nom: String) -> bool:
	# Ilse n'est plus sur sa caisse après l'éboulement ; un figurant parti ne revient pas.
	if nom == "poi_ilse" and phase != "jeu":
		return false
	if pois_vus.has(nom) and nom in config.get("disparait_apres", []):
		return false
	return super.poi_disponible(nom)


func _jeu(delta: float) -> void:
	if zone != ZONE_CAMPEMENT:
		super._jeu(delta)
		return
	temps_jeu += delta
	_suivre_inactivite(delta)
	for k in config.get("disparait_apres", []):
		if pois_vus.has(k) and props.has(k.trim_prefix("poi_")) and not boite.visible:
			props[k.trim_prefix("poi_")].visible = false
	var oblig := obligatoires_vus()
	if oblig and _obligatoires_depuis < 0.0:
		_obligatoires_depuis = temps_jeu
	# Filet : après la relance, GLISSEMENT_S sans bouger et la caméra va montrer l'éboulement
	# (une fois les points obligatoires vus).
	if oblig and relance_faite and inactif >= GLISSEMENT_S:
		_montrer_eboulement()
		return
	var par_temps: bool = oblig and config.has("eboulement_max_s") \
		and temps_jeu - _obligatoires_depuis >= float(config.eboulement_max_s)
	if not boite.visible and oblig and (joueur.position.x >= EBOULEMENT_X or par_temps):
		if par_temps and joueur.position.x < EBOULEMENT_X:
			_montrer_eboulement()
		else:
			_eboulement()
		return
	_interagir_pois()


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



func _eboulement() -> void:
	phase = "eboulement"
	_invite.hide()
	_aide.hide()
	# Vaskar se fige le temps du plan : il ne sort pas du cadre fixe.
	joueur.actif = false
	Son.bruitage("eboulement")
	var carcasse: Sprite2D = props.carcasse
	var t := create_tween().set_parallel()
	t.tween_property(carcasse, "rotation", -0.35, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(carcasse, "position", carcasse.position + Vector2(-90, 30), 0.9)
	# Le poste doit être dans le cadre : la caméra se recadre entre le poste et Vaskar (et
	# y reste jusqu'au rappel de Dremm), quel que soit le chemin qui a mené ici.
	camera.cible = null
	var x_cadre := clampf((POSTE.x + joueur.position.x) / 2.0, POSTE.x - 500.0, POSTE.x + 500.0)
	camera.jouer([{"position": [x_cadre, camera.position.y], "zoom": camera.zoom.x, "duree": 0.5, "courbe": "sortie"},
		{"position": [x_cadre, camera.position.y], "zoom": camera.zoom.x, "duree": 1.4,
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
		_inviter(POUTRE, "Maintenir %s : soulever" % touche("interagir"))
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

func titre_fin() -> String:
	return "Ullanor"


func rappel_fin() -> String:
	return RAPPEL_CHOIX.get(int(Jeu.drapeau("choix_ep01_ullanor", 3)), "")
