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
## prend la moyenne des nombres ; 0 si aucun nombre (« derrière la porte »).
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
	for k in g.get("calques", []):
		if typeof(k) != TYPE_DICTIONARY or not k.has("fichier"):
			calques.append(k)
			continue
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
			if k.get("ambiance", true) == false:
				c.hors_ambiance = true
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
		if amb.has("couleur") and not amb.has("niveau") and k.get("ambiance", true):
			var t := Color(amb.couleur) * float(amb.get("gain", 1.0))
			t.a = 1.0
			c.teinte = t.to_html()
		if typeof(k.get("tete")) == TYPE_DICTIONARY:
			var t: Dictionary = k.tete
			var manquants := ["corps", "fichier", "avant"].filter(
				func(cle): return t.has(cle) and not ResourceLoader.exists(dossier.path_join(t[cle])))
			if not t.has("pivot_px") or not t.has("fichier") or not t.has("corps") or not manquants.is_empty():
				push_warning("Décor %s : bloc « tete » de %s incomplet, ignoré (%s)" % [g.get("plan", "?"), f, manquants])
			else:
				c.tete = t.duplicate()
				c.tete["plat"] = eclaire
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
			var m := RegEx.create_from_string("ambiant ailleurs ([0-9.]+)").search(String(a.get("zone", "")))
			if m:
				var n := float(m.get_string(1))
				ambiant = Color(n, n, n).to_html(false)
	if loi_apercu:
		# Même loi pour les appoints (hublot, couloir, traîne de la lampe).
		for e in lum:
			if not e.has("profil"):
				e.profil = "apercu"
				e.rayon_px = 3.0 * float(e.get("rayon_px", 120))
				e.hauteur_px = 1500.0
	return {"version": VERSION_FORMAT, "taille": g.cadre_px, "calques": calques,
		"source": "guide", "cle": cle, "lumieres": lum, "rais_force": float(g.get("rais_force", 1.0)),
		"rebond": g.get("rebond", {}),
		# Plan à lumière peinte sans « ambiance » (Ullanor) : posé à 1,0, comme assembler.py.
		"peint_sans_ambiance": not g.has("ambiance") and not plan_eclaire(g), "ambiant": ambiant, "veille": veille,
		"etats": etats_guide, "etat_initial": etats_guide.keys()[0] if not etats_guide.is_empty() else ""}


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
		l.range_item_cull_mask = MASQUE_LUMIERE | 1
		if typeof(L.get("energie_par_etat")) == TYPE_DICTIONARY:
			l.set_meta("energie_par_etat", L.energie_par_etat)
		var sc := float(L.get("scintillement", 0.0))
		if sc > 0.0:
			l.set_meta("energie", l.energy)
			l.set_meta("scintillement", sc)
		add_child(l)


## Texture radiale d'une lumière (256 px, rayon 128) : « lineaire » (feux) ou « traine »
## (décroissance exponentielle à longue traîne de l'aperçu de la DA, sur un rayon de 1100 px).
static func _texture_lumiere(profil: String) -> Texture2D:
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


func _process(_delta: float) -> void:
	# Scintillement des feux : bruit lent et propre à chaque lumière.
	var t := Time.get_ticks_msec() / 1000.0
	for l in get_children():
		if l is PointLight2D and l.has_meta("scintillement"):
			var e: float = l.get_meta("energie")
			var sc: float = l.get_meta("scintillement")
			l.energy = e * (1.0 + sc * (sin(t * 7.3 + l.position.x) * 0.6 + sin(t * 13.1 + l.position.y) * 0.4))


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
		tex = _texture_avec_normales(dossier, k.tete.corps, k.tete.get("plat", true))
	var sprite := Sprite2D.new()
	sprite.name = "Image"
	sprite.texture = tex
	sprite.centered = false
	if k.has("position"):
		sprite.position = Vector2(k.position[0], k.position[1])
	sprite.light_mask = MASQUE_LUMIERE if k.get("lumiere", true) else MASQUE_HALO
	if k.has("voile") and float(k.voile[1]) > 0.0:
		var m := materiau_voile()
		m.set_shader_parameter("voile", Color(k.voile[0]))
		m.set_shader_parameter("force", float(k.voile[1]))
		sprite.material = m
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
		var mul := CanvasItemMaterial.new()
		mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		ombre.material = mul
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
