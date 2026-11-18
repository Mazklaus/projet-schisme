extends Node
## Catalogue des épisodes (autoload « Catalogue »).
##
## Un épisode = un dossier res://data/episodes/<id>/ avec un episode.json :
##   {"id": "ep01_isstvan", "numero": 1, "titre": "…", "chapitres": [
##     {"id": "c01", "titre": "…", "scene": "res://…tscn", "dialogue": "res://…dlg"}]}
##
## Les épisodes livrés après le jeu de base arrivent en paquets .pck dans le dossier
## « episodes » à côté de l'exécutable : ils sont montés au démarrage, puis leurs dossiers
## data/episodes/<id>/ apparaissent dans res:// comme ceux du jeu de base.

const DOSSIER_EPISODES := "res://data/episodes"
const DOSSIER_PAQUETS := "episodes"

## id → dictionnaire de l'épisode, triés par numéro dans `ordre`.
var episodes: Dictionary = {}
var ordre: PackedStringArray = []
var paquets_montes: PackedStringArray = []


func _ready() -> void:
	monter_paquets()
	recharger()


## Monte les .pck d'épisodes trouvés à côté de l'exécutable (jeu exporté seulement).
func monter_paquets() -> void:
	if OS.has_feature("editor"):
		return
	var dossier := OS.get_executable_path().get_base_dir().path_join(DOSSIER_PAQUETS)
	var dir := DirAccess.open(dossier)
	if dir == null:
		return
	for f in dir.get_files():
		if f.get_extension() == "pck" and ProjectSettings.load_resource_pack(dossier.path_join(f), false):
			paquets_montes.append(f)


func recharger(dossier := DOSSIER_EPISODES) -> void:
	episodes.clear()
	var liste: Array[Dictionary] = []
	var dir := DirAccess.open(dossier)
	if dir == null:
		push_warning("Aucun dossier d'épisodes : " + dossier)
		ordre = []
		return
	for sous in dir.get_directories():
		var ep := lire_episode(dossier.path_join(sous).path_join("episode.json"))
		if not ep.is_empty():
			liste.append(ep)
	liste.sort_custom(func(a, b): return int(a.numero) < int(b.numero))
	ordre = []
	for ep in liste:
		episodes[ep.id] = ep
		# Un épisode « cache » (démo technique) reste jouable par son id mais n'entre pas
		# dans l'enchaînement ni dans le menu.
		if not ep.get("cache", false):
			ordre.append(ep.id)


## Lit et valide un episode.json. Renvoie {} (avec un avertissement) s'il est invalide.
static func lire_episode(chemin: String) -> Dictionary:
	if not FileAccess.file_exists(chemin):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	var erreurs := valider_episode(d)
	if not erreurs.is_empty():
		push_warning("%s invalide : %s" % [chemin, ", ".join(erreurs)])
		return {}
	return d


static func valider_episode(d) -> PackedStringArray:
	var e: PackedStringArray = []
	if typeof(d) != TYPE_DICTIONARY:
		return PackedStringArray(["pas un objet JSON"])
	for cle in ["id", "numero", "titre", "chapitres"]:
		if not d.has(cle):
			e.append("clé « %s » absente" % cle)
	if not e.is_empty():
		return e
	if typeof(d.chapitres) != TYPE_ARRAY or d.chapitres.is_empty():
		e.append("aucun chapitre")
		return e
	var ids := {}
	for c in d.chapitres:
		if typeof(c) != TYPE_DICTIONARY or not c.has("id") or not c.has("scene"):
			e.append("chapitre sans id ou sans scène")
			continue
		if ids.has(c.id):
			e.append("chapitre « %s » en double" % c.id)
		ids[c.id] = true
	return e


func episode(id: String) -> Dictionary:
	return episodes.get(id, {})


func chapitre(id_episode: String, id_chapitre: String) -> Dictionary:
	for c in episode(id_episode).get("chapitres", []):
		if c.id == id_chapitre:
			return c
	return {}


## Chapitre qui suit, éventuellement dans l'épisode suivant. {} à la fin du dernier épisode.
## Renvoie {"episode": id, "chapitre": id}.
func suivant(id_episode: String, id_chapitre: String) -> Dictionary:
	var chapitres: Array = episode(id_episode).get("chapitres", [])
	for i in chapitres.size():
		if chapitres[i].id == id_chapitre and i + 1 < chapitres.size():
			return {"episode": id_episode, "chapitre": chapitres[i + 1].id}
	var j := ordre.find(id_episode)
	if j >= 0 and j + 1 < ordre.size():
		var ep_suivant: Dictionary = episodes[ordre[j + 1]]
		return {"episode": ep_suivant.id, "chapitre": ep_suivant.chapitres[0].id}
	return {}
