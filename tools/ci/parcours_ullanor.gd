extends SceneTree
## Joue la tranche verticale d'Ullanor de bout en bout comme un testeur automatique, puis
## vérifie la sauvegarde (critères QA de game-design-tv.md). Échoue au moindre écart.
##
##   godot --headless -s res://tools/ci/parcours_ullanor.gd -- --choix=<branche> [options]
##
## Branches : sortir | auxiliaires | obeir (option choisie) | silence (QTE puis aucune réponse
## pendant 8 s) | rassemblement (passe sans s'arrêter) | inaction (ne fait rien après le rappel).
## Options :
##   --sans-poi        ne visite pas les 3 points d'intérêt
##   --flaner          traîne au départ pour déclencher la relance vox de Dremm (30 s)
##   --immobile        ne bouge jamais avant l'éboulement : invite de déplacement, relance,
##                     puis la caméra va montrer l'éboulement (filet de sécurité)
##   --vitesse=N       accélère le temps (4 par défaut ; 1 pour mesurer la durée réelle)
##   --cine            laisse jouer les plans caméra au lieu de les passer
##   --captures=DIR    une image à chaque changement de phase (avec xvfb-run, sans --headless)
##   --rafale=S        avec --captures : une image de plus toutes les S secondes de jeu

const ATTENDU := {
	"sortir": {"choix_ep01_ullanor": 1, "vivant_ilse": true, "connait_ilse_sauveur": true,
		"relation_dremm": -1, "relation_ilse": 2, "trait_compassion": 1},
	"auxiliaires": {"choix_ep01_ullanor": 2, "vivant_ilse": true, "connait_ilse_sauveur": false,
		"relation_dremm": 0, "relation_ilse": 0},
	"obeir": {"choix_ep01_ullanor": 3, "vivant_ilse": false, "relation_dremm": 1, "relation_ilse": 0,
		"trait_obeissance": 1},
}
const OPTION := {"sortir": 0, "auxiliaires": 1, "obeir": 2}

var choix := "sortir"
var poi := true
var flaner := false
var immobile := false
var cine := false
var captures := ""
var vitesse := 4.0
var rafale := 0.0
var _prochaine_rafale := 0.0
var _images := 0
var _temps_jeu := 0.0
var _phase := ""
var _phases: Array[String] = []
var _pois_restants: Array = []
var _interagir_relache := false
var _relance_vue := false
var _pois_vus := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--choix="):
			choix = a.get_slice("=", 1)
		elif a == "--sans-poi":
			poi = false
		elif a == "--flaner":
			flaner = true
		elif a == "--immobile":
			immobile = true
		elif a == "--cine":
			cine = true
		elif a.begins_with("--vitesse="):
			vitesse = float(a.get_slice("=", 1))
		elif a.begins_with("--rafale="):
			rafale = float(a.get_slice("=", 1))
		elif a.begins_with("--captures="):
			captures = a.get_slice("=", 1)
	if choix not in ["sortir", "auxiliaires", "obeir", "silence", "rassemblement", "inaction"]:
		printerr("Branche inconnue : ", choix)
		quit(2)
		return
	Engine.time_scale = vitesse
	root.get_node(^"Sauvegarde").isoler_pour_tests()
	root.get_node(^"Sauvegarde").effacer(0)
	root.get_node(^"Jeu").nouvelle_partie.call_deferred("ep01_ullanor")


func _relacher_tout() -> void:
	for a in ["gauche", "droite", "haut", "bas", "interagir"]:
		Input.action_release(a)


func _aller_vers(joueur: Node2D, cible: Vector2) -> bool:
	var d := cible - joueur.position
	_relacher_tout()
	if absf(d.x) > 25.0:
		Input.action_press("droite" if d.x > 0 else "gauche")
	if absf(d.y) > 15.0:
		Input.action_press("bas" if d.y > 0 else "haut")
	return absf(d.x) <= 25.0 and absf(d.y) <= 15.0


func _process(delta: float) -> bool:
	_images += 1
	_temps_jeu += delta
	var jeu = root.get_node(^"Jeu")
	if _images > 60 * 60 * 10:
		printerr("Parcours bloqué en phase « %s »" % _phase)
		quit(1)
		return false
	var scene = current_scene
	if scene == null or not "phase" in scene:
		return false
	if scene.phase != _phase:
		_phase = scene.phase
		_phases.append(_phase)
		print("[%5.1f s] phase %s" % [_temps_jeu, _phase])
		if _phase == "jeu":
			_pois_restants = scene.pois.keys() if poi else []
		if not captures.is_empty():
			root.get_texture().get_image().save_png("%s/%02d_%s.png" % [captures, _phases.size(), _phase])
	if rafale > 0.0 and not captures.is_empty() and _temps_jeu >= _prochaine_rafale:
		_prochaine_rafale = _temps_jeu + rafale
		root.get_texture().get_image().save_png("%s/r%05.1f_%s.png" % [captures, _temps_jeu, _phase])
	if _phase == "ecran_fin":
		# Laisser l'écran de fin apparaître (capture), puis vérifier.
		if scene.ecran_fin == null or scene.ecran_fin.modulate.a < 1.0:
			return false
		if not captures.is_empty():
			root.get_texture().get_image().save_png("%s/%02d_ecran_fin_affiche.png" % [captures, _phases.size()])
		return _verifier(jeu, scene)
	_pois_vus = scene.pois_vus.size()
	if not cine:
		scene.camera.passer()
	if scene.relance_faite and not _relance_vue:
		_relance_vue = true
		print("[%5.1f s] relance vox de Dremm" % _temps_jeu)
	# Boîte de dialogue : avancer les répliques, répondre au choix minuté.
	var boite = scene.boite
	var boutons: Array = boite.find_children("*", "Button", true, false)
	if not boutons.is_empty():
		_relacher_tout()
		if OPTION.has(choix):
			boite._choisir(OPTION[choix])
		return false
	if boite.visible:
		_relacher_tout()
		if _images % 4 == 0:
			var e := InputEventAction.new()
			e.action = "avancer"
			e.pressed = true
			Input.parse_input_event(e)
		return false
	var joueur: Node2D = scene.joueur
	match scene.phase:
		"jeu":
			if immobile or (flaner and not scene.relance_faite):
				_relacher_tout()
			elif not _pois_restants.is_empty():
				var p: String = _pois_restants[0]
				if _interagir_relache:
					Input.action_release("interagir")
					_interagir_relache = false
				elif scene.poi_proche() == p:
					_relacher_tout()
					Input.action_press("interagir")
					_interagir_relache = true
					_pois_restants.pop_front()
				else:
					_aller_vers(joueur, scene.pois[p])
			else:
				_aller_vers(joueur, Vector2(scene.EBOULEMENT_X + 60, 900))
		"libre":
			if choix == "rassemblement":
				_aller_vers(joueur, Vector2(scene.RASSEMBLEMENT_X + 40, 900))
			elif choix == "inaction":
				_relacher_tout()
			elif joueur.distance_sol(scene.POUTRE) < scene.QTE_DISTANCE * 0.6:
				_relacher_tout()
				Input.action_press("interagir")
			else:
				_aller_vers(joueur, scene.POUTRE + Vector2(60, 0))
		_:
			_relacher_tout()
	return false


func _verifier(jeu, scene) -> bool:
	var attendu: Dictionary = ATTENDU.get(choix, ATTENDU.obeir)
	var sauve: Dictionary = root.get_node(^"Sauvegarde").lire(0)
	var erreurs: Array[String] = []
	if not jeu.etat.episodes_termines.has("ep01_ullanor"):
		erreurs.append("épisode non marqué terminé")
	if sauve.is_empty():
		erreurs.append("aucune sauvegarde")
	else:
		var dr: Dictionary = sauve.drapeaux
		for cle in attendu:
			if not dr.has(cle):
				erreurs.append("%s absent de la sauvegarde" % cle)
			elif typeof(attendu[cle]) == TYPE_BOOL and bool(dr[cle]) != attendu[cle]:
				erreurs.append("%s = %s (attendu %s)" % [cle, dr[cle], attendu[cle]])
			elif typeof(attendu[cle]) == TYPE_INT and int(dr[cle]) != attendu[cle]:
				erreurs.append("%s = %s (attendu %s)" % [cle, dr[cle], attendu[cle]])
	for p in ["cine", "jeu", "eboulement", "libre", "choix", "fin", "ecran_fin"]:
		if choix == "rassemblement" or choix == "inaction":
			if p == "choix":
				continue
		if not _phases.has(p):
			erreurs.append("phase « %s » jamais atteinte" % p)
	if poi and _pois_vus != 3:
		erreurs.append("%d point(s) d'intérêt visité(s) sur 3" % _pois_vus)
	if (flaner or immobile) and not _relance_vue:
		erreurs.append("relance vox de Dremm absente")
	if immobile and not scene.glissement_fait:
		erreurs.append("la caméra n'est pas allée montrer l'éboulement")
	if immobile and not scene.aide_vue:
		erreurs.append("invite de déplacement jamais affichée")
	if not immobile and not flaner and scene.glissement_fait:
		erreurs.append("filet de sécurité déclenché alors que le joueur avançait")
	var rappel: Label = scene.ecran_fin.find_child("Rappel", true, false)
	var attendu_rappel: String = scene.RAPPEL_CHOIX[int(attendu.choix_ep01_ullanor)]
	if rappel == null or rappel.text != attendu_rappel:
		erreurs.append("écran de fin : rappel « %s » (attendu « %s »)" % [rappel.text if rappel else "", attendu_rappel])
	print("Points d'intérêt vus : %d/3" % _pois_vus)
	print("Branche %s : %.0f s de jeu simulé (vitesse ×%.0f, cinés %s) ; drapeaux : %s" % [
		choix, _temps_jeu, vitesse, "jouées" if cine else "passées", sauve.get("drapeaux", {})])
	for e in erreurs:
		printerr("ÉCHEC : ", e)
	quit(1 if not erreurs.is_empty() else 0)
	return false
