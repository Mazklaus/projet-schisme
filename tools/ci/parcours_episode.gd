extends SceneTree
## Joue un épisode de bout en bout comme un testeur automatique, chapitre après chapitre, puis
## vérifie la sauvegarde. Échoue au moindre écart ou blocage.
##
##   godot --headless -s res://tools/ci/parcours_episode.gd -- --episode=ep01 [options]
##
## Options :
##   --politique=premier|dernier|silence   option prise à chaque menu : la première, la dernière,
##                     ou rien (les menus minutés expirent, les autres prennent la dernière option)
##   --attendu=cle1,cle2…   clés qui doivent être dans la sauvegarde finale
##   --vitesse=N       accélère le temps (4 par défaut)
##   --captures=DIR    une image à chaque changement de chapitre ou de phase (avec xvfb-run)
##   --chapitre=ID     commencer à ce chapitre (les chapitres d'avant ne sont pas exigés)
##   --importer=N      reprendre les drapeaux de l'emplacement N (ex. sauvegarde de la tranche)

var episode := "ep01"
var politique := "premier"
var attendu: PackedStringArray = []
var vitesse := 4.0
var captures := ""
var chapitre := ""
var importer := -1
var _images := 0
var _temps := 0.0
var _etapes: Array[String] = []
var _etape := ""
var _interagir := false
var _menus := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--episode="):
			episode = a.get_slice("=", 1)
		elif a.begins_with("--politique="):
			politique = a.get_slice("=", 1)
		elif a.begins_with("--attendu="):
			attendu = a.get_slice("=", 1).split(",", false)
		elif a.begins_with("--vitesse="):
			vitesse = float(a.get_slice("=", 1))
		elif a.begins_with("--captures="):
			captures = a.get_slice("=", 1)
		elif a.begins_with("--chapitre="):
			chapitre = a.get_slice("=", 1)
		elif a.begins_with("--importer="):
			importer = int(a.get_slice("=", 1))
	Engine.time_scale = vitesse
	root.get_node(^"Sauvegarde").isoler_pour_tests()
	if importer >= 0:
		root.get_node(^"Jeu").importer.call_deferred(importer, episode, chapitre)
		return
	root.get_node(^"Sauvegarde").effacer(0)
	root.get_node(^"Jeu").nouvelle_partie.call_deferred(episode)


func _relacher() -> void:
	for a in ["gauche", "droite", "haut", "bas", "interagir"]:
		Input.action_release(a)


func _aller_vers(joueur: Node2D, cible: Vector2) -> bool:
	var d := cible - joueur.position
	_relacher()
	if absf(d.x) > 25.0:
		Input.action_press("droite" if d.x > 0 else "gauche")
	if absf(d.y) > 15.0:
		Input.action_press("bas" if d.y > 0 else "haut")
	return absf(d.x) <= 25.0 and absf(d.y) <= 15.0


func _process(delta: float) -> bool:
	_images += 1
	_temps += delta
	var jeu = root.get_node(^"Jeu")
	if _images > 60 * 60 * 30:
		printerr("Parcours bloqué : %s" % _etape)
		quit(1)
		return false
	var scene = current_scene
	if scene == null or not "phase" in scene:
		return false
	var etape := "%s/%s" % [jeu.etat.chapitre, scene.phase]
	if scene.phase == "jeu":
		etape += ":" + scene.zone
	if etape != _etape:
		_etape = etape
		_etapes.append(etape)
		print("[%6.1f s] %s" % [_temps, etape])
		if not captures.is_empty():
			root.get_texture().get_image().save_png("%s/%03d_%s.png" % [captures, _etapes.size(), etape.replace("/", "_").replace(":", "_")])
	if scene.phase == "ecran_fin":
		if scene.ecran_fin != null and scene.ecran_fin.modulate.a >= 1.0:
			return _verifier(jeu, scene)
		return false
	scene.camera.passer()
	var boite = scene.boite
	var boutons: Array = boite.find_children("*", "Button", true, false)
	if not boutons.is_empty():
		_relacher()
		var minute: bool = boite._delai_total > 0.0
		if politique == "silence" and minute:
			return false
		_menus += 1
		boite._choisir(0 if politique == "premier" else boutons.size() - 1)
		return false
	if boite.visible:
		_relacher()
		if _images % 4 == 0:
			var e := InputEventAction.new()
			e.action = "avancer"
			e.pressed = true
			Input.parse_input_event(e)
		return false
	var joueur: Node2D = scene.joueur
	match scene.phase:
		"jeu":
			_explorer(scene, joueur)
		"libre":
			# QTE de la tranche : soulever la poutre (sauf en silence : ne rien faire).
			if politique == "silence":
				_relacher()
			elif joueur.distance_sol(scene.POUTRE) < scene.QTE_DISTANCE * 0.6:
				_relacher()
				Input.action_press("interagir")
			else:
				_aller_vers(joueur, scene.POUTRE + Vector2(60, 0))
		_:
			_relacher()
	return false


## Visite les points d'intérêt encore lisibles, de gauche à droite, puis avance vers la droite
## (déclencheurs, éboulement).
func _explorer(scene, joueur: Node2D) -> void:
	if _interagir:
		Input.action_release("interagir")
		_interagir = false
		return
	var restants: Array = scene.pois.keys().filter(func(p): return scene.poi_disponible(p) and not scene.pois_vus.has(p))
	restants.sort_custom(func(a, b): return scene.pois[a].x < scene.pois[b].x)
	if not restants.is_empty():
		var p: String = restants[0]
		if scene.poi_proche() == p:
			_relacher()
			Input.action_press("interagir")
			_interagir = true
		else:
			_aller_vers(joueur, scene.pois[p])
		return
	_aller_vers(joueur, Vector2(joueur.limites.end.x, joueur.position.y))


func _verifier(jeu, scene) -> bool:
	var erreurs: Array[String] = []
	var sauve: Dictionary = root.get_node(^"Sauvegarde").lire(0)
	if not jeu.etat.episodes_termines.has(episode):
		erreurs.append("épisode %s non marqué terminé" % episode)
	if sauve.is_empty():
		erreurs.append("aucune sauvegarde")
	else:
		for cle in attendu:
			if not sauve.drapeaux.has(cle):
				erreurs.append("%s absent de la sauvegarde" % cle)
	var exiges := chapitre.is_empty()
	for c in root.get_node(^"Catalogue").episode(episode).chapitres:
		exiges = exiges or c.id == chapitre
		if exiges and not _etapes.any(func(e: String): return e.begins_with(c.id + "/")):
			erreurs.append("chapitre %s jamais joué" % c.id)
	print("Épisode %s, politique %s : %.0f s de jeu simulé, %d menus ; drapeaux : %s" % [
		episode, politique, _temps, _menus, sauve.get("drapeaux", {})])
	for e in erreurs:
		printerr("ÉCHEC : ", e)
	quit(1 if not erreurs.is_empty() else 0)
	return false
