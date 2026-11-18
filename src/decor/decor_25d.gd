@tool
class_name Decor25D
extends Node2D
## Décor 2.5D : calques peints en parallaxe, éclairés par les lumières 2D grâce à leurs
## cartes de normales.
##
## Lit res://assets/decors/<id>/decor.json (contrat avec la chaîne d'images du Tools Programmer),
## ou, à défaut, le <plan>.json du guide de style de la DA (§6 : distances en mètres,
## <nom>_normal.png, <nom>_ombre.png, voile atmosphérique), converti par depuis_guide().
## Cadre de référence : la composition est exacte (calques alignés comme dans la peinture)
## quand la caméra est centrée sur le décor au zoom 1. Ailleurs, la parallaxe décale chaque
## calque selon sa profondeur.
##
##   {"version": 1, "taille": [l, h], "calques": [
##     {"fichier": "00_ciel.png",          # obligatoire, relatif au dossier du décor
##      "profondeur": 0.1,                 # parallaxe : 0 = fixe à l'écran, 1 = suit la caméra
##      "normales": "00_ciel_n.png",       # facultatif, espace tangent OpenGL (Y vers le haut)
##      "position": [x, y],                # facultatif, coin haut-gauche en pixels du décor
##      "lumiere": true,                   # facultatif (vrai par défaut) : reçoit les Light2D
##      "ombre": "00_ciel_ombre.png",      # facultatif : ombres portées, en multiplication
##      "voile": ["#C99A5B", 0.3],         # facultatif : couleur et force du voile atmosphérique
##      "melange": "addition"}]}           # facultatif : calque en addition (particules, lueurs)
##
## Format du guide, tête séparée (facultatif, par calque de personnage) :
##   "tete": {"corps": "calques/45_vaskar_corps.png", "fichier": "calques/45_vaskar_tete.png",
##            "avant": "calques/45_vaskar_avant.png", "pivot_px": [1702.8, 507.9],
##            "ordre": ["corps", "tete", "avant"], "rotation_max_deg": 15}
## Sans ce bloc, detacher_tete() découpe la tête automatiquement dans le calque.
## Pour chaque fichier, une version <nom>_plat.png (sans lumière cuite) est préférée si elle
## existe, avec <nom>_plat_normal.png : le moteur éclaire lui-même.
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
## Dossier des décors (les tests pointent vers leurs fixtures).
@export var dossier_decors := DOSSIER

## Voile atmosphérique : mélange la couleur du calque vers la couleur du voile, avant la lumière.
const SHADER_VOILE := """
shader_type canvas_item;
uniform vec4 voile : source_color = vec4(0.79, 0.6, 0.36, 1.0);
uniform float force : hint_range(0.0, 1.0) = 0.0;
// Zone masquée (UV : x, y, largeur, hauteur) : une partie détachée du calque pour être animée
// à part (la tête pour un hochement). Largeur nulle : rien n'est masqué.
uniform vec4 masque = vec4(0.0);
void fragment() {
	if (masque.z > 0.0 && UV.x >= masque.x && UV.x < masque.x + masque.z
			&& UV.y >= masque.y && UV.y < masque.y + masque.w) {
		discard;
	}
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, voile.rgb, force), c.a) * COLOR;
}
"""
static var _shader_voile: Shader

var taille := Vector2.ZERO
var calques: Array[Parallax2D] = []


func _ready() -> void:
	construire()


## Taille de référence de l'écran (résolution de base du projet).
static func taille_ecran() -> Vector2:
	return Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))


## JSON du décor : decor.json (format moteur) ou, à défaut, le <plan>.json du guide de style
## de la DA (premier .json du dossier qui contient « cadre_px »).
static func chemin_json(id: String, dossier_decors := DOSSIER) -> String:
	var dossier := dossier_decors.path_join(id)
	if FileAccess.file_exists(dossier.path_join("decor.json")):
		return dossier.path_join("decor.json")
	var dir := DirAccess.open(dossier)
	if dir:
		for f in dir.get_files():
			if f.get_extension() == "json" and FileAccess.get_file_as_string(dossier.path_join(f)).contains("\"cadre_px\""):
				return dossier.path_join(f)
	return dossier.path_join("decor.json")


## Lit et valide le JSON d'un décor (l'un ou l'autre format), ramené au format moteur.
## Renvoie {"erreurs": [...]} si invalide.
static func lire(id: String, dossier_decors := DOSSIER) -> Dictionary:
	var chemin := chemin_json(id, dossier_decors)
	if not FileAccess.file_exists(chemin):
		return {"erreurs": ["introuvable : " + chemin]}
	var d = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	if typeof(d) == TYPE_DICTIONARY and d.has("cadre_px"):
		d = depuis_guide(d, chemin.get_base_dir())
	var erreurs := valider(d)
	if not erreurs.is_empty():
		return {"erreurs": erreurs}
	return d


## Convertit un <plan>.json du guide de style (§6) au format moteur :
## - cadre_px → taille ; calques plein cadre ;
## - distance_m → profondeur = distance_reference / distance (parallaxe en 1/d). La référence
##   est « distance_reference_m » si présent, sinon le calque le plus proche (profondeur 1) ;
##   un calque sans distance est un ciel (00_…, profondeur 0, non éclairé) ou des particules
##   (au premier plan, profondeur 1, non éclairées) ;
## - <nom>_normal.png et <nom>_ombre.png à côté du calque sont repris s'ils existent ;
## - voile atmosphérique t = 1 - exp(-d / d0) vers la couleur « voile ».
static func depuis_guide(g: Dictionary, dossier: String) -> Dictionary:
	var distances: Array[float] = []
	for k in g.get("calques", []):
		if typeof(k) == TYPE_DICTIONARY and k.has("distance_m") and float(k.distance_m) > 0.0:
			distances.append(float(k.distance_m))
	var ref := float(g.get("distance_reference_m", distances.min() if not distances.is_empty() else 1.0))
	var voile: Dictionary = g.get("voile", {})
	var calques := []
	for k in g.get("calques", []):
		if typeof(k) != TYPE_DICTIONARY or not k.has("fichier"):
			calques.append(k)
			continue
		var f: String = k.fichier
		if not ResourceLoader.exists(dossier.path_join(f)):
			# Calque pas encore livré (la DA génère certains calques à l'assemblage) : on le saute.
			push_warning("Décor %s : calque absent, ignoré : %s" % [g.get("plan", "?"), f])
			continue
		var c := {"fichier": f}
		var base := f.get_basename()
		if k.has("distance_m") and float(k.distance_m) > 0.0:
			var d := float(k.distance_m)
			c.profondeur = clampf(ref / d, 0.0, 2.0)
			c.lumiere = k.get("lumiere", true)
			if voile.has("couleur") and voile.has("d0_m"):
				c.voile = [voile.couleur, 1.0 - exp(-d / float(voile.d0_m))]
		else:
			var ciel := f.get_file().begins_with("00_")
			c.profondeur = 0.0 if ciel else 1.0
			c.lumiere = k.get("lumiere", false)
			if not ciel:
				# Particules : posées en addition légère, comme dans assembler.py.
				c.melange = k.get("melange", "addition")
		if ResourceLoader.exists(dossier.path_join(base + "_normal.png")):
			c.normales = base + "_normal.png"
		# Version « plate » (albédo × occlusion, sans lumière cuite) : c'est elle que le moteur
		# éclaire, sinon le contre-jour peint compterait deux fois. Le nœud garde le nom du calque.
		if ResourceLoader.exists(dossier.path_join(base + "_plat.png")):
			c.nom = f.get_file().get_basename()
			c.fichier = base + "_plat.png"
			if ResourceLoader.exists(dossier.path_join(base + "_plat_normal.png")):
				c.normales = base + "_plat_normal.png"
		if ResourceLoader.exists(dossier.path_join(base + "_ombre.png")):
			c.ombre = base + "_ombre.png"
		if typeof(k.get("tete")) == TYPE_DICTIONARY:
			var t: Dictionary = k.tete
			var manquants := ["corps", "fichier", "avant"].filter(
				func(cle): return t.has(cle) and not ResourceLoader.exists(dossier.path_join(t[cle])))
			if not t.has("pivot_px") or not t.has("fichier") or not t.has("corps") or not manquants.is_empty():
				push_warning("Décor %s : bloc « tete » de %s incomplet, ignoré (%s)" % [g.get("plan", "?"), f, manquants])
			else:
				c.tete = t
		calques.append(c)
	return {"version": VERSION_FORMAT, "taille": g.cadre_px, "calques": calques,
		"source": "guide", "cle": g.get("cle", {})}


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
	var d := lire(id_decor, dossier_decors)
	if d.has("erreurs"):
		push_error("Décor « %s » : %s" % [id_decor, ", ".join(d.erreurs)])
		return
	taille = Vector2(d.taille[0], d.taille[1])
	var dossier := dossier_decors.path_join(id_decor)
	for i in d.calques.size():
		var k: Dictionary = d.calques[i]
		calques.append(_creer_calque(dossier, k, i))


func _creer_calque(dossier: String, k: Dictionary, index: int) -> Parallax2D:
	# Une échelle nulle rend la transformée de Parallax2D non inversible : plancher minuscule.
	var p := maxf(float(k.get("profondeur", 1.0)), 0.0001)
	var couche := Parallax2D.new()
	# Nom de nœud sans « / » (les fichiers du guide sont dans calques/) : Calque_45_vaskar.
	couche.name = "Calque_%s" % k.get("nom", String(k.fichier).get_file().get_basename())
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
	# Tête séparée (bloc « tete » du guide) : le calque affiche le corps seul, la tête et la
	# partie du col qui passe devant sont des sprites à part (voir _poser_tete).
	if k.has("tete"):
		tex = _texture_avec_normales(dossier, k.tete.corps)
	var sprite := Sprite2D.new()
	sprite.name = "Image"
	sprite.texture = tex
	sprite.centered = false
	if k.has("position"):
		sprite.position = Vector2(k.position[0], k.position[1])
	sprite.light_mask = MASQUE_LUMIERE if k.get("lumiere", true) else 0
	if k.has("voile") and float(k.voile[1]) > 0.0:
		var m := materiau_voile()
		m.set_shader_parameter("voile", Color(k.voile[0]))
		m.set_shader_parameter("force", float(k.voile[1]))
		sprite.material = m
	elif k.get("melange", "") == "addition":
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = add
	couche.add_child(sprite)
	if k.has("tete"):
		_poser_tete(couche, sprite, dossier, k.tete)
	if k.has("ombre"):
		# Ombres portées : calque à part en multiplication, déplaçable avec la lumière.
		var ombre := Sprite2D.new()
		ombre.name = "Ombre"
		ombre.texture = load(dossier.path_join(k.ombre))
		ombre.centered = false
		ombre.position = sprite.position
		var mul := CanvasItemMaterial.new()
		mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		ombre.material = mul
		couche.add_child(ombre)
	add_child(couche)
	return couche


## Texture couleur + normales d'une partie ; préfère la version plate (_plat, _plat_normal).
static func _texture_avec_normales(dossier: String, fichier: String) -> CanvasTexture:
	var base := fichier.get_basename()
	var tex := CanvasTexture.new()
	var plat := ResourceLoader.exists(dossier.path_join(base + "_plat.png"))
	tex.diffuse_texture = load(dossier.path_join(base + ("_plat.png" if plat else ".png")))
	for n in ([base + "_plat_normal.png", base + "_normal.png"] if plat else [base + "_normal.png"]):
		if ResourceLoader.exists(dossier.path_join(n)):
			tex.normal_texture = load(dossier.path_join(n))
			break
	return tex


## Tête séparée livrée par la chaîne d'images : corps (déjà dans « Image »), tête, puis
## « avant » (le col devant le cou), dans l'ordre de « ordre ». Plein cadre, même origine.
## La tête pivote autour de pivot_px ; sa rotation est bornée par rotation_max_deg.
func _poser_tete(couche: Node, corps: Sprite2D, dossier: String, t: Dictionary) -> void:
	var pivot := Vector2(t.pivot_px[0], t.pivot_px[1])
	var ordre: Array = t.get("ordre", ["corps", "tete", "avant"])
	for partie in ordre:
		if partie == "corps" or (partie == "avant" and not t.has("avant")):
			continue
		var s := Sprite2D.new()
		s.name = "Tete" if partie == "tete" else "Avant"
		s.texture = _texture_avec_normales(dossier, t.fichier if partie == "tete" else t.avant)
		s.centered = false
		s.light_mask = corps.light_mask
		s.material = corps.material
		if partie == "tete":
			s.position = corps.position + pivot
			s.offset = -pivot
			s.set_meta("rotation_max", deg_to_rad(float(t.get("rotation_max_deg", 15.0))))
		else:
			s.position = corps.position
		couche.add_child(s)


static func materiau_voile() -> ShaderMaterial:
	if _shader_voile == null:
		_shader_voile = Shader.new()
		_shader_voile.code = SHADER_VOILE
	var m := ShaderMaterial.new()
	m.shader = _shader_voile
	return m


## Détache la tête d'une figure peinte sur un calque plein cadre pour l'animer à part.
## La tête est le haut de la silhouette, jusqu'à la ligne où elle s'élargit nettement (les
## épaules). Renvoie le Sprite2D de la tête, pivot au cou, ou null si rien n'est détecté.
## Le calque d'origine masque la même zone : aucun double contour.
func detacher_tete(nom_calque: String) -> Sprite2D:
	var couche := get_node_or_null(nom_calque)
	if couche == null:
		return null
	# Tête déjà livrée en calque séparé (bloc « tete ») : rien à détacher.
	if couche.has_node("Tete"):
		return couche.get_node("Tete")
	var image_sprite := couche.get_node("Image") as Sprite2D
	var tex := image_sprite.texture as CanvasTexture
	var zone := Decor25D.zone_tete(tex.diffuse_texture.get_image())
	if zone.size == Vector2i.ZERO:
		return null
	var taille_tex := Vector2(tex.diffuse_texture.get_size())
	var base := image_sprite.material as ShaderMaterial
	if base == null:
		base = materiau_voile()
		image_sprite.material = base
	var tete_mat := base.duplicate() as ShaderMaterial
	tete_mat.set_shader_parameter("masque", Vector4.ZERO)
	base.set_shader_parameter("masque", Vector4(zone.position.x / taille_tex.x, zone.position.y / taille_tex.y,
		zone.size.x / taille_tex.x, zone.size.y / taille_tex.y))
	var tete := Sprite2D.new()
	tete.name = "Tete"
	tete.texture = tex
	tete.material = tete_mat
	tete.light_mask = image_sprite.light_mask
	tete.centered = false
	tete.region_enabled = true
	tete.region_rect = Rect2(zone)
	var cou := Vector2(zone.position.x + zone.size.x / 2.0, zone.end.y)
	tete.position = image_sprite.position + cou
	tete.offset = Vector2(zone.position) - cou
	tete.set_meta("rotation_max", deg_to_rad(15.0))
	couche.add_child(tete)
	return tete


## Rectangle de la tête dans une image RGBA : haut de la silhouette jusqu'aux épaules.
static func zone_tete(img: Image) -> Rect2i:
	var bb := img.get_used_rect()
	if bb.size == Vector2i.ZERO:
		return Rect2i()
	var largeurs: Array[int] = []
	var gauche := bb.end.x
	var droite := bb.position.x
	for y in range(bb.position.y, bb.end.y, 2):
		var g := -1
		var d := -1
		for x in range(bb.position.x, bb.end.x, 2):
			if img.get_pixel(x, y).a > 0.5:
				if g < 0:
					g = x
				d = x
		if g < 0:
			largeurs.append(0)
			continue
		var w := d - g
		# Largeur de référence de la tête : la médiane des lignes déjà vues (un maximum courant
		# suivrait l'élargissement progressif du cou et ne verrait jamais les épaules).
		var vues := largeurs.filter(func(v): return v > 0)
		vues.sort()
		var ref: int = vues[vues.size() / 2] if not vues.is_empty() else 0
		# Épaules : la silhouette s'élargit de plus de 60 % par rapport à la tête.
		if ref > 0 and vues.size() > 10 and w > ref * 1.6:
			return Rect2i(gauche - 4, bb.position.y, droite - gauche + 8, y - bb.position.y)
		largeurs.append(w)
		gauche = mini(gauche, g)
		droite = maxi(droite, d)
	return Rect2i()


## Mémoire vidéo estimée des textures du décor (RGBA8 non compressé + mipmaps ignorés), en octets.
## Sert au budget de perf : voir src/perf/budget.gd.
func memoire_textures() -> int:
	var total := 0
	for c in calques:
		var tex := (c.get_node("Image") as Sprite2D).texture as CanvasTexture
		for t in [tex.diffuse_texture, tex.normal_texture]:
			if t != null:
				total += t.get_width() * t.get_height() * 4
		for nom in ["Ombre", "Tete", "Avant"]:
			var s := c.get_node_or_null(nom) as Sprite2D
			if s == null or (nom == "Tete" and s.region_enabled):
				continue  # une tête détachée partage la texture du calque
			var st := s.texture
			var lst: Array = [st.diffuse_texture, st.normal_texture] if st is CanvasTexture else [st]
			for t in lst:
				if t != null:
					total += t.get_width() * t.get_height() * 4
	return total
