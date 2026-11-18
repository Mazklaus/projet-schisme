extends SceneTree
## Parcourt l'épisode de démo de bout en bout, comme un joueur pressé, et échoue à la moindre
## erreur. Lancé par la CI (headless) :
##   godot --headless -s res://tools/ci/parcours_demo.gd [-- --choix=0|1|attendre] [--capture=chemin.png]
## « attendre » laisse expirer le choix minuté. --capture enregistre une image du décor
## (nécessite un affichage, par exemple xvfb-run, sans --headless).

var choix := "0"
var capture := ""
var _images := 0
var _capture_faite := false
const LIMITE_IMAGES := 60 * 120


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--choix="):
			choix = a.get_slice("=", 1)
		elif a.begins_with("--capture="):
			capture = a.get_slice("=", 1)
	root.get_node(^"Sauvegarde").isoler_pour_tests()
	root.get_node(^"Sauvegarde").effacer(0)
	root.get_node(^"Jeu").nouvelle_partie.call_deferred("ep00_prologue")


func _process(_delta: float) -> bool:
	_images += 1
	var jeu = root.get_node(^"Jeu")
	if jeu.etat.episodes_termines.has("ep00_prologue"):
		print("Parcours terminé en %d images ; drapeaux : %s" % [_images, jeu.etat.drapeaux])
		quit(0)
		return false
	if _images > LIMITE_IMAGES:
		printerr("Parcours bloqué (chapitre %s, nœud %s)" % [jeu.etat.chapitre, jeu.etat.noeud_dialogue])
		quit(1)
		return false
	# Pas de type Chapitre ici : un script lancé par -s se compile avant les autoloads.
	var scene = current_scene
	if scene != null and "boite" in scene and scene.boite != null:
		# Capture à la première réplique affichée (après le carton d'ouverture).
		if not capture.is_empty() and not _capture_faite and scene.boite.visible and scene.boite._panneau.visible and scene.boite._texte.visible_ratio >= 1.0:
			_capture_faite = true
			root.get_texture().get_image().save_png(capture)
			print("Capture : ", capture)
		scene.camera.passer()
		var boite = scene.boite
		var boutons: Array = boite.find_children("*", "Button", true, false)
		if not boutons.is_empty():
			if choix != "attendre":
				boite._choisir(clampi(int(choix), 0, boutons.size() - 1))
		elif boite.visible and _images % 4 == 0:
			var e := InputEventAction.new()
			e.action = "avancer"
			e.pressed = true
			Input.parse_input_event(e)
	return false
