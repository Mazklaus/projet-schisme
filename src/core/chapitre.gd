class_name Chapitre
extends Node2D
## Base d'une scène de chapitre : décor 2.5D, caméra de ciné, boîte de dialogue.
##
## La scène lit son chapitre dans le Catalogue (Jeu.etat), charge le .dlg, et exécute les
## commandes du dialogue (liste dans executer_commande). Une commande inconnue est transmise
## à _commande_specifique(), à surcharger par chapitre.

@export var decor: Decor25D
@export var camera: CameraCine
@export var boite: BoiteDialogue
## Pour lancer la scène seule depuis l'éditeur (F6) : chapitre utilisé si Jeu n'en a pas.
@export var episode_par_defaut := ""
@export var chapitre_par_defaut := ""

var infos: Dictionary
var plans: Dictionary = {}
var lecteur: LecteurDialogue


func _ready() -> void:
	if Jeu.etat.episode.is_empty():
		Jeu.etat.episode = episode_par_defaut
		Jeu.etat.chapitre = chapitre_par_defaut
	infos = Catalogue.chapitre(Jeu.etat.episode, Jeu.etat.chapitre)
	# « plans » : un fichier ou une liste de fichiers (plans de l'épisode, puis du chapitre).
	var fichiers_plans = infos.get("plans", [])
	for f in [fichiers_plans] if typeof(fichiers_plans) == TYPE_STRING else fichiers_plans:
		var p = JSON.parse_string(FileAccess.get_file_as_string(f))
		if typeof(p) == TYPE_DICTIONARY:
			plans.merge(p, true)
		else:
			push_error("Plans illisibles : %s" % f)
	boite.commande.connect(_executer)
	boite.fini.connect(_dialogue_fini)
	var indicateur := IndicateurArchivage.new()
	indicateur.name = "IndicateurArchivage"
	add_child(indicateur)
	if infos.has("dialogue"):
		var d := FormatDialogue.charger(infos.dialogue)
		for err in d.erreurs:
			push_error("%s : %s" % [infos.dialogue, err])
		lecteur = LecteurDialogue.new(d, Jeu.etat.drapeaux)
		lecteur.noeud_entre.connect(func(n): Jeu.etat.noeud_dialogue = n)
		var depart: String = Jeu.etat.noeud_dialogue
		var debut: bool = depart.is_empty() or not d.noeuds.has(depart)
		if debut:
			depart = d.ordre[0] if not d.ordre.is_empty() else FormatDialogue.FIN
		_avant_dialogue()
		if debut and cartons_chapitre:
			_lancer_apres_carton(depart)
		else:
			boite.lancer(lecteur, depart)


## Carton de chapitre au début de chaque chapitre (pas à la reprise d'une sauvegarde en cours de
## chapitre). Désactivable pour les tests qui pilotent une scène pas à pas.
static var cartons_chapitre := true


func _lancer_apres_carton(depart: String) -> void:
	var ep := Catalogue.episode(Jeu.etat.episode)
	var numero := 1
	var chapitres: Array = ep.get("chapitres", [])
	for i in chapitres.size():
		if chapitres[i].get("id", "") == Jeu.etat.chapitre:
			numero = i + 1
	var ligne := "Épisode %d · %s" % [ep.get("numero", 1), ep.get("titre", "")] if not ep.is_empty() else ""
	await afficher_carton_chapitre(numero, infos.get("titre", ""), ligne)
	if is_inside_tree():
		boite.lancer(lecteur, depart)


## Appelé juste avant le premier nœud du dialogue (lecteur prêt) : à surcharger.
func _avant_dialogue() -> void:
	pass


func _executer(nom: String, args: Array) -> void:
	# « & » en dernier argument : la commande démarre et le dialogue continue sans l'attendre.
	var sans_attendre: bool = not args.is_empty() and args[-1] == "&"
	if sans_attendre:
		args = args.slice(0, args.size() - 1)
		executer_commande(nom, args)
	else:
		await executer_commande(nom, args)
	if nom != "fin":
		boite.reprendre()


## Exécute une commande de dialogue (attendable). Commandes communes à tous les chapitres :
##   @plan <nom>                     séquence caméra du fichier de plans du chapitre
##   @attendre <s>
##   @lumiere <nœud> <énergie> [s]   énergie d'une Light2D
##   @carton <s> <texte…>            texte plein écran sur fond noir
##   @titre <s> <texte…>             texte sur l'image, sans fond
##   @montrer <nœud> / @cacher <nœud>
##   @fondu <nœud> <opacité> [s]
##   @teinte <nœud> <#couleur> [s]   modulate (assombrir, poussière…)
##   @echelle <nœud> <sx> <sy> [s]
##   @fumee <nœud> <force> [s]       ombre de fumée mouvante sur une image ; les reflets
##                                   clairs et chauds (armure dorée) restent allumés. 0 : dissipée
##   @clameur <s> <texte…>           cri de foule : texte ivoire et or incrusté sur l'image,
##                                   avec un tremblement de caméra
##   @sauver                         sauvegarde l'état de la partie
##   @ambiance <nom> [s]             boucle d'ambiance amb_<nom>, fondu enchaîné (autoload Son)
##   @musique <nom|stop> [s]         boucle de musique mus_<nom>, ou coupe la musique
##   @bruitage <nom>                 bruitage sfx_<nom> (ou une de ses variantes), une fois
##   (les commandes de son rendent la main tout de suite)
##   @fin                            termine le chapitre
## Les chemins de nœuds sont relatifs à la scène de chapitre.
func executer_commande(nom: String, args: Array) -> void:
	match nom:
		"plan":
			var brut = plans.get(args[0] if not args.is_empty() else "", [])
			var p: Array = brut if typeof(brut) == TYPE_ARRAY else brut.get("sequence", [])
			if typeof(brut) == TYPE_DICTIONARY:
				await _preparer_plan(brut)
			if p.is_empty():
				if typeof(brut) != TYPE_DICTIONARY:
					push_warning("Plan caméra inconnu : %s" % [args])
			else:
				camera.jouer(p)
				await camera.sequence_terminee
		"attendre":
			await get_tree().create_timer(float(args[0]) if not args.is_empty() else 1.0).timeout
		"lumiere":
			var l := _noeud(args, 0) as Light2D
			if l:
				await _animer(l, "energy", float(args[1]), args, 2)
		"carton", "titre":
			if args.size() >= 2:
				# Dernier carton noir du dialogue : il reste noir jusqu'à la suite (écran de fin,
				# chapitre suivant), sans laisser revoir la scène derrière lui.
				var final := nom == "carton" and lecteur != null and lecteur.finit_ensuite()
				await afficher_carton(" ".join(args.slice(1)), float(args[0]), nom == "carton",
					Color.WHITE, Color.BLACK, final)
		"montrer", "cacher":
			# CanvasItem ou CanvasLayer (gros plans en surimpression) : tous deux ont « visible ».
			var n := _noeud(args, 0)
			if n and "visible" in n:
				n.visible = nom == "montrer"
		"fondu":
			var n := _noeud(args, 0) as CanvasItem
			if n:
				n.visible = true
				await _animer(n, "modulate:a", float(args[1]), args, 2)
		"teinte":
			var n := _noeud(args, 0) as CanvasItem
			if n:
				var c := Color(args[1])
				c.a = n.modulate.a
				await _animer(n, "modulate", c, args, 2)
		"echelle":
			var n := _noeud(args, 0) as Node2D
			if n:
				await _animer(n, "scale", Vector2(float(args[1]), float(args[2])), args, 3)
		"fumee":
			var n := _noeud(args, 0) as CanvasItem
			if n and args.size() > 1:
				var m := Chapitre.materiau_fumee(n)
				var cible := float(args[1])
				var duree := float(args[2]) if args.size() > 2 else 0.0
				if duree <= 0.0:
					m.set_shader_parameter("force", cible)
				else:
					# tween_method : les uniformes ne sont pas des propriétés listées partout
					# (pilote factice des tests).
					var t := create_tween()
					t.tween_method(func(v: float): m.set_shader_parameter("force", v),
						float(m.get_shader_parameter("force")), cible, duree)
					await t.finished
		"clameur":
			if args.size() >= 2:
				var duree := float(args[0])
				camera.jouer([{"position": [camera.position.x, camera.position.y], "zoom": camera.zoom.x,
					"duree": minf(duree, 1.6), "courbe": "lineaire", "tremblement": 9}])
				await afficher_carton(" ".join(args.slice(1)), duree, false, COULEUR_CLAMEUR, CONTOUR_CLAMEUR)
		"sauver":
			Jeu.sauver()
		"ambiance":
			if not args.is_empty():
				Son.ambiance(args[0], float(args[1]) if args.size() > 1 else 2.0)
		"musique":
			if not args.is_empty():
				Son.musique(args[0], float(args[1]) if args.size() > 1 else 2.0)
		"bruitage":
			if not args.is_empty():
				Son.bruitage(args[0])
		"fin":
			_finir()
		_:
			await _commande_specifique(nom, args)


func _noeud(args: Array, i: int) -> Node:
	var n: Node = get_node_or_null(NodePath(args[i])) if args.size() > i else null
	if n == null:
		push_warning("Nœud introuvable pour la commande : %s" % [args])
	return n


## Anime une propriété ; durée en args[i_duree] (0 ou absente : immédiat).
func _animer(n: Object, propriete: String, valeur: Variant, args: Array, i_duree: int) -> void:
	var duree := float(args[i_duree]) if args.size() > i_duree else 0.0
	if duree <= 0.0:
		n.set_indexed(NodePath(propriete), valeur)
		return
	var t := create_tween()
	t.tween_property(n, propriete, valeur, duree)
	await t.finished


const COULEUR_CLAMEUR := Color("#F2EAD3")
const CONTOUR_CLAMEUR := Color("#B8892E")
const SHADER_FUMEE := """
shader_type canvas_item;
// Ombre de fumée qui passe sur l'image : deux couches de bruit qui dérivent. Les pixels
// clairs et chauds (reflets dorés) sont épargnés, pour que l'ombre ait une cause visible.
uniform sampler2D bruit : repeat_enable, filter_linear;
uniform float force = 0.0;
uniform vec2 vitesse = vec2(0.05, 0.012);
uniform vec3 teinte : source_color = vec3(0.30, 0.28, 0.26);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float n = texture(bruit, UV * vec2(1.1, 0.7) + TIME * vitesse).r;
	float n2 = texture(bruit, UV * 2.4 - TIME * vitesse * 1.8).r;
	float fumee = smoothstep(0.3, 0.7, n * 0.7 + n2 * 0.3);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float reflet = smoothstep(0.55, 0.8, lum) * smoothstep(0.0, 0.12, c.r - c.b);
	float ombre = force * mix(0.45, 1.0, fumee) * (1.0 - 0.85 * reflet);
	c.rgb = mix(c.rgb, c.rgb * teinte, ombre);
	COLOR = c;
}
"""


## Matériau de fumée d'un nœud (créé à la première utilisation).
static func materiau_fumee(n: CanvasItem) -> ShaderMaterial:
	if n.material is ShaderMaterial and (n.material as ShaderMaterial).shader.resource_name == "fumee":
		return n.material
	var sh := Shader.new()
	sh.resource_name = "fumee"
	sh.code = SHADER_FUMEE
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.012
	bruit.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.noise = bruit
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("bruit", tex)
	m.set_shader_parameter("force", 0.0)
	n.material = m
	return m


## Texte plein écran, avec fondu (habillage StyleSchisme, maquette UI v0.1) :
##   fond noir (@carton)  : carton d'archive, surtitre « ARCHIVE » et phrase en italique ;
##   sur l'image (@titre) : lieu en capitales romaines, filet d'or, puis la suite (date…) en or,
##                          en bas à gauche sur un voile sombre ;
##   couleur donnée (@clameur) : texte en capitales sur l'image, à la couleur demandée.
func afficher_carton(texte: String, duree: float, fond_noir := true, couleur := Color.WHITE,
		contour := Color.BLACK, garder_noir := false) -> void:
	var couche := CanvasLayer.new()
	couche.layer = 50
	var fond := ColorRect.new()
	fond.color = StyleSchisme.NOIR if fond_noir else Color(0, 0, 0, 0)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	var l: Control
	if fond_noir:
		l = Chapitre.contenu_archive(texte)
	elif couleur == Color.WHITE:
		l = Chapitre.contenu_lieu(texte, fond)
	else:
		var lc := StyleSchisme.label(texte, StyleSchisme.titre(700), 48, couleur, 0.06)
		lc.add_theme_color_override("font_outline_color", contour)
		lc.add_theme_constant_override("outline_size", 10)
		lc.set_anchors_preset(Control.PRESET_FULL_RECT)
		# Sur l'image : en bas à gauche, au-dessus de la boîte de dialogue, pour ne pas tomber
		# sur le point focal du plan (retour DA, Ullanor).
		lc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lc.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		lc.offset_left = 110.0
		lc.offset_bottom = -300.0
		l = lc
	fond.add_child(l)
	couche.add_child(fond)
	add_child(couche)
	fond.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(fond, "modulate:a", 1.0, 0.4)
	t.tween_interval(maxf(duree - 0.8, 0.0))
	if garder_noir:
		# Seul le texte s'efface ; le noir reste jusqu'à liberer_carton_final().
		t.tween_property(l, "modulate:a", 0.0, 0.4)
		await t.finished
		liberer_carton_final()
		carton_final = couche
		return
	t.tween_property(fond, "modulate:a", 0.0, 0.4)
	await t.finished
	couche.queue_free()


## Carton d'archive : surtitre « ARCHIVE » entre deux filets, phrase en Garamond italique,
## première lettre en or.
static func contenu_archive(texte: String) -> Control:
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 40)
	centre.add_child(vb)
	vb.add_child(StyleSchisme.surtitre("ARCHIVE"))
	var phrase := RichTextLabel.new()
	phrase.name = "Texte"
	phrase.bbcode_enabled = true
	phrase.fit_content = true
	phrase.scroll_active = false
	phrase.custom_minimum_size.x = 1150
	phrase.add_theme_font_override("normal_font", StyleSchisme.italique())
	phrase.add_theme_font_size_override("normal_font_size", 46)
	phrase.add_theme_color_override("default_color", Color("#E3DAC4"))
	phrase.add_theme_constant_override("line_separation", 10)
	var t := BoiteDialogue.typographie(texte.strip_edges())
	if not t.is_empty():
		t = "[color=#%s]%s[/color]%s" % [StyleSchisme.OR_CLAIR.to_html(false), t.substr(0, 1), t.substr(1)]
	phrase.text = "[center]%s[/center]" % t
	vb.add_child(phrase)
	return centre


## « Ullanor. 000.M31. » → [« ULLANOR », « 000.M31 »] : le lieu, puis le reste (date, précision).
static func decouper_lieu(texte: String) -> PackedStringArray:
	var t := texte.strip_edges()
	var i := t.find(". ")
	var lieu := t.substr(0, i) if i >= 0 else t.trim_suffix(".")
	var suite := t.substr(i + 2).strip_edges().trim_suffix(".") if i >= 0 else ""
	return PackedStringArray([lieu.to_upper(), suite])


## Titre sur l'image : en bas à gauche (retour DA, Ullanor), sur un voile sombre (lisibilité
## sur les fonds clairs, retour DA du 27/11). Le filet d'or se trace de gauche à droite.
static func contenu_lieu(texte: String, fond: Control) -> Control:
	var voile := TextureRect.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.04, 0.035, 0.03, 0.55), Color(0.04, 0.035, 0.03, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	# Rayon 1 depuis le coin bas gauche : nul sur les autres coins, sans bord visible.
	gt.fill_from = Vector2(0.0, 1.0)
	gt.fill_to = Vector2(0.7, 0.3)
	gt.width = 128
	gt.height = 64
	voile.texture = gt
	voile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	voile.stretch_mode = TextureRect.STRETCH_SCALE
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	voile.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	voile.offset_top = -620
	voile.offset_right = 1100
	voile.offset_bottom = -180
	fond.add_child(voile)
	var parties := decouper_lieu(texte)
	var vb := VBoxContainer.new()
	vb.name = "Lieu"
	vb.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	vb.grow_vertical = Control.GROW_DIRECTION_BEGIN
	vb.offset_left = 110.0
	vb.offset_bottom = -300.0
	vb.add_theme_constant_override("separation", 8)
	var l1 := StyleSchisme.label(parties[0], StyleSchisme.titre(600), 54, StyleSchisme.MARBRE, 0.16)
	l1.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l1.add_theme_constant_override("shadow_offset_y", 2)
	l1.add_theme_constant_override("shadow_outline_size", 6)
	vb.add_child(l1)
	var regle := HBoxContainer.new()
	regle.add_theme_constant_override("separation", 12)
	var los := StyleSchisme.Losange.new()
	los.plein = true
	regle.add_child(los)
	var filet := StyleSchisme.Filet.new(260.0)
	filet.couleur = StyleSchisme.OR
	regle.add_child(filet)
	vb.add_child(regle)
	if not parties[1].is_empty():
		var l2 := StyleSchisme.label(parties[1].to_upper(), StyleSchisme.titre(500), 26, StyleSchisme.OR_CLAIR, 0.3)
		l2.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		l2.add_theme_constant_override("shadow_offset_y", 2)
		l2.add_theme_constant_override("shadow_outline_size", 6)
		vb.add_child(l2)
	filet.scale.x = 0.0
	filet.create_tween().tween_property(filet, "scale:x", 1.0, 0.6).set_delay(0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return vb


## Carton de chapitre : ogive fine, « CHAPITRE II », titre, ligne d'épisode. Fondu 0,6 s, tenue,
## fondu 0,6 s ; le noir se lève ensuite sur la scène.
func afficher_carton_chapitre(numero: int, titre_chapitre: String, ligne_episode: String, duree := 3.5) -> void:
	var couche := CanvasLayer.new()
	couche.name = "CartonChapitre"
	couche.layer = 55
	var fond := ColorRect.new()
	fond.color = StyleSchisme.NOIR
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	couche.add_child(fond)
	var contenu := Chapitre.contenu_chapitre(numero, titre_chapitre, ligne_episode)
	fond.add_child(contenu)
	add_child(couche)
	contenu.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(contenu, "modulate:a", 1.0, 0.6)
	t.tween_interval(maxf(duree - 1.2, 0.0))
	t.tween_property(contenu, "modulate:a", 0.0, 0.6)
	t.tween_property(fond, "modulate:a", 0.0, 0.4)
	await t.finished
	couche.queue_free()


static func contenu_chapitre(numero: int, titre_chapitre: String, ligne_episode: String) -> Control:
	var racine := Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ogive := Ogive.new()
	ogive.set_anchors_preset(Control.PRESET_CENTER)
	ogive.offset_left = -350
	ogive.offset_right = 350
	ogive.offset_top = -400
	ogive.offset_bottom = 360
	racine.add_child(ogive)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(centre)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 30)
	centre.add_child(vb)
	vb.add_child(StyleSchisme.surtitre("CHAPITRE " + StyleSchisme.romain(numero)))
	var t := StyleSchisme.label(titre_chapitre, StyleSchisme.titre(500), 82, StyleSchisme.MARBRE, 0.06)
	t.name = "Titre"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	vb.add_child(StyleSchisme.regle_fleur())
	if not ligne_episode.is_empty():
		var e := StyleSchisme.label(ligne_episode, StyleSchisme.italique(), 28, StyleSchisme.GRIS)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(e)
	return racine


## Ogive (arc brisé) au trait fin d'or terni, derrière le carton de chapitre.
class Ogive extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for k in [[0.0, 0.55, 1.2], [20.0, 0.3, 0.8]]:
			var m: float = k[0]
			var w := size.x - 2.0 * (40.0 + m)
			var x0 := 40.0 + m
			var haut := 10.0 + m * 1.2
			# Arc brisé : deux arcs de rayon 0,8 × la largeur, centrés sur la ligne de naissance.
			var r := w * 0.8
			var th_sommet := acos((w / 2.0 - r) / r)
			var naissance := haut + r * sin(th_sommet)
			var pts := PackedVector2Array([Vector2(x0, size.y)])
			var n := 24
			for i in n + 1:
				var th := PI - (PI - th_sommet) * float(i) / n
				pts.append(Vector2(x0 + r + r * cos(th), naissance - r * sin(th)))
			for i in range(n, -1, -1):
				var th := PI - (PI - th_sommet) * float(i) / n
				pts.append(Vector2(x0 + w - r - r * cos(th), naissance - r * sin(th)))
			pts.append(Vector2(x0 + w, size.y))
			draw_polyline(pts, Color(StyleSchisme.OR_TERNI, k[1]), k[2], true)


## Noir laissé par le dernier carton d'un dialogue (voir afficher_carton).
var carton_final: CanvasLayer


func liberer_carton_final() -> void:
	if is_instance_valid(carton_final):
		carton_final.queue_free()
	carton_final = null


## Plan décrit par un objet : {"decor": id, "textures": {"Calque_x": "calques/y.png"}, "sequence": […]}.
## Le décor et les textures sont gérés par les chapitres qui savent changer de décor.
func _preparer_plan(_plan: Dictionary) -> void:
	pass


## À surcharger dans un chapitre pour ses propres commandes.
func _commande_specifique(nom: String, args: Array) -> void:
	push_warning("Commande de dialogue inconnue : @%s %s" % [nom, args])


## Le dialogue s'est terminé (« -> FIN » ou fin de nœud). Par défaut, le chapitre se termine ;
## un chapitre jouable surcharge pour revenir au jeu.
func _dialogue_fini() -> void:
	_finir()


## Lance le dialogue à un nœud donné (points d'intérêt, scènes déclenchées par le jeu).
func jouer_noeud(nom: String) -> void:
	# Un dialogue reprend après le dernier carton (la nuit après Ullanor, une relance) : le noir
	# gardé par ce carton s'efface, sinon tout se jouerait dessous.
	if is_instance_valid(carton_final):
		var c := carton_final
		carton_final = null
		var fond := c.get_child(0) as CanvasItem
		var t := c.create_tween()
		t.tween_property(fond, "modulate:a", 0.0, 0.4)
		t.tween_callback(c.queue_free)
	boite.lancer(lecteur, nom)


func _finir() -> void:
	Jeu.terminer_chapitre()
