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
## Effets de mise en scène des nœuds (src/core/mise_en_scene.gd).
var mise_en_scene: MiseEnScene
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
	joueur.sprite = _figure("vaskar")
	joueur.add_child(joueur.sprite)
	joueur.visible = false
	post_soleil = PostSoleil.new()
	add_child(post_soleil)
	if decor and decor.visible:
		post_soleil.suivre(decor)
		var amb0 := get_node_or_null(^"Ambiance") as CanvasModulate
		if amb0:
			amb0.set_meta("defaut", amb0.color)
			amb0.color = ambiance_du_decor(decor, amb0.color)
		decor.appliquer_rebond(amb0.color if amb0 else Color(0, 0, 0, 0))
	super._ready()
	_lever_noir_initial()


var _decor_demande := false


## CanvasModulate voulu pour un décor : celui du plan, blanc pour un plan à lumière peinte sans
## ambiance (retour DA, Ullanor), sinon celui de la scène.
static func ambiance_du_decor(d: Node2D, defaut: Color) -> Color:
	if d is Decor25D and d.ambiant.a > 0.0:
		return d.ambiant
	if d is Decor25D and d.peint_sans_ambiance:
		return Color.WHITE
	return defaut
var post_soleil: PostSoleil


## Suite après le dernier carton (la nuit après le Triomphe) : le noir du carton passe au voile
## de la scène, pour que l'ancien décor ne revienne pas pendant le fondu du carton (QA 05:12).
## Si la suite ne change pas de décor, le voile se lève comme au lancement.
func jouer_noeud(nom: String) -> void:
	if is_instance_valid(carton_final) and _voile_noir:
		_voile_noir.modulate.a = 1.0
		_decor_demande = false
		_lever_noir_initial()
	super.jouer_noeud(nom)


func noircir_sous_carton() -> void:
	if _voile_noir:
		_voile_noir.modulate.a = 1.0


## Si le début du chapitre ne change pas de décor, on lève le noir sur le décor de la scène.
func _lever_noir_initial() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not _decor_demande and _voile_noir.modulate.a > 0.0:
		_fondu_noir(0.0, 0.35)


func _avant_dialogue() -> void:
	if infos.has("jeu"):
		var z = JSON.parse_string(FileAccess.get_file_as_string(infos.jeu))
		if typeof(z) == TYPE_DICTIONARY:
			zones = z
		else:
			push_error("Fichier jeu illisible : %s" % infos.jeu)
	lecteur.noeud_entre.connect(_mise_en_scene_du_noeud)
	mise_en_scene = MiseEnScene.new()
	mise_en_scene.camera = camera
	mise_en_scene.drapeaux = Jeu.etat.drapeaux
	mise_en_scene.position_joueur = func(): return joueur.global_position if is_instance_valid(joueur) else Vector2(960, 900)
	mise_en_scene.figurant = func(nom: String): return props.get(nom)
	add_child(mise_en_scene)
	_regie = RegieGrosPlans.charger("res://data/episodes/%s/gros_plans.json" % Jeu.etat.episode)
	lecteur.noeud_entre.connect(_regie_entrer)
	boite.evenement.connect(_sur_evenement_dialogue)


# --------------------------------------------------------------------------- gros plans

## Gros plans de dialogue (fonds de CA2, bustes de CA1) : décidés par la régie, affichés sous les
## gros plans d'Horus (5) et l'interface (10). Le fond, déjà éclairé, a sa couche (3) ; le buste
## a la sienne (4), avec son ambiance (CanvasModulate) et ses Light2D clé et contre, qui ne
## touchent pas le fond. Les Light2D n'éclairent rien dans un CanvasLayer (Godot 4.7,
## Compatibilité) : le buste est rendu dans un SubViewport transparent, affiché dans la couche.
const COUCHE_FOND_GROS_PLAN := 3
const COUCHE_GROS_PLAN := 4
const FONDU_GROS_PLAN_S := 0.25
const FONDU_EXPRESSION_S := 0.3
var _regie := RegieGrosPlans.new()
var _couche_gp: CanvasLayer
var _racine_gp: Node2D
var _fond_gp := ""
var _couche_buste: CanvasLayer
var _vue_buste: SubViewport
var _ecran_buste: Sprite2D
var _racine_buste: Node2D
var _cle_buste := ""
var _cle_eclairage := ""


## « @plan large | serre | serre:<perso> » : surcharge de la régie (Narrative).
func executer_commande(nom: String, args: Array) -> void:
	if nom == "plan" and not args.is_empty() and mise_en_scene:
		mise_en_scene.plan(String(args[0]))
	if nom == "plan" and not args.is_empty() and RegieGrosPlans.est_surcharge(String(args[0])):
		_regie.surcharger(String(args[0]))
		return
	if nom == "plan" and _regie.plan != "large":
		_regie.plan_nomme()
		_afficher_gros_plan("large")
	await super.executer_commande(nom, args)


func _regie_entrer(noeud: String) -> void:
	_regie.entrer(String(infos.get("id", "")), noeud)
	if _regie.plan == "large" and _couche_gp and _couche_gp.visible:
		_afficher_gros_plan("large")


func _sur_evenement_dialogue(e: Dictionary) -> void:
	if mise_en_scene and e.get("type") == "replique":
		mise_en_scene.ligne()
	var avant := _regie.plan
	var p := _regie.decider(e)
	if p != avant or (p != "large" and _couche_gp and not _couche_gp.visible):
		_afficher_gros_plan(p)
	elif p != "large":
		_poser_buste(p)


func _afficher_gros_plan(p: String) -> void:
	if p == "large":
		if _couche_gp and _couche_gp.visible:
			var t := create_tween().set_parallel()
			t.tween_property(_racine_gp, "modulate:a", 0.0, FONDU_GROS_PLAN_S)
			t.tween_property(_ecran_buste, "modulate:a", 0.0, FONDU_GROS_PLAN_S)
			t.chain().tween_callback(func() -> void:
				_couche_gp.hide()
				_couche_buste.hide()
				_vue_buste.render_target_update_mode = SubViewport.UPDATE_DISABLED)
		return
	var id_fond := String(_regie.scene.get("decor", ""))
	# Sans « etat » dans la scène, le fond suit l'état du décor affiché (aube ou nuit au bloc).
	var scene_gp: Dictionary = _regie.scene.duplicate()
	if not scene_gp.has("etat") and decor is Decor25D and not String(decor.etat).is_empty():
		scene_gp.etat = decor.etat
	var cle_fond := "%s|%s" % [id_fond, scene_gp.get("etat", "")]
	if _couche_gp == null:
		_couche_gp = CanvasLayer.new()
		_couche_gp.name = "GrosPlanFond"
		_couche_gp.layer = COUCHE_FOND_GROS_PLAN
		_couche_gp.visible = false
		add_child(_couche_gp)
		_couche_buste = CanvasLayer.new()
		_couche_buste.name = "GrosPlanDialogue"
		_couche_buste.layer = COUCHE_GROS_PLAN
		_couche_buste.visible = false
		add_child(_couche_buste)
		_vue_buste = SubViewport.new()
		_vue_buste.name = "VueBuste"
		_vue_buste.size = Vector2i(Decor25D.taille_ecran())
		_vue_buste.transparent_bg = true
		_couche_buste.add_child(_vue_buste)
		_ecran_buste = Sprite2D.new()
		_ecran_buste.name = "EcranBuste"
		_ecran_buste.centered = false
		_ecran_buste.texture = _vue_buste.get_texture()
		_ecran_buste.material = materiau_premultiplie().duplicate()
		_couche_buste.add_child(_ecran_buste)
		_racine_buste = Node2D.new()
		_racine_buste.name = "Buste"
		_vue_buste.add_child(_racine_buste)
	if cle_fond != _fond_gp:
		if _racine_gp:
			_racine_gp.queue_free()
		_racine_gp = construire_fond_gros_plan(id_fond, scene_gp)
		_couche_gp.add_child(_racine_gp)
		_fond_gp = cle_fond
		var accord: Dictionary = _racine_gp.get_meta("accord", {})
		var mat := _ecran_buste.material as ShaderMaterial
		mat.set_shader_parameter("teinte", accord.get("teinte", Color.WHITE))
		mat.set_shader_parameter("plafond", float(accord.get("plafond", 10.0)))
		mat.set_shader_parameter("exposition", float(accord.get("exposition", 1.0)))
		var lis: Dictionary = accord.get("lisere", {})
		mat.set_shader_parameter("lisere_force", float(lis.get("force", 0.0)))
		if not lis.is_empty():
			var c := Color(String(lis.get("couleur", "#FFE8B0")))
			mat.set_shader_parameter("lisere_couleur", Vector3(c.r, c.g, c.b))
			var dl: Array = lis.get("direction", [-1.0, 0.0])
			mat.set_shader_parameter("lisere_dir", Vector2(dl[0], dl[1]).normalized())
			mat.set_shader_parameter("lisere_px", float(lis.get("px", 3.0)))
	_poser_buste(p, false)
	if not _couche_gp.visible:
		_racine_gp.modulate.a = 0.0
		_ecran_buste.modulate.a = 0.0
		_couche_gp.show()
		_couche_buste.show()
	_vue_buste.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var t := create_tween().set_parallel()
	t.tween_property(_racine_gp, "modulate:a", 1.0, FONDU_GROS_PLAN_S)
	t.tween_property(_ecran_buste, "modulate:a", 1.0, FONDU_GROS_PLAN_S)


## Buste du personnage cadré, à l'expression de la régie, éclairé pour le fond. Un changement
## d'expression sur le même cadrage se fait en fondu enchaîné (CA1).
func _poser_buste(p: String, enchaine := true) -> void:
	if _racine_buste == null:
		return
	var cote := _regie.cote_du_plan()
	var id_fond := String(_regie.scene.get("decor", ""))
	var cle_ecl := "%s|%s|%s|%s" % [p, cote, _fond_gp, id_fond]
	if cle_ecl != _cle_eclairage:
		for n in _vue_buste.get_children():
			if n != _racine_buste:
				n.queue_free()
		var etat := String(_fond_gp.get_slice("|", 1))
		var tete_x := float(tete_du_fond(id_fond, cote, _racine_gp.get_meta("zones", {}) if _racine_gp else {}).x)
		for n in construire_eclairage_buste(RegieGrosPlans.eclairage_buste(p, cote), id_fond, cote, etat, tete_x):
			_vue_buste.add_child(n)
		_cle_eclairage = cle_ecl
	var chemin := RegieGrosPlans.chemin_buste(p, cote, _regie.expression)
	var cle := "%s|%s" % [chemin, cote]
	if cle == _cle_buste:
		return
	var ancien := _racine_buste.get_child(_racine_buste.get_child_count() - 1) as Sprite2D \
		if _racine_buste.get_child_count() > 0 else null
	var meme_cadrage: bool = enchaine and ancien != null and ancien.get_meta("cadrage", "") == "%s|%s" % [p, cote]
	_cle_buste = cle
	var tete := tete_du_fond(id_fond, cote, _racine_gp.get_meta("zones", {}) if _racine_gp else {})
	var sp := construire_sprite_buste(chemin, tete, cote, p)
	# « decalage_x » de la scène {perso: px} : écarter une tête d'un point lumineux du fond
	# (DA : le hublot de la cabine faisait une auréole à Sefa).
	sp.position.x += float(_regie.scene.get("decalage_x", {}).get(p.to_upper(), 0.0))
	sp.set_meta("cadrage", "%s|%s" % [p, cote])
	_racine_buste.add_child(sp)
	if meme_cadrage:
		sp.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(sp, "modulate:a", 1.0, FONDU_EXPRESSION_S)
		t.tween_callback(ancien.queue_free)
	for n in _racine_buste.get_children():
		if n != sp and not (meme_cadrage and n == ancien):
			n.queue_free()
	_accorder_visage(tete.x + float(_regie.scene.get("decalage_x", {}).get(p.to_upper(), 0.0)), cle)


## DA 27/11 : dans un gros plan, le visage porte. Sa médiane ne descend pas à plus de
## ECART_VISAGE sous celle de l'armure (valeurs finales, exposition comprise) : on mesure le
## buste rendu une fois, puis le visage seul est remonté dans le shader d'affichage.
const ECART_VISAGE := 0.08
const GAIN_VISAGE_MAX := 3.0


func _accorder_visage(tete_x: float, cle: String) -> void:
	var mat := _ecran_buste.material as ShaderMaterial
	var h := float(_vue_buste.size.y)
	var w := float(_vue_buste.size.x)
	# Tête : crâne à CRANE_CIBLE, menton à MENTON_CIBLE (cadrage) ; on garde le centre du visage.
	var cy := (CRANE_CIBLE + MENTON_CIBLE) * 0.5
	var demi_h := (MENTON_CIBLE - CRANE_CIBLE) * 0.5
	var demi_w := demi_h * h / w / RAPPORT_TETE * 0.8
	mat.set_shader_parameter("visage", Vector4(tete_x / w, cy, demi_w, demi_h))
	mat.set_shader_parameter("gain_visage", 1.0)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_instance_valid(_vue_buste) or cle != _cle_buste:
		return
	var img := _vue_buste.get_texture().get_image()
	if img == null:
		return
	img.resize(320, 180, Image.INTERPOLATE_BILINEAR)
	var expo := float(mat.get_shader_parameter("exposition"))
	var face := _mediane_zone(img, Rect2((tete_x / w - demi_w * 0.6) * 320, (cy - demi_h * 0.5) * 180, demi_w * 1.2 * 320, demi_h * 180))
	var armure := _mediane_zone(img, Rect2((tete_x / w - demi_w * 2.5) * 320, (MENTON_CIBLE + 0.12) * 180, demi_w * 5.0 * 320, 0.25 * 180))
	if OS.has_environment("DEBUG_VISAGE"):
		print("visage ", face, " armure ", armure, " expo ", expo, " tete_x ", tete_x)
	if face <= 0.0 or armure <= 0.0:
		return
	var voulu := armure * expo - ECART_VISAGE
	if face * expo < voulu:
		mat.set_shader_parameter("gain_visage", clampf(voulu / (face * expo), 1.0, GAIN_VISAGE_MAX))


static func _mediane_zone(img: Image, r: Rect2) -> float:
	var v := PackedFloat32Array()
	var x0 := clampi(int(r.position.x), 0, img.get_width() - 1)
	var y0 := clampi(int(r.position.y), 0, img.get_height() - 1)
	var x1 := clampi(int(r.end.x), x0 + 1, img.get_width())
	var y1 := clampi(int(r.end.y), y0 + 1, img.get_height())
	for y in range(y0, y1):
		for x in range(x0, x1):
			var c := img.get_pixel(x, y)
			if c.a > 0.6:
				v.append(Color(c.r / c.a, c.g / c.a, c.b / c.a).get_luminance())
	if v.size() < 10:
		return -1.0
	v.sort()
	return v[v.size() / 2]


## Cadrage des gros plans (tools/gros_plans/cadrage.py, calcul de CA1) : la tête du buste prend
## la largeur et l'axe de la tête du gabarit 40 du fond, resserrée pour l'émotion (DA 27/11) :
## haut du crâne à CRANE_CIBLE, menton à MENTON_CIBLE de la hauteur du cadre. Tête du gabarit :
## crâne 117 px au-dessus des yeux, 280 px du crâne au menton.
const CADRAGE := "res://data/gros_plans_cadrage.json"
const CRANE_CIBLE := 0.15
const MENTON_CIBLE := 0.45
const GABARIT_CRANE_YEUX := 117.0
const GABARIT_HAUTEUR_TETE := 280.0
## Hauteur crâne-menton d'un buste de CA1 ≈ 1,08 largeur maximale de la silhouette de la tête
## (mesuré sur Dremm et Sefa : 235 / 217 et 255 / 254 ; la chevelure élargit Sefa).
const RAPPORT_TETE := 1.08
static var _cadrage: Dictionary


static func cadrage() -> Dictionary:
	if _cadrage.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(CADRAGE)) if FileAccess.file_exists(CADRAGE) else null
		_cadrage = d if typeof(d) == TYPE_DICTIONARY else {"fonds": {}, "bustes": {}}
	return _cadrage


## Tête du gabarit 40 d'un fond à l'écran {x, y (ligne des yeux), largeur} ; sans gabarit, celle
## des fonds de CA2 (yeux à 497, tête de 211 px), centrée dans la zone calme du côté.
static func tete_du_fond(id_fond: String, cote: String, zones: Dictionary = {}) -> Dictionary:
	var t = cadrage().fonds.get(id_fond, {}).get(cote)
	if typeof(t) != TYPE_DICTIONARY:
		var zone: Array = zones.get(cote, {}).get("x_px", [0, 960] if cote != "droite" else [960, 1920])
		t = {"x": (float(zone[0]) + float(zone[1])) / 2.0, "y": 497.0, "largeur": 211.0}
	return tete_serree(t)


## Tête du gabarit resserrée : même axe, échelle et hauteur des yeux tirées des cibles.
static func tete_serree(t: Dictionary) -> Dictionary:
	var h := Decor25D.taille_ecran().y
	var k := (MENTON_CIBLE - CRANE_CIBLE) * h / GABARIT_HAUTEUR_TETE
	return {"x": float(t.x), "y": CRANE_CIBLE * h + GABARIT_CRANE_YEUX * k, "largeur": float(t.largeur) * k}


## Sprite du buste : albédo et normales dosées (visage FORCE_NORMALES_TETE, armure et vêtements
## FORCE_NORMALES_CORPS : la peinture porte déjà son modelé), tête calée sur celle du gabarit.
## Un buste générique buste.png (peint pour la gauche) est mis en miroir à droite ; les bustes
## finaux de CA1 sont peints pour chaque côté.
const FORCE_NORMALES_TETE := 0.3
const FORCE_NORMALES_CORPS := 0.5
const SHADER_BUSTE := """
shader_type canvas_item;
uniform sampler2D normales : filter_linear;
uniform bool a_normales = false;
uniform float force_tete = 0.3;
uniform float force_corps = 0.5;
uniform float y_cou = 0.45;
void fragment() {
	if (a_normales) {
		NORMAL_MAP = texture(normales, UV).rgb;
		NORMAL_MAP_DEPTH = mix(force_tete, force_corps, smoothstep(y_cou - 0.03, y_cou + 0.03, UV.y));
	}
}
"""
static var _shader_buste: Shader


static func construire_sprite_buste(chemin: String, tete_fond: Dictionary, cote: String, perso := "") -> Sprite2D:
	var sp := Sprite2D.new()
	sp.name = chemin.get_file().get_basename()
	sp.centered = false
	var tex := load(chemin) as Texture2D
	sp.texture = tex
	sp.flip_h = cote == "droite" and chemin.get_file() == "buste.png"
	if _shader_buste == null:
		_shader_buste = Shader.new()
		_shader_buste.code = SHADER_BUSTE
	var m := ShaderMaterial.new()
	m.shader = _shader_buste
	var normale := chemin.get_basename() + "_normal.png"
	if ResourceLoader.exists(normale):
		m.set_shader_parameter("normales", load(normale))
		m.set_shader_parameter("a_normales", true)
	m.set_shader_parameter("force_tete", FORCE_NORMALES_TETE)
	m.set_shader_parameter("force_corps", FORCE_NORMALES_CORPS)
	sp.material = m
	if tex == null:
		return sp
	var taille := tex.get_size()
	var b = cadrage().bustes.get(perso.to_upper(), {}).get(cote)
	var tete_b: Dictionary = b if typeof(b) == TYPE_DICTIONARY else {"x": taille.x / 2.0, "crane": taille.y * 0.15, "largeur": taille.x * 0.18}
	if sp.flip_h:
		tete_b = tete_b.duplicate()
		tete_b.x = taille.x - float(tete_b.x)
	# Tête : du crâne au menton relevé, sinon RAPPORT_TETE largeur de silhouette ; aux cibles.
	var tete_h := float(tete_b.menton) - float(tete_b.crane) if tete_b.has("menton") \
		else float(tete_b.largeur) * RAPPORT_TETE
	var h := Decor25D.taille_ecran().y
	var ech := (MENTON_CIBLE - CRANE_CIBLE) * h / tete_h
	# Cou : un peu sous le menton.
	m.set_shader_parameter("y_cou", (float(tete_b.crane) + tete_h * 1.05) / taille.y)
	sp.scale = Vector2.ONE * ech
	sp.position = Vector2(float(tete_fond.x) - float(tete_b.x) * ech, CRANE_CIBLE * h - float(tete_b.crane) * ech)
	return sp


## Ambiance et lumières du buste pour un fond : celles du .eclairage.json de CA1 (un fichier par
## côté), sinon les « lumieres » du fond de CA2 (écrites pour la gauche, x symétrisé à droite) ;
## sans rien, une clé neutre de face. direction_camera = sens de la lumière (x à droite, y vers le
## haut, z vers la caméra : z > 0 vient de derrière, rasante ; z < 0 vient de face).
static func construire_eclairage_buste(ecl: Dictionary, id_fond: String, cote: String, etat := "", tete_x := -1.0) -> Array:
	var tete := tete_du_fond(id_fond, cote)
	if tete_x < 0.0:
		tete_x = float(tete.x)
	var L: Dictionary = ecl.get("fonds", {}).get(id_fond, {}).get("lumieres", {})
	# Le .eclairage.json d'un côté droit est déjà symétrisé par CA1 ; le fond, lui, est écrit
	# pour la gauche.
	var miroir := cote == "droite" and (L.is_empty() or String(ecl.get("cote_ecran", "gauche")) != "droite")
	var g := {}
	var chemin_fond := DOSSIER_DECORS.path_join(id_fond).path_join(id_fond + ".json")
	if FileAccess.file_exists(chemin_fond):
		var lu = JSON.parse_string(FileAccess.get_file_as_string(chemin_fond))
		g = lu if typeof(lu) == TYPE_DICTIONARY else {}
	if L.is_empty() and typeof(g.get("lumieres")) == TYPE_DICTIONARY:
		L = g.lumieres
	var noeuds: Array = []
	var cm := CanvasModulate.new()
	cm.name = "Ambiance"
	var amb: Dictionary = L.get("ambiance", {})
	var couleur_amb := Color("#2A2A32")
	if amb.has("couleur"):
		couleur_amb = Color(String(amb.couleur))
	else:
		# Fond de la longue traîne : l'ambiance du décor source pour l'état affiché.
		var etats: Dictionary = g.get("lumieres_source", {}).get("etats", {}) \
			if typeof(g.get("lumieres_source")) == TYPE_DICTIONARY else {}
		for nom in etats:
			if etats[nom].has("canvas_modulate") and (etat.is_empty() or etat.begins_with(nom) or nom == etat):
				couleur_amb = Color(String(etats[nom].canvas_modulate))
				if nom == etat:
					break
	var gain := float(amb.get("gain", 1.0))
	cm.color = Color(couleur_amb.r * gain, couleur_amb.g * gain, couleur_amb.b * gain)
	noeuds.append(cm)
	var cle: Dictionary = L.get("cle", {"couleur": "#E0D8CC", "direction_camera": [0.3, -0.3, -0.9]})
	noeuds.append(_lumiere_buste("Cle", cle, 1.0, miroir, null, tete_x))
	if L.has("contre"):
		var contre: Dictionary = L.contre
		# Contre sans direction : du haut, côté opposé à la clé.
		var dc = cle.get("direction_camera", [0.3, -0.3, 0.5])
		noeuds.append(_lumiere_buste("Contre", contre, float(contre.get("force", 0.3)), miroir,
			[-float(dc[0]), -0.6, 0.6], tete_x))
	# Plancher du visage (DA, nuit d'Ullanor : les yeux doivent sortir) : un appoint doux de face,
	# limité à la tête, de la couleur de l'ambiance.
	var plancher := float(amb.get("plancher_visage", PLANCHER_VISAGE.get(id_fond, 0.0)))
	if plancher > 0.0:
		var f := PointLight2D.new()
		f.name = "PlancherVisage"
		f.position = Vector2(tete_x, float(tete.y) + 0.3 * float(tete.largeur))
		f.texture = _texture_lumiere_buste()
		f.texture_scale = float(tete.largeur) * 1.6 / 128.0
		f.height = 400.0
		var c := couleur_amb.lerp(Color.WHITE, 0.5)
		f.color = c
		f.energy = plancher
		noeuds.append(f)
	return noeuds


## Plancher du visage par fond, quand l'.eclairage.json n'a pas « ambiance.plancher_visage ».
const PLANCHER_VISAGE := {"ullanor_nuit_gros_plan": 0.4}
## Un contre venu de derrière (DirectionalLight2D rasante) ne rend qu'une fraction de sa force sur
## les normales : sans gain, la lune de la nuit d'Ullanor ne se voyait pas (DA).
const GAIN_CONTRE_RASANT := 4.0


static func _lumiere_buste(nom: String, d: Dictionary, energie: float, miroir: bool, dir_defaut, tete_x := 480.0) -> Light2D:
	var couleur := Color(String(d.get("couleur", "#FFFFFF")))
	var l: Light2D
	var dir_b = d.get("direction_camera", dir_defaut)
	if typeof(d.get("position_px")) != TYPE_ARRAY and typeof(dir_b) == TYPE_ARRAY and float(dir_b[1]) > 0.3:
		# Lumière par en dessous (feu au sol, hors champ) : une source ponctuelle sous le cadre,
		# qui s'éteint en montant (DA : rien au-dessus des épaulières, un liseré sous la mâchoire).
		var sx := float(dir_b[0]) * (-1.0 if miroir else 1.0)
		var pf := PointLight2D.new()
		pf.position = Vector2(tete_x - sx * 700.0, 1080.0 + 300.0)
		pf.texture = _texture_lumiere_buste()
		pf.texture_scale = 1400.0 / 128.0
		pf.height = 20.0
		l = pf
		energie *= 3.0
	elif typeof(d.get("position_px")) == TYPE_ARRAY:
		var pl := PointLight2D.new()
		var pos := Vector2(d.position_px[0], d.position_px[1])
		pl.position = Vector2(1920.0 - pos.x, pos.y) if miroir else pos
		pl.texture = _texture_lumiere_buste()
		pl.texture_scale = 1400.0 / 128.0
		pl.height = 80.0
		l = pl
	else:
		var dir = dir_b if dir_b != null else [0.0, -0.3, -0.9]
		var dl := DirectionalLight2D.new()
		var sx := float(dir[0]) * (-1.0 if miroir else 1.0)
		var sy := -float(dir[1])
		var z := float(dir[2])
		# DirectionalLight2D éclaire vers +y à rotation nulle.
		dl.rotation = atan2(-sx, sy)
		dl.height = clampf(-z * 0.45, 0.12, 0.45) if z < 0.0 else clampf(0.3 * (1.0 - z), 0.03, 0.2)
		if z > 0.0 and nom == "Contre":
			energie *= GAIN_CONTRE_RASANT
		l = dl
	l.name = nom
	l.color = couleur
	l.energy = energie
	var vac := float(d.get("vacillement", 0.0))
	var m := RegEx.create_from_string("vacillement (\\d+[,.]\\d+)").search(String(d.get("note", "")))
	if vac == 0.0 and m:
		vac = m.get_string(1).replace(",", ".").to_float()
	if vac > 0.0:
		l.ready.connect(func() -> void:
			var t := l.create_tween().set_loops()
			for k in [1.0 - vac, 1.0, 1.0 - vac * 0.5, 1.0]:
				t.tween_property(l, "energy", energie * k, randf_range(0.08, 0.25)))
	return l


static var _tex_lumiere_buste: Texture2D
static var _materiau_premult: ShaderMaterial


## Rendu d'un SubViewport transparent : couleurs déjà prémultipliées par l'alpha. Un mélange
## normal les remultiplie et noircit les contours (DA : liserés sombres) ; le fondu passe par
## l'alpha de modulate.
static func materiau_premultiplie() -> ShaderMaterial:
	if _materiau_premult == null:
		var sh := Shader.new()
		sh.code = """
shader_type canvas_item;
render_mode blend_premul_alpha;
// Accord avec le fond du gros plan : teinte du fond, et plafond (haute lumière du fond)
// approché en douceur à partir de 75 %.
uniform vec3 teinte = vec3(1.0);
uniform float plafond = 10.0;
uniform float exposition = 1.0;
// Visage : remonté seul (ellipse en UV, bord adouci) pour ne pas passer sous l'armure.
uniform vec4 visage = vec4(0.5, 0.3, 0.1, 0.15);
uniform float gain_visage = 1.0;
// Liseré de contre-jour : arête de la silhouette tournée vers la source (hors plafond).
uniform vec3 lisere_couleur = vec3(1.0, 0.91, 0.69);
uniform vec2 lisere_dir = vec2(-1.0, 0.0);
uniform float lisere_force = 0.0;
uniform float lisere_px = 3.0;
varying vec4 modulation;
void vertex() {
	modulation = COLOR;
}
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 u = t.rgb / max(t.a, 0.0001) * teinte * exposition;
	vec2 dv = (UV - visage.xy) / visage.zw;
	u *= mix(1.0, gain_visage, 1.0 - smoothstep(0.7, 1.0, length(dv)));
	float L = dot(u, vec3(0.2126, 0.7152, 0.0722));
	float k = 0.75 * plafond;
	if (L > k) {
		float Lc = k + (plafond - k) * (1.0 - exp(-(L - k) / (plafond - k)));
		u *= Lc / L;
	}
	if (lisere_force > 0.0) {
		vec2 pas = lisere_dir * TEXTURE_PIXEL_SIZE;
		float bord = max(1.0 - texture(TEXTURE, UV + pas * lisere_px).a,
				0.6 * (1.0 - texture(TEXTURE, UV + pas * lisere_px * 0.5).a));
		u += lisere_couleur * lisere_force * bord;
	}
	COLOR = vec4(u * t.a * modulation.rgb, t.a) * modulation.a;
}
"""
		_materiau_premult = ShaderMaterial.new()
		_materiau_premult.shader = sh
	return _materiau_premult


static func _texture_lumiere_buste() -> Texture2D:
	if _tex_lumiere_buste == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color.WHITE, Color(0.45, 0.45, 0.45), Color.BLACK])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 256
		t.height = 256
		_tex_lumiere_buste = t
	return _tex_lumiere_buste


## Fond de gros plan de CA2 (assets/decors/<id>) : calques déjà éclairés, posés tels quels ;
## « additif » en addition, avec un vacillement léger. Les gabarits de CA1 ne vont pas en jeu.
## La scène peut choisir un « etat » (calques marqués « etat » d'un autre état écartés) et des
## « opacites » {calque: a} (poussière à 0,4 la nuit, galerie).
static func construire_fond_gros_plan(id: String, scene: Dictionary = {}) -> Node2D:
	var racine := Node2D.new()
	racine.name = "Fond_" + id
	var dossier := DOSSIER_DECORS.path_join(id)
	var g = JSON.parse_string(FileAccess.get_file_as_string(dossier.path_join(id + ".json"))) \
		if FileAccess.file_exists(dossier.path_join(id + ".json")) else null
	if typeof(g) != TYPE_DICTIONARY:
		push_warning("Fond de gros plan introuvable : %s" % id)
		return racine
	racine.set_meta("zones", g.get("zones_calmes", {}))
	# État inconnu du fond (ou absent) : son premier état, jamais deux fonds superposés.
	var etats_fond: Array = []
	for k in g.get("calques", []):
		if typeof(k) == TYPE_DICTIONARY and k.has("etat") and not etats_fond.has(String(k.etat)):
			etats_fond.append(String(k.etat))
	var voulu := String(scene.get("etat", ""))
	if not etats_fond.is_empty() and not etats_fond.has(voulu):
		scene = scene.duplicate()
		scene.etat = etats_fond[0]
		# « aube_naissante » du décor → fond « aube ».
		for e in etats_fond:
			if not voulu.is_empty() and voulu.begins_with(e):
				scene.etat = e
	for k in g.get("calques", []):
		if typeof(k) != TYPE_DICTIONARY or not k.has("fichier") or k.has("pour"):
			continue
		if k.has("etat") and String(k.etat) != String(scene.get("etat", k.etat)):
			continue
		var chemin := dossier.path_join(k.fichier)
		if not ResourceLoader.exists(chemin):
			continue
		var sp := Sprite2D.new()
		sp.name = String(k.fichier).get_file().get_basename()
		sp.texture = load(chemin)
		sp.centered = false
		sp.light_mask = 0
		var mode := String(k.get("mode", ""))
		var additif := mode == "additif" or (mode.is_empty() and sp.name.begins_with("9"))
		sp.modulate.a = float(scene.get("opacites", {}).get(sp.name, 1.0))
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		if additif:
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sp.material = m
		racine.add_child(sp)
		if additif and not sp.name.begins_with("9"):
			sp.ready.connect(func() -> void:
				var t := sp.create_tween().set_loops()
				for a in [0.88, 1.0, 0.93, 1.0]:
					t.tween_property(sp, "modulate:a", a, randf_range(0.15, 0.35)))
	racine.set_meta("accord", accord_du_fond(racine, "%s|%s" % [id, scene.get("etat", "")]))
	return racine


## Accord du buste avec son fond (DA 27/11 : l'armure restait blanc-gris sur un fond ambre) :
## « teinte » = chroma moyenne du fond (luminance 1, dosée par FORCE_TEINTE_FOND), « plafond » =
## haute lumière du fond (centile 99,5 de la luminance), que le buste ne dépasse pas.
const FORCE_TEINTE_FOND := 0.6
const ECHANTILLON_FOND := Vector2i(160, 90)
static var _accords := {}


const ACCORD := "res://data/gros_plans_accord.json"


## Réglages d'un fond (et état) dans data/gros_plans_accord.json : « exposition »,
## « force_teinte » (part de la teinte du fond reprise), « lisere » {couleur, direction, force, px}.
static func reglage_du_fond(cle: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(ACCORD)) if FileAccess.file_exists(ACCORD) else null
	var fonds: Dictionary = d.get("fonds", {}) if typeof(d) == TYPE_DICTIONARY else {}
	var e = fonds.get(cle, fonds.get(cle.get_slice("|", 0), {}))
	return e if typeof(e) == TYPE_DICTIONARY else {}


static func exposition_du_fond(cle: String) -> float:
	return float(reglage_du_fond(cle).get("exposition", 1.0))


static func accord_du_fond(racine: Node2D, cle: String) -> Dictionary:
	if _accords.has(cle):
		return _accords[cle]
	var w := ECHANTILLON_FOND.x
	var h := ECHANTILLON_FOND.y
	var px := PackedColorArray()
	px.resize(w * h)
	px.fill(Color.BLACK)
	for sp in racine.get_children():
		if not (sp is Sprite2D) or sp.texture == null:
			continue
		var img: Image = sp.texture.get_image()
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()
		img = img.duplicate()
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
		var add := (sp.material as CanvasItemMaterial) != null \
			and (sp.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD
		var op := float(sp.modulate.a)
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				var a := c.a * op
				var i := y * w + x
				px[i] = px[i] + Color(c.r * a, c.g * a, c.b * a, 0.0) if add \
					else px[i].lerp(Color(c.r, c.g, c.b), a)
	var somme := Color(0, 0, 0)
	var lums := PackedFloat32Array()
	lums.resize(px.size())
	for i in px.size():
		somme += px[i]
		lums[i] = px[i].get_luminance()
	lums.sort()
	var moy := somme / float(px.size())
	var l := maxf(moy.get_luminance(), 0.01)
	var chroma := Color(moy.r / l, moy.g / l, moy.b / l)
	var reg := reglage_du_fond(cle)
	var t := Color(1, 1, 1).lerp(chroma, float(reg.get("force_teinte", FORCE_TEINTE_FOND)))
	var lt := maxf(t.get_luminance(), 0.01)
	var r := {"teinte": Color(t.r / lt, t.g / lt, t.b / lt), "plafond": maxf(lums[int(lums.size() * 0.995)], 0.12),
		"exposition": float(reg.get("exposition", 1.0)), "lisere": reg.get("lisere", {})}
	_accords[cle] = r
	return r


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
	# Particules, tirs, éclairs, tremblements, calques animés (MiseEnScene, Level Designer).
	# Un nœud qui commence par @decor : les effets attendent le nouveau décor (sinon ils
	# seraient posés sur l'ancien, puis retirés par le changement).
	if mise_en_scene:
		if _commence_par_decor(noeud):
			_mise_en_scene_en_attente = m
		else:
			_jouer_mise_en_scene(m)


var _mise_en_scene_en_attente: Dictionary = {}


func _jouer_mise_en_scene(m: Dictionary) -> void:
	var d := decor_par_id(decor_courant)
	if d == null:
		return
	mise_en_scene.drapeaux = Jeu.etat.drapeaux
	mise_en_scene.jouer(m, d, monde_de(d))


## Vrai si le nœud change de décor avant sa première réplique ou son premier choix.
func _commence_par_decor(noeud: String) -> bool:
	if lecteur == null:
		return false
	for instr in lecteur.dialogue.get("noeuds", {}).get(noeud, []):
		match instr.get("type"):
			"commande":
				if instr.get("nom") == "decor":
					return true
			"replique", "menu":
				return false
	return false


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
		l.name = "LumiereMontante"
		l.add_to_group("souvenir_surexpose")
		# Le halo monte aussi dans le ciel (calques non éclairés, masque halo).
		l.range_item_cull_mask = Decor25D.MASQUE_LUMIERE | Decor25D.MASQUE_HALO
		l.energy = 0.0
		l.height = 300.0
		d.add_child(l)
		t.tween_property(l, "energy", float(L.get("energie", 2.5)), duree)
	var amb := get_node_or_null(^"Ambiance") as CanvasModulate
	if amb and e.has("ambiance"):
		var avant := amb.color
		_tween_souvenir = create_tween()
		_tween_souvenir.tween_property(amb, "color", Color(e.ambiance), duree * 0.6)
		_tween_souvenir.tween_property(amb, "color", avant, duree)
		_surexpose = Color(e.ambiance)


## Réglages d'image d'un souvenir (« mémoire surexposée ») : retirés à chaque changement de décor.
var _tween_souvenir: Tween
var _surexpose := Color(0, 0, 0, 0)
const SORTIE_SOUVENIR_S := 1.0
var _tween_ambiance: Tween


## Remet l'image à zéro avant un nouveau décor : coupe le tween d'ambiance du souvenir et retire
## ses lumières. Rend la teinte de départ du fondu (la surexposition si un souvenir était actif,
## alpha 0 sinon).
func reinitialiser_image() -> Color:
	if mise_en_scene:
		mise_en_scene.nettoyer()
	if _tween_souvenir and _tween_souvenir.is_valid():
		_tween_souvenir.kill()
	_tween_souvenir = null
	for l in get_tree().get_nodes_in_group("souvenir_surexpose"):
		l.queue_free()
	for n in get_tree().get_nodes_in_group("props_de_plan"):
		props.erase(String(n.name))
		n.queue_free()
	var depart := _surexpose
	_surexpose = Color(0, 0, 0, 0)
	return depart


## Plan objet : changer de décor si besoin, puis remplacer des textures de calques (extérieur de
## la galerie : croisade, warp, Orvane).
func _preparer_plan(p: Dictionary) -> void:
	if p.has("decor") and p.decor != decor_courant:
		await _changer_decor(p.decor)
	var d := decor_par_id(p.get("decor", decor_courant))
	# « etat » : état propre au plan (la lampe serrée sur Sefa la nuit), posé à la coupe.
	if p.has("etat") and d is Decor25D and d.etat != String(p.etat):
		d.appliquer_etat(String(p.etat), float(p.get("fondu_etat", 0.0)))
	# « props » : {nom: [x, y]} posés sur le décor le temps du plan (la plaque à l'aube).
	# Forme objet : {nom: {"position": [x, y], "miroir": true, "decalage": [0, 0], "echelle": 1.0}}.
	for nom in p.get("props", {}):
		if not is_instance_valid(props.get(nom)):
			var v = p.props[nom]
			var spec := spec_figure(v if typeof(v) == TYPE_DICTIONARY else {"position": v})
			var pos: Array = spec.position
			# Dans le « Monde » du décor (z 10) : posé à la racine, il passait sous tous les calques.
			var s := _prop(monde_de(d), nom, Vector2(pos[0], pos[1]))
			poser_figure(s, spec)
			s.add_to_group("props_de_plan")
	for nom in p.get("textures", {}):
		var image: Sprite2D = null
		for c in (d.calques if d is Decor25D else d.get_children()):
			if String(c.name) == String(nom):
				image = c.get_node_or_null(^"Image") as Sprite2D
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
	_vox.add_theme_font_override("font", StyleSchisme.italique())
	_vox.add_theme_color_override("font_color", StyleSchisme.TEXTE)
	_vox.add_theme_color_override("font_outline_color", Color.BLACK)
	_vox.add_theme_constant_override("outline_size", 8)
	_ui.add_child(_vox)
	_aide = _construire_aide_deplacement()
	_ui.add_child(_aide)
	_voile_noir = ColorRect.new()
	_voile_noir.color = Color.BLACK
	_voile_noir.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile_noir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Noir au lancement : le décor posé dans la scène (le Triomphe d'Ullanor) ne doit pas
	# apparaître avant le premier @decor ou @plan du chapitre (QA : 2 s du Triomphe avant l'archive).
	_voile_noir.modulate.a = 1.0
	_ui.add_child(_voile_noir)
	_invite = Label.new()
	_invite.add_theme_font_size_override("font_size", 26)
	_invite.add_theme_font_override("font", StyleSchisme.texte(500))
	_invite.add_theme_color_override("font_color", StyleSchisme.MARBRE)
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
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_font_override("font", StyleSchisme.texte(500))
	l.add_theme_color_override("font_color", StyleSchisme.MARBRE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	var plaque := StyleBoxFlat.new()
	plaque.bg_color = Color(0.04, 0.03, 0.02, 0.82)
	plaque.border_color = StyleSchisme.OR_TERNI
	plaque.set_border_width_all(1)
	plaque.set_corner_radius_all(0)
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
	s.scale = Vector2.ONE * echelle_prop(nom)
	return s


## Échelle d'un accessoire peint au double (props/echelles.json) ; 1 sinon.
static var _echelles_props: Dictionary = {}
static func echelle_prop(nom: String) -> float:
	if _echelles_props.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(PROPS + "echelles.json")) \
			if FileAccess.file_exists(PROPS + "echelles.json") else null
		_echelles_props = d if typeof(d) == TYPE_DICTIONARY else {"_": 1}
	return float(_echelles_props.get(nom, 1.0))


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
	if etiquettes_de_debogage():
		var l := Label.new()
		l.name = "EtiquetteDebogage"
		l.text = nom
		l.position = Vector2(-60, -300)
		l.add_theme_font_size_override("font_size", 20)
		s.add_child(l)
	return s


## Étiquettes de débogage (noms des silhouettes et décors provisoires) : dans l'éditeur
## seulement, jamais dans une build exportée (règle GD 27/11, contrôlée en CI).
## SCHISME_SANS_DEBUG=1 les coupe aussi dans l'éditeur (bots de capture, tests).
static func etiquettes_de_debogage() -> bool:
	return OS.has_feature("editor") and OS.get_environment("SCHISME_SANS_DEBUG") != "1"


## « @geste <perso> <geste> [attendre] » : geste d'un personnage découpé (data/anim/gestes.json).
## Le personnage est un figurant posé ou le joueur. Sans « attendre », le dialogue continue
## pendant le geste ; avec, il reprend une fois le geste posé (ou fini s'il ne se tient pas).
## Un personnage encore en sprite d'un bloc ignore le geste (pas d'erreur : les .dlg peuvent
## être écrits avant la livraison des pièces).
func jouer_geste(args: Array) -> void:
	if args.size() < 2:
		push_warning("@geste : il faut un personnage et un geste (%s)" % [args])
		return
	var qui := String(args[0]).to_lower()
	var f = props.get(qui)
	if not is_instance_valid(f) and joueur and joueur.sprite and String(joueur.sprite.name) == qui:
		f = joueur.sprite
	if not (f is RigPersonnage):
		return
	var rig := f as RigPersonnage
	if not rig.jouer_geste(String(args[1])):
		return
	if args.size() > 2 and String(args[2]) == "attendre":
		await get_tree().create_timer(rig.duree_visible(String(args[1]))).timeout


## Dossier du personnage découpé (rig.json + pièces, contrat de découpe v1).
const DOSSIER_RIGS := "res://assets/personnages/%s/pied"


## Figure d'un personnage : son rig s'il est livré, sinon son sprite d'un bloc (ou la silhouette).
func _figure(nom: String) -> Node2D:
	var rig := RigPersonnage.charger(DOSSIER_RIGS % nom)
	if rig:
		rig.scale = Vector2.ONE * _echelle_figure(rig)
		return rig
	return _sprite(nom)


## Les pièces des rigs sont peintes au double de la taille en jeu (contrat v1).
static func _echelle_figure(f: Node2D) -> float:
	return 0.5 if f is RigPersonnage else 1.0


## Figurant posé sur un point : rig ou sprite ; un sprite reçoit respiration et balancement,
## désynchronisés (phase tirée du nom).
func _figurant(parent: Node, nom: String, pos: Vector2) -> Node2D:
	var f := _figure(nom)
	f.position = pos
	parent.add_child(f)
	props[nom] = f
	if f is Sprite2D:
		VieFigure.animer(f)
	return f


## Condition d'un point ou d'un prop de zone : un nom de drapeau (vrai), ou une expression
## (« vivant_ilse == true and choix_ep01_orvane != 1 », comme la mise en scène). Absente : vrai.
static func condition_de_zone(config: Dictionary, cle: String, drapeaux_partie: Dictionary) -> bool:
	var si = config.get("conditions", {}).get(cle)
	if typeof(si) != TYPE_STRING or String(si).strip_edges().is_empty():
		return true
	var texte := String(si).strip_edges()
	if texte.is_valid_identifier():
		return bool(drapeaux_partie.get(texte, false))
	return MiseEnScene.condition_vraie(texte, drapeaux_partie)


## Le décor a ses personnages peints (calque 40_personnages livré, pas son gabarit).
static func personnages_peints(d: Node) -> bool:
	if d == null:
		return false
	var c := d.get_node_or_null(^"Calque_40_personnages")
	return c != null and not bool(c.get_meta("gabarit", false))


## Figurant ou prop : un nom seul, ou un objet {nom, geste, miroir, decalage, echelle, position}.
static func spec_figure(v) -> Dictionary:
	var o: Dictionary = v if typeof(v) == TYPE_DICTIONARY else {"nom": str(v)}
	var dec = o.get("decalage", [0, 0])
	var pos = o.get("position", [0, 0])
	return {
		"nom": String(o.get("nom", "")),
		"geste": String(o.get("geste", "")),
		"miroir": bool(o.get("miroir", false)),
		"decalage": dec if typeof(dec) == TYPE_ARRAY and dec.size() >= 2 else [0, 0],
		"echelle": float(o.get("echelle", 1.0)),
		"position": pos if typeof(pos) == TYPE_ARRAY and pos.size() >= 2 else [0, 0],
	}


## Applique décalage, échelle, miroir et geste. Un geste inconnu du rig (ou un sprite) : repos.
static func poser_figure(f: Node2D, spec: Dictionary) -> void:
	if f == null:
		return
	f.position += Vector2(float(spec.decalage[0]), float(spec.decalage[1]))
	var e := float(spec.echelle)
	if e != 1.0:
		f.scale *= e
	if spec.miroir:
		f.scale.x = -absf(f.scale.x)
	if not String(spec.geste).is_empty() and f is RigPersonnage \
			and (f as RigPersonnage).gestes_connus().has(spec.geste):
		(f as RigPersonnage).jouer_geste(spec.geste)


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
					var t := create_tween()
					t.tween_property(amb, "color", dec.ambiant, duree)
					t.tween_callback(func(): dec.appliquer_rebond(amb.color))
				else:
					amb.color = dec.ambiant
					dec.appliquer_rebond(amb.color))
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
	for x in range(0, int(TAILLE_PROVISOIRE.x), 1920 if etiquettes_de_debogage() else 1 << 30):
		var l := Label.new()
		l.name = "EtiquetteDebogage"
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
		# « etat_selon » comme dans les zones : {"drapeau", "valeurs", "defaut"} (archive_fin).
		return {"decor": r.get("decor", id), "etat": r.get("etat", ""), "etat_selon": r.get("etat_selon", {})}
	return {"decor": id, "etat": "", "etat_selon": {}}


## État choisi par un drapeau de partie : {"drapeau", "valeurs": {"1": "..."}, "defaut"}.
static func etat_selon(e: Dictionary, drapeaux_partie: Dictionary) -> String:
	var v = drapeaux_partie.get(e.get("drapeau", ""))
	var cle := str(int(v)) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else str(v)
	return String(e.get("valeurs", {}).get(cle, e.get("defaut", "")))


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
		return etat_selon(c.etat_selon, Jeu.etat.drapeaux)
	return String(c.get("etat", ""))


func _changer_decor(id_demande: String) -> void:
	_decor_demande = true
	var r := resoudre_decor(id_demande)
	var id: String = r.decor
	var cible := decor_par_id(id)
	var etat := _etat_a_l_entree(id, r.etat)
	if not r.etat_selon.is_empty():
		etat = etat_selon(r.etat_selon, Jeu.etat.drapeaux)
	if cible.visible and decor_courant == id:
		if cible is Decor25D and not etat.is_empty() and cible.etat != etat:
			cible.appliquer_etat(etat, 1.5)
		if mise_en_scene and not _mise_en_scene_en_attente.is_empty():
			var m := _mise_en_scene_en_attente
			_mise_en_scene_en_attente = {}
			_jouer_mise_en_scene(m)
		if _voile_noir.modulate.a > 0.0 and phase != "ecran_fin":
			await _fondu_noir(0.0, 0.35)
		return
	await _fondu_noir(1.0, 0.35)
	var sortie_souvenir := reinitialiser_image()
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
		var normal: Color = ambiance_du_decor(cible, amb.get_meta("defaut"))
		if _tween_ambiance and _tween_ambiance.is_valid():
			_tween_ambiance.kill()
		if sortie_souvenir.a > 0.0:
			# Sortie de souvenir : de la surexposition vers l'étalonnage normal du lieu.
			amb.color = sortie_souvenir
			_tween_ambiance = create_tween()
			_tween_ambiance.tween_property(amb, "color", normal, SORTIE_SOUVENIR_S)
			if cible is Decor25D:
				_tween_ambiance.tween_callback(func(): cible.appliquer_rebond(normal))
		else:
			amb.color = normal
		if cible is Decor25D:
			cible.appliquer_rebond(normal)
	post_soleil.suivre(cible)
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
	if mise_en_scene and not _mise_en_scene_en_attente.is_empty():
		var m := _mise_en_scene_en_attente
		_mise_en_scene_en_attente = {}
		_jouer_mise_en_scene(m)
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
		"geste":
			await jouer_geste(args)
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
		if not condition_de_zone(config, k, Jeu.etat.drapeaux):
			continue
		var p: Array = config.pois[k]
		pois[k] = Vector2(p[0], p[1])
	# Décor avec ses personnages peints (calque 40_personnages de CA1) : les figurants
	# provisoires les doubleraient.
	var peints := personnages_peints(d)
	var poses := 0
	for k in config.get("figurants", {}):
		var spec := spec_figure(config.figurants[k])
		if not peints and pois.has(k) and not spec.nom.is_empty() and not props.has(spec.nom):
			poser_figure(_figurant(monde_de(d), spec.nom, pois[k] + Vector2(0, -10)), spec)
			poses += 1
	# « props » de zone : {cle: {nom, position, geste, miroir, decalage, echelle}}, chacun sous sa
	# condition (« conditions »[cle]). Posés même sur un décor peint : la mise en scène les veut.
	# Retrouvés par leur nom (@geste ilse agenouiller) et par leur clé.
	for k in config.get("props", {}):
		if not condition_de_zone(config, k, Jeu.etat.drapeaux):
			continue
		var spec := spec_figure(config.props[k])
		if spec.nom.is_empty():
			spec.nom = String(k)
		if is_instance_valid(props.get(spec.nom)):
			continue
		var f := _figurant(monde_de(d), spec.nom, Vector2(float(spec.position[0]), float(spec.position[1])))
		poser_figure(f, spec)
		props[String(k)] = f
		poses += 1
	# Le gabarit de la DA (silhouettes grises) doublerait les figures posées : masqué tant qu'il y en a.
	var gab := d.get_node_or_null(^"Calque_40_personnages") if d else null
	if gab and bool(gab.get_meta("gabarit", false)):
		gab.visible = poses == 0
	_declenches = {}
	_vus_depuis = {}
	_tout_vu_depuis = -1.0
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
		joueur.sprite = _figure(perso)
		joueur.add_child(joueur.sprite)
	joueur.sprite.scale = Vector2.ONE * float(config.get("echelle", 1.0)) * _echelle_figure(joueur.sprite)
	# Respiration au repos (sprite d'un bloc) : l'échelle du chapitre devient l'échelle de repos.
	# Un rig respire et marche de lui-même.
	if joueur.sprite is Sprite2D:
		VieFigure.animer(joueur.sprite).reprendre()
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


## Règle générale (spec v1.4 §9) : quand tous les points d'intérêt disponibles de la zone sont
## vus (un point masqué par une condition n'est pas dans « pois »), la suite part TOUT_VU_S
## secondes après la fin de la dernière réplique ; le max_s des déclencheurs reste un filet.
const TOUT_VU_S := 3.0
## Temps de jeu où le dernier point a fini d'être lu (-1 : pas encore tout vu).
var _tout_vu_depuis := -1.0


func tous_pois_vus() -> bool:
	# Aucun point disponible (zone vide, Ilse morte) : rien n'a été « tout vu ».
	var comptes := 0
	for k in pois:
		if pois_vus.has(k):
			comptes += 1
		elif poi_disponible(k):
			return false
	return comptes > 0


func _suivre_declencheurs() -> bool:
	var i := declencheur_pret()
	if i < 0:
		return false
	_declenches[i] = true
	_quitter_jeu()
	jouer_noeud(config.declencheurs[i].noeud)
	return true


## Index du déclencheur qui part maintenant (-1 : aucun) : x franchi, max_s écoulé, ou tout vu.
func declencheur_pret() -> int:
	if boite.visible:
		_tout_vu_depuis = -1.0
		return -1
	# Spec §9.4 : une zone à déclencheur de position (« x ») avance par le chemin et le filet
	# max_s, jamais par la règle « tout vu » (assaut du ch. 4 : la suite est au bout de la rue).
	var par_position := false
	for d in config.get("declencheurs", []):
		par_position = par_position or (d as Dictionary).has("x")
	if not par_position and _tout_vu_depuis < 0.0 and tous_pois_vus():
		_tout_vu_depuis = temps_jeu
	var tout_vu := _tout_vu_depuis >= 0.0 and temps_jeu - _tout_vu_depuis >= TOUT_VU_S
	var liste: Array = config.get("declencheurs", [])
	# Tout vu : la suite est celle du filet (premier déclencheur à max_s prêt), sinon le premier
	# déclencheur prêt.
	var suite := -1
	if tout_vu:
		for i in liste.size():
			if not _declenches.has(i) and obligatoires_vus(liste[i].get("apres", [])):
				if liste[i].has("max_s"):
					suite = i
					break
				if suite < 0:
					suite = i
	for i in liste.size():
		var d: Dictionary = liste[i]
		if _declenches.has(i) or not obligatoires_vus(d.get("apres", [])):
			continue
		if not _vus_depuis.has(i):
			_vus_depuis[i] = temps_jeu
		var par_temps: bool = d.has("max_s") and temps_jeu - _vus_depuis[i] >= float(d.max_s)
		if joueur.position.x >= float(d.get("x", INF)) or par_temps or i == suite:
			return i
	return -1


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


## Écran de fin (maquette UI v0.1, écran 8) : « FIN DE L'ÉPISODE N », titre, « Ce que l'archive
## a gardé » (le rappel, une ou plusieurs lignes), boutons en cartouches.
func _construire_ecran_fin(titre: String, rappel: String) -> Control:
	var centre := CenterContainer.new()
	centre.name = "EcranFin"
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 26)
	centre.add_child(vb)
	var ep := Catalogue.episode(Jeu.etat.episode)
	vb.add_child(StyleSchisme.surtitre("FIN DE L'ÉPISODE %d" % int(ep.get("numero", 1))))
	var l_titre := StyleSchisme.label(titre, StyleSchisme.titre(500), 90, StyleSchisme.MARBRE, 0.06)
	l_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l_titre)
	vb.add_child(StyleSchisme.regle_fleur())
	if not rappel.is_empty():
		var tete := StyleSchisme.label("CE QUE L'ARCHIVE A GARDÉ", StyleSchisme.titre(600), 18, StyleSchisme.OR_TERNI, 0.36)
		tete.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(tete)
	var ligne := StyleSchisme.label(rappel, StyleSchisme.italique(), 30, Color("#D8CFBB"))
	ligne.name = "Rappel"
	ligne.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ligne.add_theme_constant_override("line_spacing", 8)
	vb.add_child(ligne)
	var espace := Control.new()
	espace.custom_minimum_size.y = 30
	vb.add_child(espace)
	var boutons := HBoxContainer.new()
	boutons.alignment = BoxContainer.ALIGNMENT_CENTER
	boutons.add_theme_constant_override("separation", 26)
	vb.add_child(boutons)
	for d in [["Rejouer", func(): Jeu.nouvelle_partie(Jeu.etat.episode)],
			["Menu", func(): get_tree().change_scene_to_file(Jeu.MENU)],
			["Quitter", func(): get_tree().quit()]]:
		var b := Button.new()
		b.name = d[0]
		b.text = d[0]
		b.custom_minimum_size = Vector2(290, 62)
		StyleBoxCartouche.habiller(b)
		b.pressed.connect(d[1])
		boutons.add_child(b)
	return centre


# --------------------------------------------------------------------------- vox

## Affiche les répliques d'un nœud en surimpression, sans arrêter le jeu.
func jouer_vox(noeud: String) -> void:
	var l := LecteurDialogue.new(lecteur.dialogue, Jeu.etat.drapeaux)
	l.demarrer(noeud)
	var e := l.avancer()
	while e.type == "replique":
		var nom := BoiteDialogue.nom_affiche(e)
		var t := BoiteDialogue.typographie(e.texte)
		_vox_file.append(("%s\u00A0: %s" % [nom, t]) if not nom.is_empty() else t)
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
	if texte.contains(BoiteDialogue.SUFFIXE_VOX):
		Son.bruitage("vox_crepite")
	_vox.text = texte
	_vox.show()
	await get_tree().create_timer(maxf(2.5, texte.length() * 0.06)).timeout
	_vox_suivant()
