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
	if infos.has("plans"):
		var p = JSON.parse_string(FileAccess.get_file_as_string(infos.plans))
		if typeof(p) == TYPE_DICTIONARY:
			plans = p
	boite.commande.connect(_executer)
	boite.fini.connect(_dialogue_fini)
	if infos.has("dialogue"):
		var d := FormatDialogue.charger(infos.dialogue)
		for err in d.erreurs:
			push_error("%s : %s" % [infos.dialogue, err])
		lecteur = LecteurDialogue.new(d, Jeu.etat.drapeaux)
		lecteur.noeud_entre.connect(func(n): Jeu.etat.noeud_dialogue = n)
		var depart: String = Jeu.etat.noeud_dialogue
		if depart.is_empty() or not d.noeuds.has(depart):
			depart = d.ordre[0] if not d.ordre.is_empty() else FormatDialogue.FIN
		boite.lancer(lecteur, depart)


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
##   @sauver                         sauvegarde l'état de la partie
##   @fin                            termine le chapitre
## Les chemins de nœuds sont relatifs à la scène de chapitre.
func executer_commande(nom: String, args: Array) -> void:
	match nom:
		"plan":
			var p: Array = plans.get(args[0] if not args.is_empty() else "", [])
			if p.is_empty():
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
				await afficher_carton(" ".join(args.slice(1)), float(args[0]), nom == "carton")
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
		"sauver":
			Jeu.sauver()
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


## Texte plein écran (sur fond noir, ou sur l'image), avec fondu. Placeholder visuel.
func afficher_carton(texte: String, duree: float, fond_noir := true) -> void:
	var couche := CanvasLayer.new()
	couche.layer = 50
	var fond := ColorRect.new()
	fond.color = Color.BLACK if fond_noir else Color(0, 0, 0, 0)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	var l := Label.new()
	l.text = texte
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.add_theme_font_size_override("font_size", 56)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 0 if fond_noir else 10)
	fond.add_child(l)
	couche.add_child(fond)
	add_child(couche)
	fond.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(fond, "modulate:a", 1.0, 0.4)
	t.tween_interval(maxf(duree - 0.8, 0.0))
	t.tween_property(fond, "modulate:a", 0.0, 0.4)
	await t.finished
	couche.queue_free()


## À surcharger dans un chapitre pour ses propres commandes.
func _commande_specifique(nom: String, args: Array) -> void:
	push_warning("Commande de dialogue inconnue : @%s %s" % [nom, args])


## Le dialogue s'est terminé (« -> FIN » ou fin de nœud). Par défaut, le chapitre se termine ;
## un chapitre jouable surcharge pour revenir au jeu.
func _dialogue_fini() -> void:
	_finir()


## Lance le dialogue à un nœud donné (points d'intérêt, scènes déclenchées par le jeu).
func jouer_noeud(nom: String) -> void:
	boite.lancer(lecteur, nom)


func _finir() -> void:
	Jeu.terminer_chapitre()
