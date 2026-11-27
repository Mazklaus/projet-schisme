class_name LecteurDialogue
extends RefCounted
## Exécute un dialogue analysé par FormatDialogue, pas à pas, sans rien afficher.
##
## Usage : demarrer("debut"), puis avancer() renvoie le prochain événement :
##   {"type": "replique", "personnage", "humeur", "texte"}
##   {"type": "choix", "options": [{"texte", "index"}], "delai": s}
##        → répondre par choisir(index) ; si delai > 0 et rien n'est choisi à temps,
##          appeler expirer() (le menu saute à sa cible « *! »)
##   {"type": "commande", "nom", "args"}                  → la scène l'exécute puis rappelle avancer()
##   {"type": "fin"}
## Les sauts et les affectations sont traités en interne. Les drapeaux vivent dans le
## dictionnaire passé au constructeur (en jeu : Jeu.etat.drapeaux, donc sauvegardés).

signal noeud_entre(nom: String)

var dialogue: Dictionary
var drapeaux: Dictionary
var noeud := ""
var _index := 0
var _options: Array = []
var _menu: Dictionary = {}
## Garde-fou contre une boucle de sauts sans réplique.
const MAX_SAUTS := 1000


func _init(dialogue_analyse: Dictionary, drapeaux_partie: Dictionary = {}) -> void:
	dialogue = dialogue_analyse
	drapeaux = drapeaux_partie


func demarrer(nom: String) -> void:
	_entrer(nom)


func termine() -> bool:
	return noeud == FormatDialogue.FIN


func avancer() -> Dictionary:
	if not _options.is_empty():
		push_warning("avancer() pendant un choix : appeler choisir()")
		return _evenement_choix()
	var sauts := 0
	while not termine():
		var instructions: Array = dialogue.noeuds.get(noeud, [])
		if _index >= instructions.size():
			# Fin de nœud sans saut : le dialogue s'arrête (la narration doit écrire « -> FIN »
			# pour être explicite, mais on ne bloque pas le joueur).
			_entrer(FormatDialogue.FIN)
			break
		var instr: Dictionary = instructions[_index]
		_index += 1
		match instr.type:
			"replique":
				return {"type": "replique", "personnage": instr.personnage,
					"humeur": instr.humeur, "texte": instr.texte}
			"commande":
				return {"type": "commande", "nom": instr.nom, "args": instr.args}
			"affectation":
				# Règle du canon : pas de vivant_<perso> pour un personnage canon.
				if not Personnages.ecriture_permise(instr.nom):
					push_error("Dialogue : %s refusé, %s est un personnage canon (nœud %s)" % [
						instr.nom, String(instr.nom).trim_prefix("vivant_"), noeud])
					continue
				var v: Variant
				match instr.get("op", "="):
					"+=": v = int(drapeaux.get(instr.nom, 0)) + instr.valeur
					"-=": v = int(drapeaux.get(instr.nom, 0)) - instr.valeur
					_: v = instr.valeur
				# Relations de -3 à +3, traits de 0 à 10 (systeme-de-choix.md §2).
				drapeaux[instr.nom] = Personnages.borner(instr.nom, v)
			"saut":
				if _condition(instr):
					sauts += 1
					if sauts > MAX_SAUTS:
						push_error("Boucle de sauts dans le dialogue (nœud %s)" % noeud)
						_entrer(FormatDialogue.FIN)
						break
					_entrer(instr.cible)
			"menu":
				_options = instr.options.filter(_condition)
				if _options.is_empty():
					if instr.has("cible_delai"):
						_entrer(instr.cible_delai)
					continue
				_menu = instr
				return _evenement_choix()
	return {"type": "fin"}


func choisir(index: int) -> void:
	if index < 0 or index >= _options.size():
		push_error("Choix %d invalide" % index)
		return
	var cible: String = _options[index].cible
	_options = []
	_entrer(cible)


## Le délai du menu courant est écoulé sans choix : on suit la cible « *! ».
func expirer() -> void:
	if _options.is_empty() or not _menu.has("cible_delai"):
		return
	_entrer(_menu.cible_delai)


func _evenement_choix() -> Dictionary:
	var r := []
	for i in _options.size():
		r.append({"texte": _options[i].texte, "index": i})
	return {"type": "choix", "options": r, "delai": float(_menu.get("delai", 0.0))}


func _condition(instr: Dictionary) -> bool:
	return FormatDialogue.evaluer(instr, drapeaux)


func _entrer(nom: String) -> void:
	noeud = nom
	_index = 0
	_options = []
	_menu = {}
	noeud_entre.emit(nom)
