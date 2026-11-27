extends Node
## Sauvegardes versionnées (autoload « Sauvegarde »).
##
## Une sauvegarde est un fichier JSON par emplacement : user://sauvegardes/emplacement_<n>.json.
## Elle porte toujours le numéro de schéma VERSION. À la lecture, une sauvegarde ancienne passe
## par les migrations successives (v1 → v2 → … → VERSION), ce qui permet de livrer un nouvel
## épisode sans casser les parties des épisodes précédents.
##
## Pour changer le format : incrémenter VERSION, puis ajouter _migrer_vers_<VERSION>(donnees)
## qui transforme un dictionnaire de la version précédente. Ne jamais modifier une migration
## déjà livrée. Une sauvegarde plus récente que le jeu est refusée (pas de perte silencieuse).

signal sauvegardee(emplacement: int)

const VERSION := 2
## v2 : clés de la tranche renommées selon systeme-de-choix.md §6.
const RENOMMAGES_V2 := {
	"choix_ullanor": "choix_ep01_ullanor",
	"soldate_vivante": "vivant_ilse",
	"soldate_connait_sauveur": "connait_ilse_sauveur",
}
const NB_EMPLACEMENTS := 6
const DOSSIER_DEFAUT := "user://sauvegardes"

var dossier := DOSSIER_DEFAUT


## Nouvel état de partie, au format courant.
static func etat_vierge() -> Dictionary:
	return {
		"version": VERSION,
		"episode": "",
		"chapitre": "",
		"noeud_dialogue": "",
		## Drapeaux narratifs (choix faits, personnages rencontrés…), partagés entre épisodes.
		"drapeaux": {},
		"episodes_termines": [],
		"horodatage": 0,
	}


func chemin(emplacement: int) -> String:
	return "%s/emplacement_%d.json" % [dossier, emplacement]


func existe(emplacement: int) -> bool:
	return FileAccess.file_exists(chemin(emplacement))


## Écrit l'état sur disque. L'écriture passe par un fichier temporaire puis un renommage, pour
## qu'un plantage pendant l'écriture ne détruise pas la sauvegarde précédente.
func ecrire(emplacement: int, etat: Dictionary) -> Error:
	assert(emplacement >= 0 and emplacement < NB_EMPLACEMENTS)
	var err := DirAccess.make_dir_recursive_absolute(dossier)
	if err != OK:
		return err
	var donnees := etat.duplicate(true)
	donnees["version"] = VERSION
	donnees["horodatage"] = int(Time.get_unix_time_from_system())
	var cible := chemin(emplacement)
	var temporaire := cible + ".tmp"
	var f := FileAccess.open(temporaire, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(donnees, "\t"))
	f.close()
	err = DirAccess.rename_absolute(temporaire, cible)
	if err == OK:
		sauvegardee.emit(emplacement)
	return err


## Lit et migre une sauvegarde. Renvoie {} si l'emplacement est vide, illisible ou trop récent.
func lire(emplacement: int) -> Dictionary:
	if not existe(emplacement):
		return {}
	var texte := FileAccess.get_file_as_string(chemin(emplacement))
	# JSON.new().parse() plutôt que parse_string() : un fichier corrompu ne doit pas
	# lever d'erreur moteur, seulement être ignoré.
	var json := JSON.new()
	var donnees = json.data if json.parse(texte) == OK else null
	if typeof(donnees) != TYPE_DICTIONARY:
		push_warning("Sauvegarde %d illisible" % emplacement)
		return {}
	return migrer(donnees)


func effacer(emplacement: int) -> void:
	if existe(emplacement):
		DirAccess.remove_absolute(chemin(emplacement))


## Amène un dictionnaire de n'importe quelle version connue au format courant.
func migrer(donnees: Dictionary) -> Dictionary:
	var v := int(donnees.get("version", 0))
	if v > VERSION:
		push_warning("Sauvegarde en version %d, plus récente que le jeu (%d) : ignorée" % [v, VERSION])
		return {}
	if v < 1:
		push_warning("Sauvegarde sans numéro de version : ignorée")
		return {}
	var d := donnees.duplicate(true)
	while v < VERSION:
		v += 1
		var methode := "_migrer_vers_%d" % v
		assert(has_method(methode), "Migration manquante : " + methode)
		d = call(methode, d)
		d["version"] = v
	# Complète les clés absentes (ajoutées sans migration, avec une valeur par défaut neutre).
	var vierge := etat_vierge()
	for cle in vierge:
		if not d.has(cle):
			d[cle] = vierge[cle]
	return d


func _migrer_vers_2(d: Dictionary) -> Dictionary:
	var dr: Dictionary = d.get("drapeaux", {})
	for ancien in RENOMMAGES_V2:
		if dr.has(ancien):
			dr[RENOMMAGES_V2[ancien]] = dr[ancien]
			dr.erase(ancien)
	d["drapeaux"] = dr
	return d


## Résumé affichable dans le menu de chargement.
func resume(emplacement: int) -> Dictionary:
	var d := lire(emplacement)
	if d.is_empty():
		return {}
	return {"episode": d.episode, "chapitre": d.chapitre, "horodatage": d.horodatage}


## Utilisé par tests/pre_run.gd : les tests n'écrivent jamais dans les vraies sauvegardes.
func isoler_pour_tests() -> void:
	dossier = "user://tests_sauvegardes"
