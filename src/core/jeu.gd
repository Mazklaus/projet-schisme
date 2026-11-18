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
	aller_au_chapitre(id_episode, ep.chapitres[0].id)


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
	var s := Catalogue.suivant(etat.episode, etat.chapitre)
	if s.is_empty() or s.episode != etat.episode:
		if not etat.episodes_termines.has(etat.episode):
			etat.episodes_termines.append(etat.episode)
	if s.is_empty():
		if changer_de_scene:
			get_tree().change_scene_to_file.call_deferred(MENU)
		return
	aller_au_chapitre(s.episode, s.chapitre)
	sauver()


func drapeau(nom: String, defaut: Variant = false) -> Variant:
	return etat.drapeaux.get(nom, defaut)


func poser_drapeau(nom: String, valeur: Variant = true) -> void:
	etat.drapeaux[nom] = valeur
	drapeau_change.emit(nom, valeur)
