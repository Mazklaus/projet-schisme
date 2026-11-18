class_name Chapitre
extends Node2D
## Base d'une scène de chapitre : décor 2.5D, caméra de ciné, boîte de dialogue.
##
## La scène lit son chapitre dans le Catalogue (Jeu.etat), charge le .dlg, et exécute les
## commandes du dialogue :
##   @plan <nom>          joue la séquence caméra <nom> du fichier de plans du chapitre
##   @attendre <sec>      pause
##   @lumiere <nœud> <énergie> [durée]   fait varier une Light2D enfant de la scène
##   @carton <sec> <texte…>   texte plein écran sur fond noir (cartons, échos)
##   @fin                 termine le chapitre
## Une commande inconnue est transmise à _commande_specifique(), à surcharger par chapitre.

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
	boite.fini.connect(_finir)
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
			var l := get_node_or_null(NodePath(args[0])) as Light2D
			if l:
				var t := create_tween()
				t.tween_property(l, "energy", float(args[1]), float(args[2]) if args.size() > 2 else 0.5)
				await t.finished
		"carton":
			if args.size() >= 2:
				await afficher_carton(" ".join(args.slice(1)), float(args[0]))
		"fin":
			_finir()
			return
		_:
			await _commande_specifique(nom, args)
	boite.reprendre()


## Texte plein écran sur fond noir, avec fondu. Placeholder visuel.
func afficher_carton(texte: String, duree: float) -> void:
	var couche := CanvasLayer.new()
	couche.layer = 50
	var fond := ColorRect.new()
	fond.color = Color.BLACK
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	var l := Label.new()
	l.text = texte
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.add_theme_font_size_override("font_size", 56)
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


func _finir() -> void:
	Jeu.terminer_chapitre()
