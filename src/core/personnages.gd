class_name Personnages
extends RefCounted
## Registre des personnages (data/personnages.json, systeme-de-choix.md §4) et règles des clés
## de drapeaux qui en dépendent. Garde-fou de la règle du canon : un personnage « canon » n'a
## jamais de clé vivant_<perso>.

const CHEMIN := "res://data/personnages.json"
const TRAIT_MIN := 0
const TRAIT_MAX := 10
## Liste fermée, étendue seulement par le Game Designer.
const TRAITS := ["obeissance", "compassion", "doute", "fraternite", "orgueil"]

static var _registre: Dictionary = {}


static func registre() -> Dictionary:
	if _registre.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(CHEMIN))
		_registre = d.get("personnages", {}) if typeof(d) == TYPE_DICTIONARY else {}
	return _registre


static func est_canon(perso: String) -> bool:
	return registre().get(perso, {}).get("statut", "") == "canon"


## Vrai si la clé peut être écrite. Refuse vivant_<perso> pour un personnage canon.
static func ecriture_permise(cle: String) -> bool:
	return not (cle.begins_with("vivant_") and est_canon(cle.trim_prefix("vivant_")))


## Borne une valeur selon la famille de sa clé (relations de -3 à +3, traits de 0 à 10).
static func borner(cle: String, valeur: Variant) -> Variant:
	if typeof(valeur) != TYPE_INT:
		return valeur
	if cle.begins_with("relation_"):
		return clampi(valeur, -3, 3)
	if cle.begins_with("trait_"):
		return clampi(valeur, TRAIT_MIN, TRAIT_MAX)
	return valeur
