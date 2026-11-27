extends Node
## État de la partie en cours et enchaînement des chapitres (autoload « Jeu »).

signal chapitre_change(id_episode: String, id_chapitre: String)
signal drapeau_change(nom: String, valeur: Variant)

const MENU := "res://scenes/ui/menu_principal.tscn"

var etat: Dictionary = Sauvegarde.etat_vierge()
var emplacement_courant := 0
## Faux dans les tests : on ne change pas de scène.
var changer_de_scene := true


func nouvelle_partie(id_episode := "") -> void:
	etat = Sauvegarde.etat_vierge()
	if id_episode.is_empty() and not Catalogue.ordre.is_empty():
		id_episode = Catalogue.ordre[0]
	var ep := Catalogue.episode(id_episode)
	if ep.is_empty():
		push_error("Épisode inconnu : " + id_episode)
		return
	# Sans sauvegarde importée, l'épisode part de son état par défaut : les choix les plus
	# neutres des épisodes précédents (systeme-de-choix.md §6).
	etat.drapeaux = etat_defaut(id_episode)
	aller_au_chapitre(id_episode, ep.chapitres[0].id)


## Démarre un épisode (éventuellement à un chapitre donné) avec les drapeaux d'une sauvegarde
## existante : import d'un épisode à l'autre (systeme-de-choix.md §6), ou test d'un chapitre
## à partir de la sauvegarde de la tranche. Les clés locales d'autres épisodes sont purgées.
func importer(emplacement: int, id_episode: String, id_chapitre := "") -> bool:
	var d := Sauvegarde.lire(emplacement)
	var ep := Catalogue.episode(id_episode)
	if d.is_empty() or ep.is_empty():
		push_error("Import impossible : emplacement %d, épisode %s" % [emplacement, id_episode])
		return false
	etat = Sauvegarde.etat_vierge()
	etat.drapeaux.merge(etat_defaut(id_episode))
	var prefixe := id_episode.get_slice("_", 0) + "_"
	for cle in d.drapeaux:
		if not RegEx.create_from_string("^ep[0-9]{2,3}_").search(cle) or cle.begins_with(prefixe):
			etat.drapeaux[cle] = d.drapeaux[cle]
	etat.episodes_termines = d.get("episodes_termines", [])
	aller_au_chapitre(id_episode, id_chapitre if not id_chapitre.is_empty() else ep.chapitres[0].id)
	return true


## Drapeaux de data/episodes/<id>/etat_defaut.json, ou de data/episodes/epNN/ (préfixe de
## l'id) tant que l'épisode n'a pas son dossier ; {} si absent.
static func etat_defaut(id_episode: String) -> Dictionary:
	var chemin := "%s/%s/etat_defaut.json" % [Catalogue.DOSSIER_EPISODES, id_episode]
	if not FileAccess.file_exists(chemin):
		chemin = "%s/%s/etat_defaut.json" % [Catalogue.DOSSIER_EPISODES, id_episode.get_slice("_", 0)]
	if not FileAccess.file_exists(chemin):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	if typeof(d) != TYPE_DICTIONARY or typeof(d.get("drapeaux")) != TYPE_DICTIONARY:
		push_error("État par défaut illisible : " + chemin)
		return {}
	return d.drapeaux.duplicate(true)


func charger(emplacement: int) -> bool:
	var d := Sauvegarde.lire(emplacement)
	if d.is_empty() or Catalogue.chapitre(d.episode, d.chapitre).is_empty():
		return false
	etat = d
	emplacement_courant = emplacement
	aller_au_chapitre(d.episode, d.chapitre, d.noeud_dialogue)
	return true


func sauver(emplacement := emplacement_courant) -> Error:
	emplacement_courant = emplacement
	return Sauvegarde.ecrire(emplacement, etat)


func aller_au_chapitre(id_episode: String, id_chapitre: String, noeud := "") -> void:
	var c := Catalogue.chapitre(id_episode, id_chapitre)
	if c.is_empty():
		push_error("Chapitre inconnu : %s/%s" % [id_episode, id_chapitre])
		return
	etat.episode = id_episode
	etat.chapitre = id_chapitre
	etat.noeud_dialogue = noeud
	chapitre_change.emit(id_episode, id_chapitre)
	if changer_de_scene:
		get_tree().change_scene_to_file.call_deferred(c.scene)


## Appelé par la scène de chapitre quand elle est finie.
func terminer_chapitre() -> void:
	var s := clore_chapitre()
	if s.is_empty():
		if changer_de_scene:
			get_tree().change_scene_to_file.call_deferred(MENU)
		return
	aller_au_chapitre(s.episode, s.chapitre)
	sauver()


## Marque l'épisode terminé s'il s'achève avec ce chapitre et renvoie le chapitre suivant
## ({} en fin de jeu, partie alors sauvegardée), sans changer de scène : une scène qui
## affiche son propre écran de fin l'appelle à la place de terminer_chapitre().
func clore_chapitre() -> Dictionary:
	var s := Catalogue.suivant(etat.episode, etat.chapitre)
	if s.is_empty() or s.episode != etat.episode:
		if not etat.episodes_termines.has(etat.episode):
			etat.episodes_termines.append(etat.episode)
	if s.is_empty():
		sauver()
	return s


func drapeau(nom: String, defaut: Variant = false) -> Variant:
	return etat.drapeaux.get(nom, defaut)


func poser_drapeau(nom: String, valeur: Variant = true) -> void:
	etat.drapeaux[nom] = valeur
	drapeau_change.emit(nom, valeur)
