@tool
class_name Decor25D
extends Node2D
## Décor 2.5D : calques peints en parallaxe, éclairés par les lumières 2D grâce à leurs
## cartes de normales.
##
## Lit res://assets/decors/<id>/decor.json (contrat avec la chaîne d'images du Tools Programmer).
## Cadre de référence : la composition est exacte (calques alignés comme dans la peinture)
## quand la caméra est centrée sur le décor au zoom 1. Ailleurs, la parallaxe décale chaque
## calque selon sa profondeur.
##
##   {"version": 1, "taille": [l, h], "calques": [
##     {"fichier": "00_ciel.png",          # obligatoire, relatif au dossier du décor
##      "profondeur": 0.1,                 # parallaxe : 0 = fixe à l'écran, 1 = suit la caméra
##      "normales": "00_ciel_n.png",       # facultatif, espace tangent OpenGL (Y vers le haut)
##      "position": [x, y],                # facultatif, coin haut-gauche en pixels du décor
##      "lumiere": true}]}                 # facultatif (vrai par défaut) : reçoit les Light2D
##
## L'origine du nœud est le coin haut-gauche du décor. Chaque calque devient un Parallax2D
## (scroll_scale = profondeur) contenant un Sprite2D texturé par une CanvasTexture
## (couleur + normales). Les lumières de la scène (PointLight2D, DirectionalLight2D) éclairent
## les calques dont « lumiere » est vrai.

const VERSION_FORMAT := 1
const DOSSIER := "res://assets/decors"
## Masque de lumière des calques éclairables ; un calque non éclairé a un masque vide.
const MASQUE_LUMIERE := 1

@export var id_decor := "":
	set(v):
		id_decor = v
		if is_inside_tree():
			construire()

var taille := Vector2.ZERO
var calques: Array[Parallax2D] = []


func _ready() -> void:
	construire()


## Taille de référence de l'écran (résolution de base du projet).
static func taille_ecran() -> Vector2:
	return Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))


static func chemin_json(id: String) -> String:
	return DOSSIER.path_join(id).path_join("decor.json")


## Lit et valide un decor.json. Renvoie {"erreurs": [...]} si invalide.
static func lire(id: String) -> Dictionary:
	var chemin := chemin_json(id)
	if not FileAccess.file_exists(chemin):
		return {"erreurs": ["introuvable : " + chemin]}
	var d = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	var erreurs := valider(d)
	if not erreurs.is_empty():
		return {"erreurs": erreurs}
	return d


static func valider(d) -> PackedStringArray:
	var e: PackedStringArray = []
	if typeof(d) != TYPE_DICTIONARY:
		return PackedStringArray(["pas un objet JSON"])
	if int(d.get("version", 0)) != VERSION_FORMAT:
		e.append("version %s non gérée (attendu %d)" % [d.get("version"), VERSION_FORMAT])
	var t = d.get("taille")
	if typeof(t) != TYPE_ARRAY or t.size() != 2 or t[0] <= 0 or t[1] <= 0:
		e.append("taille absente ou invalide")
	var c = d.get("calques")
	if typeof(c) != TYPE_ARRAY or c.is_empty():
		e.append("aucun calque")
		return e
	for i in c.size():
		var k = c[i]
		if typeof(k) != TYPE_DICTIONARY or not k.has("fichier"):
			e.append("calque %d sans fichier" % i)
			continue
		var p = k.get("profondeur", 1.0)
		if typeof(p) not in [TYPE_FLOAT, TYPE_INT] or p < 0.0 or p > 2.0:
			e.append("calque %d : profondeur hors de [0, 2]" % i)
		if k.has("position"):
			var pos = k.position
			if typeof(pos) != TYPE_ARRAY or pos.size() != 2:
				e.append("calque %d : position invalide" % i)
	return e


func construire() -> void:
	for c in calques:
		c.queue_free()
	calques.clear()
	if id_decor.is_empty():
		return
	var d := lire(id_decor)
	if d.has("erreurs"):
		push_error("Décor « %s » : %s" % [id_decor, ", ".join(d.erreurs)])
		return
	taille = Vector2(d.taille[0], d.taille[1])
	var dossier := DOSSIER.path_join(id_decor)
	for i in d.calques.size():
		var k: Dictionary = d.calques[i]
		calques.append(_creer_calque(dossier, k, i))


func _creer_calque(dossier: String, k: Dictionary, index: int) -> Parallax2D:
	var p := float(k.get("profondeur", 1.0))
	var couche := Parallax2D.new()
	couche.name = "Calque_%s" % String(k.fichier).get_basename()
	couche.scroll_scale = Vector2(p, p)
	# Parallax2D décale le calque de (1 - p) × (coin haut-gauche de la caméra). On compense
	# pour que la composition peinte soit exacte quand la caméra est centrée sur le décor :
	# c'est le « cadre de référence » de la chaîne d'images.
	couche.scroll_offset = -(1.0 - p) * (taille / 2.0 - taille_ecran() / 2.0)
	couche.z_index = index

	var tex := CanvasTexture.new()
	tex.diffuse_texture = load(dossier.path_join(k.fichier))
	if k.has("normales"):
		tex.normal_texture = load(dossier.path_join(k.normales))
	var sprite := Sprite2D.new()
	sprite.name = "Image"
	sprite.texture = tex
	sprite.centered = false
	if k.has("position"):
		sprite.position = Vector2(k.position[0], k.position[1])
	sprite.light_mask = MASQUE_LUMIERE if k.get("lumiere", true) else 0
	couche.add_child(sprite)
	add_child(couche)
	return couche


## Mémoire vidéo estimée des textures du décor (RGBA8 non compressé + mipmaps ignorés), en octets.
## Sert au budget de perf : voir src/perf/budget.gd.
func memoire_textures() -> int:
	var total := 0
	for c in calques:
		var tex := (c.get_node("Image") as Sprite2D).texture as CanvasTexture
		for t in [tex.diffuse_texture, tex.normal_texture]:
			if t != null:
				total += t.get_width() * t.get_height() * 4
	return total
