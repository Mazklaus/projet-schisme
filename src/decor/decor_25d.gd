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
## Calques non éclairés (ciel, particules) : seules les lumières de halo les touchent.
const MASQUE_HALO := 4
## Personnages (calques 4x_) d'un intérieur à « loi des aperçus » : la clé y est posée très
## haute (sans atténuation par les normales), ce qui les aplatissait en blanc (retour DA,
## barge). Une copie de chaque clé, basse, les éclaire seuls et garde leur modelé.
const MASQUE_PERSONNAGES := 8
## Hauteur (px) et énergie relative de cette copie, calées sur apercu_40_pe / apercu_40_b27.
const HAUTEUR_MODELE_PX := 120.0
const ENERGIE_MODELE := 0.65
## Même copie quand la clé est en contre-jour (silhouettes à 0,1–0,15 de valeur).
const ENERGIE_MODELE_CONTRE_JOUR := 0.15


## Clé qui fait face à la caméra, d'après le guide de la DA (type ou note).
static func est_contre_jour(cle: Dictionary) -> bool:
	var t := (String(cle.get("type", "")) + " " + String(cle.get("note", ""))).to_lower()
	return t.contains("vers la caméra") or t.contains("contre-jour") or bool(cle.get("contre_jour", false))

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
// En Godot 4, le COLOR d'entrée du fragment contient déjà la texture : on garde la modulation
// seule (couleur de sommet × modulate) depuis vertex(), sinon la texture compte deux fois et
// tout calque voilé sort assombri (Titans d'Ullanor, retour DA).
varying vec4 modulation;
void vertex() {
	modulation = COLOR;
}
void fragment() {
	if (masque.z > 0.0 && UV.x >= masque.x && UV.x < masque.x + masque.z
			&& UV.y >= masque.y && UV.y < masque.y + masque.w) {
		discard;
	}
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, voile.rgb, force), c.a) * modulation;
}
"""
static var _shader_voile: Shader

## Foule peinte (calques « personnages ») : la même chose que le voile, plus une respiration et
## un balancement des figures. Chaque colonne de l'image s'étire vers le haut depuis sa ligne de
## pieds (texture « pieds », relevée une fois au chargement) ; la phase varie lentement le long
## de x : les figures voisines ne bougent jamais ensemble, sans déchirure au milieu d'une figure.
## Les normales suivent le même déplacement que la couleur (sinon la lumière « glisse »).
const SHADER_FOULE := """
shader_type canvas_item;
uniform vec4 voile : source_color = vec4(0.79, 0.6, 0.36, 1.0);
uniform float force : hint_range(0.0, 1.0) = 0.0;
uniform vec4 masque = vec4(0.0);
uniform sampler2D pieds : filter_linear, repeat_disable;
uniform float respiration = 0.0;
uniform float balancement = 0.0;
uniform vec2 taille_px = vec2(1.0);
uniform float graine = 0.0;
uniform float vitesse = 1.0;
varying vec4 modulation;
void vertex() {
	modulation = COLOR;
}
void fragment() {
	if (masque.z > 0.0 && UV.x >= masque.x && UV.x < masque.x + masque.z
			&& UV.y >= masque.y && UV.y < masque.y + masque.w) {
		discard;
	}
	vec2 uv = UV;
	float pied = texture(pieds, vec2(UV.x, 0.5)).r;
	float h = pied - UV.y;
	if (h > 0.0) {
		float x = UV.x * taille_px.x;
		float ph = x * 0.011 + 1.7 * sin(x * 0.0037 + graine) + graine;
		float s = 0.5 + 0.5 * sin(TIME * vitesse * 1.55 + ph);
		uv.y = pied - h / (1.0 + respiration * s * s * (3.0 - 2.0 * s));
		uv.x -= balancement * sin(TIME * vitesse * 1.03 + ph * 0.8) * h * taille_px.y / taille_px.x;
	}
	vec4 c = texture(TEXTURE, uv);
	NORMAL_MAP = texture(NORMAL_TEXTURE, uv).rgb;
	COLOR = vec4(mix(c.rgb, voile.rgb, force), c.a) * modulation;
}
"""
static var _shader_foule: Shader
## Réglages de la foule peinte (en fraction de la hauteur de chaque figure).
const FOULE_RESPIRATION := 0.010
const FOULE_BALANCEMENT := 0.006
## Largeur d'une colonne de la texture des pieds, en pixels de l'image.
const FOULE_COLONNE_PX := 8

## Décor peint qui vit (bloc « vie » d'un calque, Ullanor) : le voile habituel, plus
## - « derive » : une ondulation lente et douce de l'image (bruit qui glisse), pour les fumées et
##   la poussière : rien ne se déplace dans la composition, la matière bouge sur place ;
## - « drapeaux » : des rectangles de tissu suspendus (x, y du haut, largeur, hauteur en px),
##   qui ondulent de plus en plus vers le bas, chacun à sa phase ;
## - « souffle » : une respiration lente au-dessus d'une ligne de sol (Titans : cheminées et
##   servos qui se soulèvent de 2 ou 3 px), déphasée le long de x ;
## - « tetes » : des têtes de machine (Titans) qui balaient de quelques px par à-coups, toutes
##   les 10 à 15 s, avec un arrêt sec ; « tressaillement » : un sursaut de servo rare.
##   Des machines immobiles et vivantes à la fois, pas une respiration organique.
const SHADER_VIVANT := """
shader_type canvas_item;
uniform vec4 voile : source_color = vec4(0.79, 0.6, 0.36, 1.0);
uniform float force : hint_range(0.0, 1.0) = 0.0;
uniform vec2 taille_px = vec2(1.0);
uniform float derive_px = 0.0;
uniform float derive_echelle_px = 120.0;
uniform vec2 derive_vitesse = vec2(0.02, -0.01);
uniform sampler2D drapeaux : filter_linear, repeat_disable;
uniform float drapeau_px = 0.0;
uniform float souffle_px = 0.0;
uniform float souffle_periode = 6.0;
uniform float souffle_sol_px = 1080.0;
uniform vec4 tetes[4];
uniform int tetes_n = 0;
uniform float tete_px = 0.0;
uniform float tressaillement_px = 0.0;
varying vec4 modulation;
float hasard(float n) {
	return fract(sin(n * 91.345 + 12.9898) * 43758.5453);
}
// Position (-1 à 1) d'un balayage par à-coups : une cible nouvelle toutes les 10 à 15 s,
// atteinte en 1,4 s en accélérant, puis arrêt sec.
float balayage(float t, float i) {
	float periode = 10.0 + 5.0 * hasard(i * 7.0 + 1.0);
	float x = t / periode + hasard(i * 3.0);
	float n = floor(x);
	float k = clamp(fract(x) * periode / 1.4, 0.0, 1.0);
	return mix(hasard(n + i * 101.0) * 2.0 - 1.0, hasard(n + 1.0 + i * 101.0) * 2.0 - 1.0, k * k);
}
float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
void vertex() {
	modulation = COLOR;
}
void fragment() {
	vec2 px = UV * taille_px;
	vec2 d = vec2(0.0);
	if (derive_px > 0.0) {
		vec2 q = px / derive_echelle_px + TIME * derive_vitesse;
		d += (vec2(bruit(q), bruit(q + vec2(5.2, 1.3))) - 0.5) * 2.0 * derive_px;
	}
	if (drapeau_px > 0.0) {
		vec4 m = texture(drapeaux, UV);
		d.x += drapeau_px * m.r * sin(TIME * (1.8 + m.b * 1.2) + px.y * 0.22 + m.g * 6.2832);
	}
	if (souffle_px > 0.0 && px.y < souffle_sol_px) {
		float s = 0.5 + 0.5 * sin(TIME * 6.2832 / souffle_periode + UV.x * 4.0);
		d.y += souffle_px * s * (souffle_sol_px - px.y) / souffle_sol_px;
	}
	for (int i = 0; i < tetes_n; i++) {
		vec4 r = tetes[i];
		vec2 e = min(px - r.xy, r.xy + r.zw - px);
		if (e.x > 0.0 && e.y > 0.0) {
			float w = clamp(min(e.x, e.y) / 5.0, 0.0, 1.0);
			d.x -= tete_px * w * balayage(TIME, float(i));
		}
	}
	if (tressaillement_px > 0.0 && px.y < souffle_sol_px) {
		// Un sursaut de 0,2 s, une fois sur deux toutes les 17 s, propre à chaque moitié du cadre.
		float moitie = step(0.5, UV.x);
		float x = TIME / 17.0 + moitie * 0.43;
		float t = fract(x) * 17.0;
		if (t < 0.2 && hasard(floor(x) + moitie * 33.0) > 0.5) {
			d.y += tressaillement_px * sin(t * 95.0) * (1.0 - t / 0.2);
		}
	}
	vec2 uv = UV + d / taille_px;
	vec4 c = texture(TEXTURE, uv);
	NORMAL_MAP = texture(NORMAL_TEXTURE, uv).rgb;
	COLOR = vec4(mix(c.rgb, voile.rgb, force), c.a) * modulation;
}
"""
static var _shader_vivant: Shader

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
	if FileAccess.file_exists(dossier.path_join(id + ".json")):
		return dossier.path_join(id + ".json")
	var dir := DirAccess.open(dossier)
	if dir:
		for f in dir.get_files():
			var texte := FileAccess.get_file_as_string(dossier.path_join(f)) if f.get_extension() == "json" else ""
			if texte.contains("\"cadre_px\"") or texte.contains("\"resolution\""):
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
	elif typeof(d) == TYPE_DICTIONARY and d.has("resolution") and d.has("calques"):
		d = depuis_planche(d, chemin.get_base_dir())
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
## Format « planche » de CA2 (décors d'Orvane) : resolution, calques avec ordre, parallaxe,
## eclaire, normal, ombre, fusion, etat, intensite(_par_etat), couleur(_intensite_par_etat),
## modulate_par_etat ; lumieres avec energie(_par_etat) ; etats {nom: {canvas_modulate}} ou
## canvas_modulate global. Ramené au format moteur, avec « etats » et des réglages par état
## que appliquer_etat() anime.
static func depuis_planche(g: Dictionary, dossier: String) -> Dictionary:
	var liste: Array = g.calques.filter(func(k): return typeof(k) == TYPE_DICTIONARY and k.has("fichier"))
	liste.sort_custom(func(a, b): return float(a.get("ordre", 0)) < float(b.get("ordre", 0)))
	var calques := []
	for k in liste:
		var f: String = k.fichier
		var gabarit := f.get_base_dir().path_join("gabarit_" + f.get_file())
		if not ResourceLoader.exists(dossier.path_join(f)) and ResourceLoader.exists(dossier.path_join(gabarit)):
			f = gabarit
		if not ResourceLoader.exists(dossier.path_join(f)):
			push_warning("Décor %s : calque absent, ignoré : %s" % [g.get("nom", "?"), f])
			continue
		var c := {"fichier": f, "nom": String(k.fichier).get_file().get_basename().trim_prefix("gabarit_")}
		var ciel := String(c.nom).begins_with("00_")
		c.profondeur = clampf(float(k.get("parallaxe", 0.0 if ciel else 1.0)), 0.0, 2.0)
		c.lumiere = bool(k.get("eclaire", false))
		if typeof(k.get("normal")) == TYPE_STRING and ResourceLoader.exists(dossier.path_join(k.normal)):
			c.normales = k.normal
		if typeof(k.get("ombre")) == TYPE_STRING and ResourceLoader.exists(dossier.path_join(k.ombre)):
			c.ombre = k.ombre
		if String(k.get("fusion", "")).contains("additif"):
			c.melange = "addition"
		for cle in ["etat", "intensite_par_etat", "couleur_intensite_par_etat", "modulate_par_etat"]:
			if k.has(cle):
				c[cle] = k[cle]
		if k.has("couleur") or k.has("intensite"):
			var t := Color(k.get("couleur", "#FFFFFF"))
			t.a = float(k.get("intensite", 1.0))
			c.teinte = t.to_html()
		calques.append(c)
	var lum: Array = []
	for L in g.get("lumieres", []):
		if typeof(L) == TYPE_DICTIONARY and String(L.get("type", "")).contains("Directional"):
			# Soleil rasant (« de la droite, rasante ») : DirectionalLight2D, énergie par état.
			var dir := String(L.get("direction", ""))
			var e := {"type": "directionnelle", "couleur": L.get("couleur", "#FFFFFF"),
				"orientation": deg_to_rad(90.0 if dir.contains("droite") else -90.0 if dir.contains("gauche") else 0.0),
				"hauteur": 0.25 if dir.contains("rasant") else 0.6}
			if typeof(L.get("energie_par_etat")) == TYPE_DICTIONARY:
				e.energie_par_etat = L.energie_par_etat
				e.intensite = float(L.energie_par_etat.values()[0])
			else:
				e.intensite = float(L.get("energie", 1.0))
			lum.append(e)
			continue
		if typeof(L) != TYPE_DICTIONARY or typeof(L.get("position_px")) != TYPE_ARRAY:
			continue
		var e := {"position_px": L.position_px, "couleur": L.get("couleur", "#FFFFFF"),
			"rayon_px": float(L.get("rayon_px", 600)) / 2.5, "hauteur_px": 200.0,
			"scintillement": 0.1 if typeof(L.get("scintillement")) == TYPE_BOOL and L.scintillement \
				else float(L.get("scintillement", 0.0)) if typeof(L.get("scintillement")) in [TYPE_FLOAT, TYPE_INT] else 0.0}
		if typeof(L.get("energie_par_etat")) == TYPE_DICTIONARY:
			e.energie_par_etat = L.energie_par_etat
			e.intensite = float(L.energie_par_etat.values()[0])
		else:
			e.intensite = float(L.get("energie", 1.0))
		if L.has("nom"):
			e.nom = L.nom
		lum.append(e)
	var etats: Dictionary = g.etats if typeof(g.get("etats")) == TYPE_DICTIONARY else {}
	var ambiant := String(g.get("canvas_modulate", ""))
	return {"version": VERSION_FORMAT, "taille": g.resolution, "calques": calques, "source": "planche",
		"lumieres": lum, "ambiant": ambiant, "etats": etats, "veille": {},
		"etat_initial": g.get("etat_initial", etats.keys()[0] if not etats.is_empty() else "")}


## Vrai si le moteur éclaire ce plan (lumières d'état, ou clé / appoint prévus en Light2D) :
## alors seulement on affiche les versions « _plat » (albédo sans lumière cuite). Sans lumière
## du moteur (Ullanor : soleil peint), une version plate sortirait blanche et sans modelé.
## « plat »: true / false dans le JSON force le choix.
static func plan_eclaire(g: Dictionary) -> bool:
	if typeof(g.get("plat")) == TYPE_BOOL:
		return g.plat
	if typeof(g.get("lumieres")) == TYPE_ARRAY and not g.lumieres.is_empty():
		return true
	var sources: Array = [g.get("cle")]
	if typeof(g.get("appoints")) == TYPE_ARRAY:
		sources.append_array(g.appoints)
	for a in sources:
		if typeof(a) == TYPE_DICTIONARY and String(a.get("type", "")).contains("Light2D"):
			return true
	return false


## distance_m du guide : un nombre, ou un texte de CA2 (« 0,2 à 5,6 », « 1,9 et 5 ») dont on
## prend la moyenne des nombres ; 0 si aucun nombre (« derrière la porte », « infini »).
static func distance_guide(v) -> float:
	if typeof(v) in [TYPE_FLOAT, TYPE_INT]:
		return float(v)
	if typeof(v) != TYPE_STRING:
		return 0.0
	var re := RegEx.create_from_string("\\d+(?:[.,]\\d+)?")
	var nombres := re.search_all(String(v))
	if nombres.is_empty():
		return 0.0
	var somme := 0.0
	for m in nombres:
		somme += m.get_string().replace(",", ".").to_float()
	return somme / nombres.size()


static func depuis_guide(g: Dictionary, dossier: String) -> Dictionary:
	var distances: Array[float] = []
	for k in g.get("calques", []):
		if typeof(k) == TYPE_DICTIONARY and distance_guide(k.get("distance_m")) > 0.0:
			distances.append(distance_guide(k.distance_m))
	var ref := float(g.get("distance_reference_m", distances.min() if not distances.is_empty() else 1.0))
	# Champs facultatifs : absents ou null (« voile »: null dans un intérieur) reviennent au même.
	var voile: Dictionary = g.voile if typeof(g.get("voile")) == TYPE_DICTIONARY else {}
	var eclaire := plan_eclaire(g)
	var calques := []
	for k_brut in g.get("calques", []):
		if typeof(k_brut) != TYPE_DICTIONARY or not k_brut.has("fichier"):
			calques.append(k_brut)
			continue
		var k: Dictionary = k_brut
		# JSON normalisé : « infini » devient 10000 avec la note « distance : infini m » ; on
		# reprend l'infini (sans parallaxe propre, comme avant la normalisation).
		if String(k.get("note", "")).contains("distance : infini"):
			k = k.duplicate()
			k.distance_m = "infini"
		var f: String = k.fichier
		var gabarit := f.get_base_dir().path_join("gabarit_" + f.get_file())
		if not ResourceLoader.exists(dossier.path_join(f)) and ResourceLoader.exists(dossier.path_join(gabarit)):
			# Personnages pas encore livrés : le gabarit de la DA (silhouettes) tient leur place.
			push_warning("Décor %s : %s remplacé par son gabarit" % [g.get("plan", "?"), f])
			f = gabarit
		if not ResourceLoader.exists(dossier.path_join(f)):
			# Calque pas encore livré (la DA génère certains calques à l'assemblage) : on le saute.
			push_warning("Décor %s : calque absent, ignoré : %s" % [g.get("plan", "?"), f])
			continue
		var c := {"fichier": f}
		var base := f.get_basename()
		if distance_guide(k.get("distance_m")) > 0.0:
			var d := distance_guide(k.distance_m)
			c.profondeur = clampf(ref / d, 0.0, 2.0)
			c.lumiere = k.get("lumiere", true)
			if voile.has("couleur") and voile.has("d0_m"):
				c.voile = [voile.couleur, 1.0 - exp(-d / float(voile.d0_m))]
			# Personnages au premier plan (4x_, à quelques mètres) : ils reçoivent le rebond du
			# sol en plus de la clé (retour DA : Vaskar et Dremm trop sombres) ; « ambiance »:
			# false dans le JSON les sort aussi de l'ambiance de la scène.
			if f.get_file().begins_with("4") and d < 30.0:
				c.rebond = true
				c.personnage = true
			if k.get("ambiance", true) == false:
				c.hors_ambiance = true
			# Liseré additif posé à la distance de son calque (41_lisere_froid de vs_galerie).
			if k.has("melange"):
				c.melange = k.melange
				for cle_l in ["force", "durete"]:
					if k.has(cle_l):
						c[cle_l] = float(k[cle_l])
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
		if eclaire and ResourceLoader.exists(dossier.path_join(base + "_plat.png")):
			c.nom = f.get_file().get_basename()
			c.fichier = base + "_plat.png"
			if ResourceLoader.exists(dossier.path_join(base + "_plat_normal.png")):
				c.normales = base + "_plat_normal.png"
		# « ombre »: false : les ombres du soleil d'un autre état (nuit, aube) ne s'appliquent pas.
		if typeof(k.get("ombre", true)) != TYPE_BOOL or k.get("ombre", true):
			if ResourceLoader.exists(dossier.path_join(base + "_ombre.png")):
				c.ombre = base + "_ombre.png"
		# État d'un lieu (nuit, aube…) : « ambiance » {couleur, gain} multiplie chaque calque de
		# décor, sauf ceux qui portent « ambiance »: false (ciel, flammes).
		var amb: Dictionary = g.ambiance if typeof(g.get("ambiance")) == TYPE_DICTIONARY else {}
		# {couleur, niveau} (plans éclairés en Light2D) est l'ambiant de la scène, pas une teinte
		# des calques : voir « ambiant » plus bas.
		# Les particules (90_, braises) sont posées après l'image dans assembler.py : pas de teinte.
		if amb.has("couleur") and not amb.has("niveau") and k.get("ambiance", true) \
				and not f.get_file().begins_with("90_"):
			var t := Color(amb.couleur) * float(amb.get("gain", 1.0))
			t.a = 1.0
			c.teinte = t.to_html()
		# Vie du décor (« vie », « foule ») : passée telle quelle au moteur.
		for cle_vie in ["vie", "foule"]:
			if k.has(cle_vie):
				c[cle_vie] = k[cle_vie]
		if typeof(k.get("tete")) == TYPE_DICTIONARY:
			var t: Dictionary = k.tete
			var manquants := ["corps", "fichier", "avant"].filter(
				func(cle): return t.has(cle) and not ResourceLoader.exists(dossier.path_join(t[cle])))
			if not t.has("pivot_px") or not t.has("fichier") or not t.has("corps") or not manquants.is_empty():
				push_warning("Décor %s : bloc « tete » de %s incomplet, ignoré (%s)" % [g.get("plan", "?"), f, manquants])
			else:
				c.tete = t.duplicate()
				c.tete["plat"] = eclaire
		# Le guide écrit « additif » ou « addition ».
		if String(c.get("melange", "")) in ["additif", "add", "ADD"]:
			c.melange = "addition"
		calques.append(c)
	# « etats » du guide : {nom: "00_exterieur_nuit : …"} ; le calque nommé n'est visible que
	# dans son état.
	# « variantes » (pont d'embarquement) : {nom: "05_exterieur_arrivee + 85_rais + …"} ;
	# chaque calque <NN>_<nom> cité n'appartient qu'aux états qui le citent.
	var etats_guide := {}
	var descr := {}
	for champ in ["etats", "variantes"]:
		if typeof(g.get(champ)) == TYPE_DICTIONARY:
			for nom in g[champ]:
				descr[nom] = String(g[champ][nom]) if typeof(g[champ][nom]) == TYPE_STRING else ""
	if not descr.is_empty():
		var re := RegEx.create_from_string("\\b\\d{2}_[a-z0-9_]+")
		var cites := {}  # calque -> états qui le citent
		for nom in descr:
			etats_guide[nom] = {}
			for m in re.search_all(descr[nom]):
				var cite := m.get_string()
				if not cites.has(cite):
					cites[cite] = []
				cites[cite].append(nom)
		for c in calques:
			var base := String(c.fichier).get_file().get_basename().trim_suffix("_plat")
			for cite in cites:
				if (base == cite or String(c.get("nom", "")) == cite) and cites[cite].size() < descr.size():
					c.etat = cites[cite][0] if cites[cite].size() == 1 else cites[cite]
	# Sans « etats », les énergies par état de la clé (arrivee / orbite) en tiennent lieu ; un
	# calque <NN>_<nom>_<etat> n'est alors visible que dans cet état.
	var cle_brute = g.get("cle")
	if etats_guide.is_empty() and typeof(cle_brute) == TYPE_DICTIONARY and typeof(cle_brute.get("energie")) == TYPE_DICTIONARY:
		for nom in cle_brute.energie:
			etats_guide[nom] = {}
	for nom in etats_guide:
		for c in calques:
			if not c.has("etat") and String(c.fichier).get_file().get_basename().ends_with("_" + nom):
				c.etat = nom
	var lum: Array = g.lumieres.duplicate() if typeof(g.get("lumieres")) == TYPE_ARRAY else []
	var cle: Dictionary = g.cle if typeof(g.get("cle")) == TYPE_DICTIONARY else {}
	var ambiant := ""
	if typeof(g.get("ambiance")) == TYPE_DICTIONARY and g.ambiance.has("niveau") and g.ambiance.has("couleur"):
		ambiant = g.ambiance.couleur
	var veille := {}
	# Seules les sources prévues en Light2D par la DA deviennent des lumières du moteur (un
	# « soleil » de clé, comme à Ullanor, est déjà peint dans les calques).
	# Une clé « mobile » (l'Empereur à l'Unification) est animée par la mise en scène, pas posée.
	var loi_apercu := false
	if String(cle.get("type", "")).contains("Light2D") and not String(cle.get("type", "")).contains("mobile"):
		var cles := lumieres_du_plan(cle)
		# Intérieur très sombre (CanvasModulate de la DA) éclairé par une seule source : la clé suit
		# la loi des aperçus de CA2, énergie·exp(−(r/portée)^1,4) sans atténuation par les normales
		# (lumière haute), sinon tout ce qui est hors de sa portée reste noir.
		var cm := ""
		for a in g.get("appoints", []) if typeof(g.get("appoints")) == TYPE_ARRAY else []:
			if typeof(a) == TYPE_DICTIONARY and String(a.get("type", "")).contains("CanvasModulate") and a.has("couleur"):
				cm = String(a.couleur)
		if not cle.has("bougies_px") and not cm.is_empty() and Color(cm).get_luminance() < 0.35:
			loi_apercu = true
		lum.append_array(cles)
	for a in g.get("appoints", []) if typeof(g.get("appoints")) == TYPE_ARRAY else []:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var type := String(a.get("type", ""))
		if type.contains("CanvasModulate") and not type.contains("Directional") and a.has("couleur"):
			ambiant = a.couleur
		elif a.has("position_px") and type.contains("Light2D"):
			lum.append_array(lumieres_du_plan(a))
		elif a.has("niveau") and a.has("couleur"):
			# Veille froide sur le fond seulement (« zone : fond et ogive ») ; ambiant ailleurs.
			veille = {"couleur": a.couleur, "niveau": float(a.niveau)}
			# « ambiant ailleurs 0.17 » ou « ambiant 0,17 ailleurs » (barge_quartiers_27).
			var m := RegEx.create_from_string("ambiant (?:ailleurs )?([0-9]+(?:[.,][0-9]+)?)").search(String(a.get("zone", "")))
			if m:
				var n := m.get_string(1).replace(",", ".").to_float()
				ambiant = Color(n, n, n).to_html(false)
	# Intérieur dont le seul ambiant est « ambiant ailleurs » d'une veille (vs_quartiers_27) : même
	# loi des aperçus pour la clé (retour DA : la lumière se concentre autour du brasero).
	if not loi_apercu and not ambiant.is_empty() and Color(ambiant).get_luminance() < 0.35 \
			and String(cle.get("type", "")).contains("Light2D") and not cle.has("bougies_px") \
			and not String(cle.get("type", "")).contains("mobile"):
		loi_apercu = true
	# Feux d'un état teinté (ullanor_nuit), comme assembler.py : chaque feu éclaire l'ALBÉDO
	# (avant la teinte d'ambiance) d'une tache aplatie au sol, exp(−d²/r²) avec y × 1,6, plus un
	# petit halo additif (0,12 × exp(−6 d²/r²)). La couleur de la Light2D est divisée par la
	# teinte des calques pour annuler celle-ci ; vacillement ±10 %, désynchronisé par feu.
	var amb_feux: Dictionary = g.ambiance if typeof(g.get("ambiance")) == TYPE_DICTIONARY else {}
	if amb_feux.has("couleur") and not amb_feux.has("niveau"):
		var t := Color(amb_feux.couleur) * float(amb_feux.get("gain", 1.0))
		for i in lum.size():
			if typeof(lum[i]) == TYPE_DICTIONARY and lum[i].get("type", "") == "feu":
				var e: Dictionary = lum[i].duplicate()
				e.profil = "feu"
				e.compense = [t.r, t.g, t.b]
				e.scintillement = 0.1
				e.halo = 0.12
				lum[i] = e
	if loi_apercu:
		# Même loi pour les appoints (hublot, couloir, traîne de la lampe).
		for e in lum:
			if not e.has("profil"):
				e.profil = "apercu"
				e.rayon_px = 3.0 * float(e.get("rayon_px", 120))
				e.hauteur_px = 1500.0
		# Les personnages gardent leur modelé : copie basse des clés, sur leur seul masque.
		var personnages := calques.filter(func(c): return typeof(c) == TYPE_DICTIONARY \
				and c.get("personnage", false) and c.get("lumiere", true))
		if not personnages.is_empty():
			for c in personnages:
				c.masque_lumiere = MASQUE_PERSONNAGES
			var modeles := []
			# Clé derrière les personnages (« vers la caméra », « contre-jour ») : la copie basse
			# est presque coupée, ils restent en silhouette (retour DA, galeries).
			var dose := ENERGIE_MODELE_CONTRE_JOUR if est_contre_jour(cle) else ENERGIE_MODELE
			for e in lum:
				if typeof(e) == TYPE_DICTIONARY and e.get("profil", "") == "apercu":
					var m: Dictionary = e.duplicate()
					m.hauteur_px = HAUTEUR_MODELE_PX
					m.intensite = float(e.get("intensite", 1.0)) * dose
					if typeof(e.get("energie_par_etat")) == TYPE_DICTIONARY:
						var pe := {}
						for nom in e.energie_par_etat:
							pe[nom] = float(e.energie_par_etat[nom]) * dose
						m.energie_par_etat = pe
					m.masque = MASQUE_PERSONNAGES
					m.erase("halo")
					modeles.append(m)
			lum.append_array(modeles)
	# « reglage_moteur » (Lead, calé sur l'aperçu validé) : {portee, energie, veille} multiplient
	# la portée et l'énergie des lumières ponctuelles et le niveau de la veille.
	var rm: Dictionary = g.reglage_moteur if typeof(g.get("reglage_moteur")) == TYPE_DICTIONARY else {}
	if not rm.is_empty():
		for e in lum:
			if typeof(e) == TYPE_DICTIONARY and e.has("position_px"):
				e.rayon_px = float(e.get("rayon_px", 120)) * float(rm.get("portee", 1.0))
				e.intensite = float(e.get("intensite", 1.0)) * float(rm.get("energie", 1.0))
		if not veille.is_empty():
			veille.niveau = float(veille.niveau) * float(rm.get("veille", 1.0))
			# « veille_teinte » : teinte seule (luminance de la couleur d'origine gardée, donc
			# l'énergie ne change pas).
			if rm.has("veille_teinte"):
				var avant := Color(veille.couleur)
				var t := Color(rm.veille_teinte)
				var k := avant.get_luminance() / maxf(t.get_luminance(), 0.001)
				veille.couleur = Color(t.r * k, t.g * k, t.b * k).to_html(false)
	return {"version": VERSION_FORMAT, "taille": g.cadre_px, "calques": calques,
		"source": "guide", "cle": cle, "lumieres": lum, "rais_force": float(g.get("rais_force", 1.0)),
		"rebond": g.get("rebond", {}),
		# Plan à lumière peinte sans « ambiance » (Ullanor) : posé à 1,0, comme assembler.py.
		"peint_sans_ambiance": not g.has("ambiance") and not plan_eclaire(g), "ambiant": ambiant, "veille": veille,
		"etats": etats_guide, "etat_initial": etats_guide.keys()[0] if not etats_guide.is_empty() else "",
		"particules": g.particules if typeof(g.get("particules")) == TYPE_ARRAY else []}


## Lumières ponctuelles décrites par la clé ou un appoint du guide de la DA : une seule
## (position_px, portee_px, energie) ou un groupe (bougies_px, energie_totale répartie).
## Le scintillement {amplitude} est désynchronisé d'une lumière à l'autre (_process).
static func lumieres_du_plan(L: Dictionary) -> Array:
	var points: Array = []
	if typeof(L.get("bougies_px")) == TYPE_ARRAY:
		points = L.bougies_px
	elif typeof(L.get("position_px")) == TYPE_ARRAY:
		points = [L.position_px]
	if points.is_empty():
		return []
	var sc = L.get("scintillement", 0.0)
	var amplitude := float(sc.get("amplitude", 0.0)) if typeof(sc) == TYPE_DICTIONARY else float(sc)
	var sortie: Array = []
	# Le guide écrit « energie » ou « force », « portee_px » (rayon d'action) ou « rayon_px ».
	var brute = L.get("energie", L.get("force", 1.0))
	var par_etat: Dictionary = brute if typeof(brute) == TYPE_DICTIONARY else {}
	var energie := float(par_etat.values()[0]) if not par_etat.is_empty() else float(brute)
	if points.size() > 1:
		# Groupe (bougies) : une lumière de groupe au barycentre, à traîne longue (profil de
		# l'aperçu de la DA : 1,4·exp(−r/380) + 0,4·exp(−r/110)), qui porte les piliers et la
		# voûte ; puis une petite lumière par bougie pour le scintillement local.
		var b = L.get("barycentre_px")
		if typeof(b) != TYPE_ARRAY:
			var somme := Vector2.ZERO
			for pt in points:
				somme += Vector2(pt[0], pt[1])
			somme /= points.size()
			b = [somme.x, somme.y]
		var total := float(L.get("energie_totale", 1.4))
		sortie.append({"position_px": b, "couleur": L.get("couleur_groupe", L.get("couleur", "#FFB060")),
			"intensite": total * 1.8 / 1.4, "rayon_px": 1100.0 / 2.5, "profil": "traine", "hauteur_px": 500.0,
			"scintillement": amplitude * 0.3})
		energie = 0.05
		for pt in points:
			sortie.append({"position_px": pt, "couleur": L.get("couleur", "#FFB060"), "intensite": energie,
				"rayon_px": float(L.get("portee_bougie_px", 120.0)) / 2.5, "scintillement": amplitude})
		return sortie
	for pt in points:
		var e := {"position_px": pt, "couleur": L.get("couleur", "#FFB060"), "intensite": energie,
			"rayon_px": float(L.get("portee_px", L.get("rayon_px", 300))) / 2.5, "scintillement": amplitude,
			"hauteur_px": 200.0}
		if not par_etat.is_empty():
			e.energie_par_etat = par_etat
		sortie.append(e)
	# Cône (lampe à main de Cthonia) : une seconde lumière orientée vers « vers_px ».
	var cone = L.get("cone")
	if typeof(cone) == TYPE_DICTIONARY and typeof(cone.get("vers_px")) == TYPE_ARRAY:
		var de := Vector2(points[0][0], points[0][1])
		var vers := Vector2(cone.vers_px[0], cone.vers_px[1])
		sortie.append({"position_px": points[0], "couleur": L.get("couleur", "#FFB060"), "intensite": energie,
			"rayon_px": de.distance_to(vers) * 1.4 / 2.5, "scintillement": amplitude, "hauteur_px": 200.0,
			"profil": "cone_%d" % int(cone.get("demi_angle_deg", 25)), "orientation": (vers - de).angle()})
	return sortie


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
	_poser_lumieres(d.get("lumieres", []))
	_poser_particules(d.get("particules", []))
	set_meta("cle", d.get("cle", {}))
	set_meta("rebond", d.get("rebond", {}))
	peint_sans_ambiance = bool(d.get("peint_sans_ambiance", false))
	for i in mini(calques.size(), d.calques.size()):
		for cle_c in ["rebond", "hors_ambiance"]:
			if d.calques[i].get(cle_c, false):
				calques[i].set_meta(cle_c, true)
	set_meta("rais_force", float(d.get("rais_force", 1.0)))
	ambiant = Color(d.ambiant) if not String(d.get("ambiant", "")).is_empty() else Color(0, 0, 0, 0)
	if not d.get("veille", {}).is_empty():
		_poser_veille(d.veille)
	else:
		_exterieur_emissif()
	etats = d.get("etats", {})
	if not String(d.get("etat_initial", "")).is_empty():
		appliquer_etat(d.etat_initial, 0.0)


# --------------------------------------------------------------------------- états

## États d'un lieu (nuit, aube…) : ciel, CanvasModulate, intensité et teinte de calques,
## énergie des lumières. Le chapitre suit « ambiant » (signal etat_change).
signal etat_change(nom: String, duree: float)
var etats: Dictionary = {}
var etat := ""


func appliquer_etat(nom: String, duree := 0.0) -> void:
	if not etats.is_empty() and not etats.has(nom):
		push_warning("Décor %s : état inconnu « %s »" % [id_decor, nom])
		return
	etat = nom
	var t: Tween = create_tween().set_parallel() if duree > 0.0 else null
	var d := lire(id_decor, dossier_decors)
	for i in calques.size():
		if i >= d.calques.size():
			break
		var k: Dictionary = d.calques[i]
		var image := calques[i].get_node(^"Image") as CanvasItem
		var cible := image.modulate
		var teinte := image.self_modulate
		if k.has("etat"):
			var dans: bool = k.etat.has(nom) if typeof(k.etat) == TYPE_ARRAY else k.etat == nom
			cible.a = 1.0 if dans else 0.0
		if typeof(k.get("intensite_par_etat")) == TYPE_DICTIONARY and k.intensite_par_etat.has(nom):
			cible.a = float(k.intensite_par_etat[nom])
		if typeof(k.get("modulate_par_etat")) == TYPE_DICTIONARY and k.modulate_par_etat.has(nom):
			var v := float(k.modulate_par_etat[nom])
			cible = Color(v, v, v, cible.a)
		if typeof(k.get("couleur_intensite_par_etat")) == TYPE_DICTIONARY and k.couleur_intensite_par_etat.has(nom):
			var ci: Array = k.couleur_intensite_par_etat[nom]
			teinte = Color(ci[0])
			teinte.a = float(ci[1])
		calques[i].visible = true
		if t:
			t.tween_property(image, "modulate", cible, duree)
			t.tween_property(image, "self_modulate", teinte, duree)
		else:
			image.modulate = cible
			image.self_modulate = teinte
	for l in get_children():
		if l is PointLight2D and l.has_meta("couleur_par_etat") and l.get_meta("couleur_par_etat").has(nom):
			var c: Color = l.get_meta("couleur_par_etat")[nom]
			if t:
				t.tween_property(l, "color", c, duree)
			else:
				l.color = c
		if l is Light2D and l.has_meta("energie_par_etat"):
			var e: Dictionary = l.get_meta("energie_par_etat")
			if e.has(nom):
				var v := float(e[nom])
				l.set_meta("energie", v)
				if t:
					t.tween_property(l, "energy", v, duree)
				else:
					l.energy = v
	var cm = etats.get(nom, {}).get("canvas_modulate") if typeof(etats.get(nom)) == TYPE_DICTIONARY else null
	if typeof(cm) == TYPE_STRING:
		ambiant = Color(cm)
		if not has_node(^"Veille"):
			_exterieur_emissif()
	etat_change.emit(nom, duree)


## Ambiance de la scène (CanvasModulate du chapitre) : les personnages proches reçoivent le
## rebond {couleur, force} du plan, et les calques « hors_ambiance » en sont compensés.
func appliquer_rebond(amb: Color) -> void:
	# Ombres en multiplication : le CanvasModulate s'applique aussi à leur sortie, donc deux fois
	# au fond ; on le compense sur l'ombre pour qu'elle reste « blanc = neutre ».
	var comp := Color(1.0 / maxf(amb.r, 0.05), 1.0 / maxf(amb.g, 0.05), 1.0 / maxf(amb.b, 0.05)) \
		if amb.a > 0.0 else Color.WHITE
	for c in calques:
		for o in c.find_children("Ombre", "Sprite2D", true, false):
			o.self_modulate = comp
	var rb: Dictionary = get_meta("rebond", {})
	var rc := Color(String(rb.get("couleur", "#FFFFFF"))) if not rb.is_empty() else Color.BLACK
	var force := float(rb.get("force", 0.0))
	for c in calques:
		if not ((c.has_meta("rebond") and force > 0.0) or c.has_meta("hors_ambiance")):
			continue
		var m := Color.WHITE
		if amb.a > 0.0:
			m = Color(1.0 / maxf(amb.r, 0.2), 1.0 / maxf(amb.g, 0.2), 1.0 / maxf(amb.b, 0.2))
		if c.has_meta("rebond"):
			m = Color(m.r * (1.0 + force * rc.r), m.g * (1.0 + force * rc.g), m.b * (1.0 + force * rc.b))
		c.modulate = Color(m.r, m.g, m.b, c.modulate.a)


## Plan à lumière peinte sans ambiance : le chapitre met son CanvasModulate à blanc.
var peint_sans_ambiance := false


## Teinte de CanvasModulate voulue par le plan (« appoints » de la DA) ; alpha 0 : aucune.
var ambiant := Color(0, 0, 0, 0)
const MASQUE_VEILLE := 2


## Plan sombre (intérieur, soir) : le ciel ou l'extérieur vu par la baie (calque 00_ non éclairé)
## garde sa propre lumière, comme dans les aperçus. Le CanvasModulate n'agit que sur son propre
## CanvasLayer : ces calques passent dans un CanvasLayer derrière la scène, qui suit la caméra.
var _couche_ciel: CanvasLayer


func _exterieur_emissif() -> void:
	if ambiant.a <= 0.0 or ambiant.get_luminance() >= 0.5 or _couche_ciel:
		return
	for c in calques:
		if not String(c.name).begins_with("Calque_00_"):
			continue
		var s := c.get_node_or_null(^"Image") as CanvasItem
		if s == null or s.light_mask & MASQUE_LUMIERE != 0:
			continue
		if _couche_ciel == null:
			_couche_ciel = CanvasLayer.new()
			_couche_ciel.name = "Ciel"
			_couche_ciel.layer = -1
			_couche_ciel.follow_viewport_enabled = true
			_couche_ciel.transform = global_transform if is_inside_tree() else transform
			_couche_ciel.visible = is_visible_in_tree()
			add_child(_couche_ciel)
			visibility_changed.connect(func(): _couche_ciel.visible = is_visible_in_tree())
		c.reparent(_couche_ciel, false)


## Veille froide qui ne touche que le fond et la voûte (calques 00_ et 10_).
func _poser_veille(v: Dictionary) -> void:
	for c in calques:
		if String(c.name).begins_with("Calque_00_") or String(c.name).begins_with("Calque_10_"):
			for s in c.find_children("*", "Sprite2D", true, false):
				s.light_mask |= MASQUE_VEILLE
	var l := DirectionalLight2D.new()
	l.name = "Veille"
	l.color = Color(v.couleur)
	l.energy = v.niveau
	l.height = 1.0
	l.range_item_cull_mask = MASQUE_VEILLE
	add_child(l)


## Lumières ponctuelles d'un état (feux du bivouac, lampes) : une PointLight2D chacune, avec
## un scintillement léger. Elles éclairent les calques « lumiere » et les personnages posés.
func _poser_lumieres(liste: Array) -> void:
	var textures := {}
	for i in liste.size():
		var L: Dictionary = liste[i]
		if L.get("type", "") == "directionnelle":
			var dl := DirectionalLight2D.new()
			dl.name = "Lumiere_%02d" % i
			dl.color = couleur_guide(L.get("couleur", "#FFFFFF"))
			dl.energy = float(L.get("intensite", 1.0))
			dl.rotation = float(L.get("orientation", 0.0))
			dl.height = float(L.get("hauteur", 0.5))
			dl.range_item_cull_mask = MASQUE_LUMIERE
			if typeof(L.get("energie_par_etat")) == TYPE_DICTIONARY:
				dl.set_meta("energie_par_etat", L.energie_par_etat)
			add_child(dl)
			continue
		if not L.has("position_px"):
			continue
		var profil: String = L.get("profil", "lineaire")
		if not textures.has(profil):
			textures[profil] = _texture_lumiere(profil)
		var l := PointLight2D.new()
		l.name = "Lumiere_%02d" % i
		l.texture = textures[profil]
		l.position = Vector2(L.position_px[0], L.position_px[1])
		l.rotation = float(L.get("orientation", 0.0))
		l.texture_scale = float(L.get("rayon_px", 120)) * 2.5 / 128.0
		if profil == "feu":
			# La texture couvre ±3 r (exp(−9) ≈ 0 au bord).
			l.texture_scale = float(L.get("rayon_px", 120)) * 6.0 / 256.0
		var coul = L.get("couleur", "#FFB060")
		if typeof(coul) == TYPE_DICTIONARY and not coul.is_empty():
			var par_etat := {}
			for nom in coul:
				par_etat[nom] = couleur_guide(coul[nom])
			l.set_meta("couleur_par_etat", par_etat)
			coul = coul.values()[0]
		l.color = couleur_guide(coul)
		l.energy = float(L.get("intensite", 1.0))
		# Hauteur (normal maps) : une lumière de groupe éclaire de face, sinon les murs tournés
		# vers la caméra ne reçoivent presque rien.
		l.height = float(L.get("hauteur_px", 40.0))
		l.range_item_cull_mask = int(L.get("masque", MASQUE_LUMIERE))
		if typeof(L.get("energie_par_etat")) == TYPE_DICTIONARY:
			l.set_meta("energie_par_etat", L.energie_par_etat)
		if typeof(L.get("compense")) == TYPE_ARRAY:
			var k: Array = L.compense
			l.color = Color(l.color.r / maxf(k[0], 0.02), l.color.g / maxf(k[1], 0.02), l.color.b / maxf(k[2], 0.02))
		var sc := float(L.get("scintillement", 0.0))
		if sc > 0.0:
			l.set_meta("energie", l.energy)
			l.set_meta("scintillement", sc)
			l.set_meta("phase", randf() * TAU)
		add_child(l)
		if float(L.get("halo", 0.0)) > 0.0:
			if not textures.has("feu_halo"):
				textures["feu_halo"] = _texture_lumiere("feu_halo")
			var h := Sprite2D.new()
			h.name = "Halo_%02d" % i
			h.texture = textures["feu_halo"]
			h.position = l.position
			h.scale = Vector2.ONE * l.texture_scale
			var add := CanvasItemMaterial.new()
			add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
			h.material = add
			h.light_mask = 0
			h.z_index = 90
			var c := couleur_guide(L.get("couleur", "#FFB060")) * float(L.get("intensite", 1.0)) * float(L.halo)
			h.modulate = Color(c.r, c.g, c.b, 1.0)
			h.set_meta("modulate_base", h.modulate)
			l.set_meta("halo", h)
			add_child(h)


## Texture radiale d'une lumière (256 px, rayon 128) : « lineaire » (feux) ou « traine »
## (décroissance exponentielle à longue traîne de l'aperçu de la DA, sur un rayon de 1100 px).
static func _texture_lumiere(profil: String) -> Texture2D:
	if profil == "feu" or profil == "feu_halo":
		# Tache de feu aplatie au sol (assembler.py) : exp(−(x² + (1,6 y)²)) sur ±3 r ; le halo est
		# 6 fois plus serré.
		var serre := 6.0 if profil == "feu_halo" else 1.0
		var img_f := Image.create(256, 256, false, Image.FORMAT_L8)
		for y in 256:
			for x in 256:
				var ux := (x - 127.5) / 128.0 * 3.0
				var uy := (y - 127.5) / 128.0 * 3.0 * 1.6
				var val := exp(-(ux * ux + uy * uy) * serre)
				img_f.set_pixel(x, y, Color(val, val, val))
		return ImageTexture.create_from_image(img_f)
	if profil.begins_with("cone_"):
		# Cône doux vers +x (la lumière est tournée par « orientation ») : décroissance radiale
		# et bords angulaires adoucis.
		var demi := deg_to_rad(float(profil.trim_prefix("cone_")))
		var img := Image.create(256, 256, false, Image.FORMAT_L8)
		for y in 256:
			for x in 256:
				var v := Vector2(x - 128 + 0.5, y - 128 + 0.5) / 128.0
				var r := v.length()
				var a := absf(v.angle())
				var radial := clampf(1.0 - r, 0.0, 1.0)
				var angulaire := clampf(1.0 - (a - demi * 0.6) / (demi * 0.8), 0.0, 1.0)
				var val := radial * radial * angulaire if r > 0.0 else 1.0
				img.set_pixel(x, y, Color(val, val, val))
		return ImageTexture.create_from_image(img)
	var g := Gradient.new()
	if profil == "traine":
		var offsets := PackedFloat32Array()
		var couleurs := PackedColorArray()
		for i in 17:
			var t := i / 16.0
			var r := t * 1100.0
			var v := (1.4 * exp(-r / 380.0) + 0.4 * exp(-r / 110.0)) / 1.8
			if i == 16:
				v = 0.0
			offsets.append(t)
			couleurs.append(Color(v, v, v, 1.0))
		g.offsets = offsets
		g.colors = couleurs
	elif profil == "apercu":
		# exp(−(r/portée)^1,4) sur un rayon de 3 portées (aperçus de CA2).
		var offsets := PackedFloat32Array()
		var couleurs := PackedColorArray()
		for i in 25:
			var t := i / 24.0
			var v := exp(-pow(3.0 * t, 1.4)) if i < 24 else 0.0
			offsets.append(t)
			couleurs.append(Color(v, v, v, 1.0))
		g.offsets = offsets
		g.colors = couleurs
	else:
		g.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


# --------------------------------------------------------------------------- particules

## Particules vivantes d'un décor peint (« particules » du guide) : chacune est posée dans un
## calque (« calque » : son nom, sans « Calque_ ») pour suivre sa parallaxe, sur une zone en px :
##   {"type": "fumee" | "braises" | "poussiere", "calque": "20_titans", "zone": [x, y, w, h],
##    "nombre": 12, "vent": [vx, vy]}
## Textures générées (pas d'image à livrer) ; préremplies pour être déjà là au premier plan.
func _poser_particules(liste: Array) -> void:
	for p in liste:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var couche: Node = get_node_or_null("Calque_" + String(p.get("calque", "")))
		if couche == null:
			push_warning("Décor %s : particules sur un calque absent (%s)" % [id_decor, p.get("calque")])
			continue
		couche.add_child(particules(p))


static func particules(p: Dictionary) -> CPUParticles2D:
	var type := String(p.get("type", "poussiere"))
	var z: Array = p.get("zone", [0, 0, 100, 100])
	var e := CPUParticles2D.new()
	e.name = "Particules_" + type
	e.local_coords = true
	e.position = Vector2(float(z[0]) + float(z[2]) / 2.0, float(z[1]) + float(z[3]) / 2.0)
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	e.emission_rect_extents = Vector2(float(z[2]), float(z[3])) / 2.0
	var vent := Vector2(5, -2)
	if typeof(p.get("vent")) == TYPE_ARRAY and p.vent.size() == 2:
		vent = Vector2(float(p.vent[0]), float(p.vent[1]))
	e.gravity = vent
	var rampe := Gradient.new()
	var echelle := Curve.new()
	match type:
		"fumee":
			e.amount = int(p.get("nombre", 14))
			e.lifetime = 10.0
			e.direction = Vector2(0.2, -1)
			e.spread = 12.0
			e.initial_velocity_min = 8.0
			e.initial_velocity_max = 16.0
			e.scale_amount_min = 0.5
			e.scale_amount_max = 0.8
			echelle.add_point(Vector2(0, 0.4))
			echelle.add_point(Vector2(1, 2.6))
			rampe.colors = PackedColorArray([Color(0.42, 0.37, 0.33, 0.0), Color(0.42, 0.37, 0.33, 0.32), Color(0.5, 0.45, 0.4, 0.0)])
			rampe.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
			e.texture = _tache(64, 0.0)
			e.angular_velocity_min = -6.0
			e.angular_velocity_max = 6.0
			if p.get("bouffees", false):
				# Évents de machine : la fumée sort par bouffées (une par « cadence_s »), pas en filet.
				e.lifetime = float(p.get("cadence_s", 7.0))
				e.explosiveness = 0.75
				e.randomness = 0.3
				e.lifetime_randomness = 0.25
		"braises":
			e.amount = int(p.get("nombre", 30))
			e.lifetime = 5.0
			e.direction = Vector2(0.3, -1)
			e.spread = 25.0
			e.initial_velocity_min = 12.0
			e.initial_velocity_max = 34.0
			e.tangential_accel_min = -8.0
			e.tangential_accel_max = 8.0
			e.scale_amount_min = 0.6
			e.scale_amount_max = 1.2
			echelle.add_point(Vector2(0, 1.0))
			echelle.add_point(Vector2(1, 0.3))
			rampe.colors = PackedColorArray([Color(1.0, 0.75, 0.35, 0.0), Color(1.0, 0.6, 0.2, 0.9), Color(0.8, 0.25, 0.08, 0.0)])
			rampe.offsets = PackedFloat32Array([0.0, 0.1, 1.0])
			e.texture = _tache(8, 0.5)
			var add := CanvasItemMaterial.new()
			add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			e.material = add
		_:
			e.amount = int(p.get("nombre", 50))
			e.lifetime = 14.0
			e.direction = Vector2(1, -0.2)
			e.spread = 60.0
			e.initial_velocity_min = 2.0
			e.initial_velocity_max = 7.0
			e.scale_amount_min = 0.4
			e.scale_amount_max = 1.0
			echelle.add_point(Vector2(0, 1.0))
			echelle.add_point(Vector2(1, 1.0))
			rampe.colors = PackedColorArray([Color(1.0, 0.93, 0.78, 0.0), Color(1.0, 0.93, 0.78, 0.45), Color(1.0, 0.93, 0.78, 0.0)])
			rampe.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
			e.texture = _tache(6, 0.3)
			var add2 := CanvasItemMaterial.new()
			add2.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			e.material = add2
	e.color_ramp = rampe
	e.scale_amount_curve = echelle
	e.preprocess = e.lifetime
	e.light_mask = MASQUE_HALO
	return e


## Tache ronde douce (fumée, braise, grain de poussière) : rayon en px, cœur plein jusqu'à « coeur ».
static func _tache(taille: int, coeur: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([coeur, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = taille
	t.height = taille
	return t


func _process(_delta: float) -> void:
	# Scintillement des feux : bruit lent et propre à chaque lumière.
	var t := Time.get_ticks_msec() / 1000.0
	for l in get_children():
		if l is PointLight2D and l.has_meta("scintillement"):
			var e: float = l.get_meta("energie")
			var sc: float = l.get_meta("scintillement")
			var ph: float = l.get_meta("phase", 0.0)
			var f := 1.0 + sc * (sin(t * 7.3 + l.position.x + ph) * 0.6 + sin(t * 13.1 + l.position.y + ph * 1.7) * 0.4)
			l.energy = e * f
			if l.has_meta("halo") and is_instance_valid(l.get_meta("halo")):
				var h: Sprite2D = l.get_meta("halo")
				var b: Color = h.get_meta("modulate_base")
				h.modulate = Color(b.r * f, b.g * f, b.b * f, 1.0)


func _creer_calque(dossier: String, k: Dictionary, index: int) -> Parallax2D:
	# Une échelle nulle rend la transformée de Parallax2D non inversible : plancher minuscule.
	var p := maxf(float(k.get("profondeur", 1.0)), 0.0001)
	var couche := Parallax2D.new()
	# Nom de nœud sans « / » (les fichiers du guide sont dans calques/) : Calque_45_vaskar.
	couche.name = "Calque_%s" % k.get("nom", String(k.fichier).get_file().get_basename())
	# Gabarit de la DA tenant la place d'un calque pas encore livré : pas des personnages peints.
	couche.set_meta("gabarit", String(k.fichier).get_file().begins_with("gabarit_"))
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
		tex = _texture_avec_normales(dossier, k.tete.corps, k.tete.get("plat", true))
	var sprite := Sprite2D.new()
	sprite.name = "Image"
	sprite.texture = tex
	sprite.centered = false
	if k.has("position"):
		sprite.position = Vector2(k.position[0], k.position[1])
	sprite.light_mask = int(k.get("masque_lumiere", MASQUE_LUMIERE)) if k.get("lumiere", true) else MASQUE_HALO
	if typeof(k.get("vie")) == TYPE_DICTIONARY and not k.has("tete"):
		var m := materiau_vivant(k.vie, tex.diffuse_texture)
		if k.has("voile"):
			m.set_shader_parameter("voile", Color(k.voile[0]))
			m.set_shader_parameter("force", float(k.voile[1]))
		sprite.material = m
	elif est_foule(k):
		var m := materiau_foule(tex.diffuse_texture, String(couche.name),
			k.foule if typeof(k.get("foule")) == TYPE_DICTIONARY else {})
		if k.has("voile"):
			m.set_shader_parameter("voile", Color(k.voile[0]))
			m.set_shader_parameter("force", float(k.voile[1]))
		sprite.material = m
	elif k.has("voile") and float(k.voile[1]) > 0.0:
		var m := materiau_voile()
		m.set_shader_parameter("voile", Color(k.voile[0]))
		m.set_shader_parameter("force", float(k.voile[1]))
		sprite.material = m
	elif k.get("melange", "") == "addition" and (k.has("force") or k.has("durete")):
		# Liseré additif dosé : alpha^durete resserre un halo peint en arête fine (retour DA,
		# 41_lisere_froid de vs_galerie), force le dose.
		var ml := ShaderMaterial.new()
		ml.shader = _shader_lisere()
		ml.set_shader_parameter("force", float(k.get("force", 1.0)))
		ml.set_shader_parameter("durete", float(k.get("durete", 1.0)))
		sprite.material = ml
	elif k.get("melange", "") == "addition":
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = add
	if k.has("teinte"):
		sprite.self_modulate = Color(k.teinte)
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
		ombre.material = materiau_ombre()
		couche.add_child(ombre)
	add_child(couche)
	return couche


## Texture couleur + normales d'une partie ; préfère la version plate (_plat, _plat_normal).
static func _texture_avec_normales(dossier: String, fichier: String, plat_permis := true) -> CanvasTexture:
	var base := fichier.get_basename()
	var tex := CanvasTexture.new()
	var plat := plat_permis and ResourceLoader.exists(dossier.path_join(base + "_plat.png"))
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
		s.texture = _texture_avec_normales(dossier, t.fichier if partie == "tete" else t.avant, t.get("plat", true))
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


## Ombre portée en multiplication, dosée par son alpha comme dans assembler.py :
## img × (1 − a·(1 − rvb)). Le mélange MUL de Godot ignore l'alpha : une ombre livrée en RVB noir
## sous un alpha partiel (Astartes des quartiers) noircissait tout le décor.
const SHADER_OMBRE := """
shader_type canvas_item;
render_mode blend_mul;
varying vec4 modulation;
void vertex() {
	modulation = COLOR;
}
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	COLOR = vec4(mix(vec3(1.0), t.rgb, t.a) * modulation.rgb, 1.0);
}
"""
static var _shader_ombre: Shader


static func materiau_ombre() -> ShaderMaterial:
	if _shader_ombre == null:
		_shader_ombre = Shader.new()
		_shader_ombre.code = SHADER_OMBRE
	var m := ShaderMaterial.new()
	m.shader = _shader_ombre
	return m


static var _lisere: Shader
static func _shader_lisere() -> Shader:
	if _lisere == null:
		_lisere = Shader.new()
		_lisere.code = """shader_type canvas_item;
render_mode blend_add;
uniform float force = 1.0;
uniform float durete = 1.0;
void fragment() {
	COLOR = vec4(COLOR.rgb, pow(COLOR.a, durete) * force);
}
"""
	return _lisere


static func materiau_voile() -> ShaderMaterial:
	if _shader_voile == null:
		_shader_voile = Shader.new()
		_shader_voile.code = SHADER_VOILE
	var m := ShaderMaterial.new()
	m.shader = _shader_voile
	return m


## Calque de foule peinte : « foule »: true/false dans le JSON, sinon tout calque dont le
## fichier parle de « personnages » (40_personnages, 25_personnages_fond et leurs gabarits).
## Pas de foule sur un calque à tête livrée à part (la tête a son propre mouvement) ni sur
## les particules en addition.
static func est_foule(k: Dictionary) -> bool:
	if k.has("tete") or k.get("melange", "") == "addition":
		return false
	if typeof(k.get("foule")) == TYPE_DICTIONARY:
		return true
	if k.has("foule"):
		return bool(k.foule)
	var nom := String(k.get("nom", String(k.get("fichier", "")).get_file().get_basename()))
	return nom.contains("personnages")


## « foule » peut régler le mouvement : {"respiration", "balancement", "vitesse"} (les Titans
## d'Ullanor respirent plus lentement et plus faiblement qu'une foule).
static func materiau_foule(image: Texture2D, graine := "", reglages: Dictionary = {}) -> ShaderMaterial:
	if _shader_foule == null:
		_shader_foule = Shader.new()
		_shader_foule.code = SHADER_FOULE
	var m := ShaderMaterial.new()
	m.shader = _shader_foule
	m.set_shader_parameter("respiration", float(reglages.get("respiration", FOULE_RESPIRATION)))
	m.set_shader_parameter("balancement", float(reglages.get("balancement", FOULE_BALANCEMENT)))
	m.set_shader_parameter("vitesse", float(reglages.get("vitesse", 1.0)))
	m.set_shader_parameter("graine", float(absi(hash(graine)) % 1000) / 100.0)
	if image:
		m.set_shader_parameter("taille_px", Vector2(image.get_size()))
		m.set_shader_parameter("pieds", ImageTexture.create_from_image(lignes_de_pieds(image.get_image())))
	return m


## Matériau d'un calque qui vit (bloc « vie ») :
##   "derive": [amplitude_px, echelle_px, vitesse_x, vitesse_y]   fumées, poussière
##   "drapeaux": [[x, y_haut, largeur, hauteur], …], "drapeau_px": amplitude au bas du tissu
##   "souffle": [amplitude_px au sommet, période_s, ligne_de_sol_y_px]
##   "tetes": [[x, y, largeur, hauteur], …] (4 au plus), "tete_px": balayage maximal
##   "tressaillement": [amplitude_px, ligne_de_sol_y_px]
static func materiau_vivant(vie: Dictionary, image: Texture2D) -> ShaderMaterial:
	if _shader_vivant == null:
		_shader_vivant = Shader.new()
		_shader_vivant.code = SHADER_VIVANT
	var m := ShaderMaterial.new()
	m.shader = _shader_vivant
	var taille := Vector2(image.get_size()) if image else Vector2(1920, 1080)
	m.set_shader_parameter("taille_px", taille)
	var dv: Array = vie.get("derive", [])
	if dv.size() >= 2:
		m.set_shader_parameter("derive_px", float(dv[0]))
		m.set_shader_parameter("derive_echelle_px", float(dv[1]))
		if dv.size() >= 4:
			m.set_shader_parameter("derive_vitesse", Vector2(float(dv[2]), float(dv[3])))
	var so: Array = vie.get("souffle", [])
	if so.size() >= 3:
		m.set_shader_parameter("souffle_px", float(so[0]))
		m.set_shader_parameter("souffle_periode", float(so[1]))
		m.set_shader_parameter("souffle_sol_px", float(so[2]))
	var tetes: Array = vie.get("tetes", [])
	if not tetes.is_empty():
		var rects: Array[Vector4] = []
		for r in tetes.slice(0, 4):
			rects.append(Vector4(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
		while rects.size() < 4:
			rects.append(Vector4.ZERO)
		m.set_shader_parameter("tetes", rects)
		m.set_shader_parameter("tetes_n", mini(tetes.size(), 4))
		m.set_shader_parameter("tete_px", float(vie.get("tete_px", 3.0)))
	var tr: Array = vie.get("tressaillement", [])
	if tr.size() >= 2:
		m.set_shader_parameter("tressaillement_px", float(tr[0]))
		m.set_shader_parameter("souffle_sol_px", float(tr[1]))
	var dr: Array = vie.get("drapeaux", [])
	if not dr.is_empty():
		m.set_shader_parameter("drapeau_px", float(vie.get("drapeau_px", 2.0)))
		m.set_shader_parameter("drapeaux", ImageTexture.create_from_image(masque_drapeaux(dr, taille)))
	return m


## Masque des tissus suspendus, à la moitié de la taille de l'image : R = ampleur (0 au point
## d'attache, 1 en bas, plus grande pour un grand drapeau), G = phase, B = vitesse propre.
## Le rectangle est élargi de 2 px de chaque côté pour que le bord du tissu puisse onduler.
static func masque_drapeaux(rects: Array, taille: Vector2) -> Image:
	var w := maxi(1, int(taille.x) / 2)
	var h := maxi(1, int(taille.y) / 2)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1729
	for r in rects:
		if typeof(r) != TYPE_ARRAY or r.size() < 4:
			continue
		var x0 := int(float(r[0]) - 2.0) / 2
		var x1 := int(float(r[0]) + float(r[2]) + 2.0) / 2
		var y0 := int(float(r[1])) / 2
		var y1 := int(float(r[1]) + float(r[3])) / 2
		var ampleur := clampf(float(r[2]) / 32.0, 0.35, 1.0)
		var phase := rng.randf()
		var vitesse := rng.randf()
		for y in range(maxi(y0, 0), mini(y1 + 1, h)):
			var k := clampf(float(y - y0) / maxf(1.0, float(y1 - y0)), 0.0, 1.0)
			k = pow(k, 1.3) * ampleur
			for x in range(maxi(x0, 0), mini(x1 + 1, w)):
				img.set_pixel(x, y, Color(k, phase, vitesse))
	return img


## Ligne des pieds de chaque colonne (FOULE_COLONNE_PX de large) : le bas de la silhouette,
## en fraction de la hauteur (canal rouge, 1 × colonnes). Une colonne vide prend la valeur de
## sa voisine non vide la plus proche : le balancement peut y pousser une figure sans saut.
## Image entièrement vide : 0 partout (rien ne bouge).
static func lignes_de_pieds(img: Image) -> Image:
	var colonnes := maxi(1, ceili(img.get_width() / float(FOULE_COLONNE_PX)))
	var sortie := Image.create(colonnes, 1, false, Image.FORMAT_RF)
	if img.is_empty():
		return sortie
	var petite := img.duplicate() as Image
	if petite.is_compressed():
		petite.decompress()
	petite.convert(Image.FORMAT_RGBA8)
	# Réduite en moyenne de surface (mipmaps, pas de rebond) et en hauteur aussi (pas de 4 px).
	var hauteur := maxi(1, img.get_height() / 4)
	petite.resize(colonnes, hauteur, Image.INTERPOLATE_TRILINEAR)
	var octets := petite.get_data()
	var pieds := PackedFloat32Array()
	pieds.resize(colonnes)
	for x in colonnes:
		pieds[x] = -1.0
		for y in range(hauteur - 1, -1, -1):
			if octets[(y * colonnes + x) * 4 + 3] > 24:
				pieds[x] = (y + 1.0) / hauteur
				break
	# Colonnes vides : valeur de la plus proche colonne pleine (passe aller puis retour).
	var derniere := -1.0
	var distance := PackedInt32Array()
	distance.resize(colonnes)
	var rempli := pieds.duplicate()
	var n := 1 << 30
	for x in colonnes:
		if pieds[x] >= 0.0:
			derniere = pieds[x]
			n = 0
		else:
			n += 1
		rempli[x] = derniere
		distance[x] = n
	derniere = -1.0
	n = 1 << 30
	for x in range(colonnes - 1, -1, -1):
		if pieds[x] >= 0.0:
			derniere = pieds[x]
			n = 0
		else:
			n += 1
		if n < distance[x]:
			rempli[x] = derniere
	for x in colonnes:
		sortie.set_pixel(x, 0, Color(maxf(rempli[x], 0.0), 0, 0))
	return sortie


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


## Couleur écrite par la DA : « #RRGGBB », ou « mélange #A / #B à 55 % » (55 % de B).
static func couleur_guide(v) -> Color:
	if typeof(v) == TYPE_COLOR:
		return v
	var texte := String(v)
	var re := RegEx.create_from_string("#[0-9A-Fa-f]{6}")
	var trouves := re.search_all(texte)
	if trouves.is_empty():
		return Color(texte) if Color.html_is_valid(texte) else Color("#FFB060")
	var c := Color(trouves[0].get_string())
	if trouves.size() > 1 and texte.contains("%"):
		var pct := RegEx.create_from_string("(\\d+)\\s*%").search(texte)
		if pct:
			c = c.lerp(Color(trouves[1].get_string()), float(pct.get_string(1)) / 100.0)
	return c
