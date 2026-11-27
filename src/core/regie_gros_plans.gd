class_name RegieGrosPlans
extends RefCounted
## Régie automatique des gros plans de dialogue (règle du GD, 27/11). Pour chaque réplique d'une
## scène décrite dans gros_plans.json, elle décide « large » ou le gros plan du locuteur :
##   1. Plan d'ouverture : la première réplique d'une scène, et toute réplique après un choix ou
##      une ligne du narrateur, reste en plan large.
##   2. Règle des 180° : chaque personnage garde son côté (« cotes » de la scène).
##   3. Pas de ping-pong : une réplique courte (< DUREE_MIN_S) garde le plan en cours ; après
##      MAX_SERRES gros plans d'affilée, un plan large pour respirer.
##   4. Surcharge : « @plan large », « @plan serre » ou « @plan serre:<perso> » priment, pour la
##      réplique suivante.
## Sans buste livré pour le locuteur (CA1), le plan reste large : la régie est inerte.

const DUREE_MIN_S := 2.0
## Vitesse de lecture estimée pour la durée d'une réplique (caractères par seconde).
const LECTURE_CPS := 15.0
const MAX_SERRES := 4
const DOSSIER_PERSOS := "res://assets/personnages"

var scenes: Array = []
var scene: Dictionary = {}
## Plan en cours : "large" ou le nom du personnage en gros plan.
var plan := "large"
var _serres_daffilee := 0
var _ouverture := true
var _surcharge := ""
## Côté du gros plan en cours quand il vient d'une surcharge (personnage hors « cotes »).
var _cote_impose := ""


func _init(config: Variant = null) -> void:
	if typeof(config) == TYPE_DICTIONARY:
		scenes = config.get("scenes", [])


static func charger(chemin: String) -> RegieGrosPlans:
	if not FileAccess.file_exists(chemin):
		return RegieGrosPlans.new()
	return RegieGrosPlans.new(JSON.parse_string(FileAccess.get_file_as_string(chemin)))


## Scène de gros plans d'un nœud pour un chapitre ({} : aucune).
func scene_du_noeud(chapitre: String, noeud: String) -> Dictionary:
	for s in scenes:
		if typeof(s) != TYPE_DICTIONARY or String(s.get("chapitre", chapitre)) != chapitre:
			continue
		for motif in s.get("noeuds", []):
			if noeud.match(String(motif)):
				return s
	return {}


## Entrée dans un nœud : changer de scène remet le plan d'ouverture.
func entrer(chapitre: String, noeud: String) -> void:
	var s := scene_du_noeud(chapitre, noeud)
	if s != scene:
		scene = s
		plan = "large"
		_serres_daffilee = 0
		_ouverture = true


## « @plan large | serre | serre:<perso> » : vaut pour la réplique suivante.
func surcharger(valeur: String) -> void:
	_surcharge = valeur


static func est_surcharge(nom_plan: String) -> bool:
	return nom_plan == "large" or nom_plan == "serre" or nom_plan.begins_with("serre:")


## Côté où afficher le personnage du plan en cours.
func cote_du_plan() -> String:
	return _cote_impose if not _cote_impose.is_empty() else cote(plan)


func cote(perso: String) -> String:
	return String(scene.get("cotes", {}).get(perso.to_upper(), ""))


## Côté d'un gros plan imposé par « @plan serre:<perso> » : celui de la scène, sinon la gauche.
func cote_surcharge(perso: String) -> String:
	var c := cote(perso)
	return c if not c.is_empty() else "gauche"


## Un plan nommé (caméra du .dlg) ramène au plan large ; la règle reprend à la réplique suivante.
func plan_nomme() -> void:
	plan = "large"
	_serres_daffilee = 0


static func chemin_buste(perso: String, cote_perso: String) -> String:
	var dossier := DOSSIER_PERSOS.path_join(perso.to_lower())
	var propre := dossier.path_join("buste_%s.png" % cote_perso)
	return propre if ResourceLoader.exists(propre) else dossier.path_join("buste.png")


func buste_existe(perso: String, cote_perso: String) -> bool:
	return ResourceLoader.exists(chemin_buste(perso, cote_perso))


func peut_serrer(perso: String) -> bool:
	return not scene.is_empty() and not cote(perso).is_empty() and buste_existe(perso, cote(perso))


static func duree_lecture(texte: String) -> float:
	return texte.length() / LECTURE_CPS


## Décide le plan d'un évènement de dialogue ({type, personnage, humeur, texte}) et le renvoie.
func decider(e: Dictionary) -> String:
	if scene.is_empty():
		_surcharge = ""
		return plan
	if e.get("type", "") != "replique":
		# Un choix : retour au large, et la réplique suivante reste en ouverture.
		plan = "large"
		_serres_daffilee = 0
		_ouverture = true
		return plan
	var perso := String(e.get("personnage", ""))
	var narrateur: bool = perso.is_empty() or e.get("humeur", "") == "vox"
	if not _surcharge.is_empty():
		var s := _surcharge
		_surcharge = ""
		var cible: String = perso if s == "serre" else s.trim_prefix("serre:").to_upper() if s.begins_with("serre:") else ""
		_ouverture = false
		if cible.is_empty() or not buste_existe(cible, cote_surcharge(cible)):
			plan = "large"
			_serres_daffilee = 0
		else:
			plan = cible
			_cote_impose = cote_surcharge(cible)
			_serres_daffilee += 1
		return plan
	if narrateur:
		plan = "large"
		_serres_daffilee = 0
		_ouverture = true
		return plan
	if _ouverture:
		_ouverture = false
		plan = "large"
		_serres_daffilee = 0
		return plan
	# Réplique courte : on garde le plan en cours.
	if duree_lecture(String(e.get("texte", ""))) < DUREE_MIN_S:
		return plan
	if not peut_serrer(perso) or _serres_daffilee >= MAX_SERRES:
		plan = "large"
		_serres_daffilee = 0
		return plan
	plan = perso
	_cote_impose = ""
	_serres_daffilee += 1
	return plan
