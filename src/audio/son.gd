extends Node
## Son du jeu (autoload « Son ») : une ambiance, une musique et des bruitages, chacun sur son bus.
##
##   Son.ambiance("ullanor_vent", 2.0)   boucle d'ambiance, fondu enchaîné (assets/audio/amb_<nom>.ogg)
##   Son.musique("ullanor_horus", 2.0)   boucle de musique, fondu enchaîné (assets/audio/mus_<nom>.ogg)
##   Son.bruitage("eboulement")          un coup (sfx_<nom>.ogg, ou une variante sfx_<nom>_NN.ogg au hasard)
##   Son.couper("musique", 0.5)          « ambiance » ou « musique » ; durée 0 : coupe net
##
## Un fichier absent ne fait rien (ni erreur ni avertissement) : les tests et les parcours headless
## tournent sans assets audio et avec le pilote factice. Tous les sons sont générés par
## tools/son/generer_ullanor.py (traçabilité : assets/audio/SOURCES.md).

const DOSSIER := "res://assets/audio/"
const BUS := {"musique": &"Musique", "ambiance": &"Ambiance", "bruitage": &"Bruitages"}
## Volumes de départ des bus (dB), à régler au mixage.
const VOLUMES := {&"Musique": -4.0, &"Ambiance": -2.0, &"Bruitages": 0.0}
const SILENCE_DB := -60.0

## Lecteur en cours par canal (« musique », « ambiance »), et nom du son qu'il joue.
var _courant := {}
var _nom_courant := {}
var _cache := {}
## Faux avec le pilote audio factice (--headless : tests, parcours CI) : rien n'est joué. Le
## pilote factice ne mixe pas, et des lectures lancées n'y seraient jamais libérées à la sortie.
var actif := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	actif = AudioServer.get_driver_name() != "Dummy"
	for nom in VOLUMES:
		if AudioServer.get_bus_index(nom) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, nom)
			AudioServer.set_bus_send(i, &"Master")
			AudioServer.set_bus_volume_db(i, VOLUMES[nom])


## À la sortie (quit, fin d'un parcours headless) : on arrête tout et on lâche les flux, sinon le
## moteur signale des ressources encore en usage.
func _exit_tree() -> void:
	for p in get_children():
		if p is AudioStreamPlayer:
			(p as AudioStreamPlayer).stop()
			p.stream = null
	_courant.clear()
	_nom_courant.clear()
	_cache.clear()


func ambiance(nom: String, fondu := 2.0) -> void:
	_boucle("ambiance", "amb_" + nom, fondu)


func musique(nom: String, fondu := 2.0) -> void:
	if nom == "stop" or nom.is_empty():
		couper("musique", fondu)
	else:
		_boucle("musique", "mus_" + nom, fondu)


## Joue un bruitage une fois. Renvoie le lecteur (pour régler volume ou hauteur), ou null.
func bruitage(nom: String, volume_db := 0.0, hauteur := 1.0) -> AudioStreamPlayer:
	var flux := _flux_bruitage(nom)
	if flux == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = flux
	p.bus = BUS.bruitage
	p.volume_db = volume_db
	p.pitch_scale = hauteur
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


## Bruitage en boucle (la poutre de la QTE…) : le lecteur reste à l'appelant, qui l'arrête.
func boucle_bruitage(nom: String, volume_db := SILENCE_DB) -> AudioStreamPlayer:
	var flux := _charger("sfx_" + nom, true)
	if flux == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = flux
	p.bus = BUS.bruitage
	p.volume_db = volume_db
	add_child(p)
	p.play()
	return p


func couper(canal: String, fondu := 1.0) -> void:
	var p: AudioStreamPlayer = _courant.get(canal)
	_courant.erase(canal)
	_nom_courant.erase(canal)
	_eteindre(p, fondu)


## Nom du son joué sur un canal (« » si rien) : pour les tests.
func en_cours(canal: String) -> String:
	return _nom_courant.get(canal, "")


func existe(nom_fichier: String) -> bool:
	return ResourceLoader.exists(DOSSIER + nom_fichier + ".ogg")


# ---------------------------------------------------------------------------

func _boucle(canal: String, fichier: String, fondu: float) -> void:
	if _nom_courant.get(canal, "") == fichier:
		return
	var flux := _charger(fichier, true)
	var ancien: AudioStreamPlayer = _courant.get(canal)
	_eteindre(ancien, fondu)
	_courant.erase(canal)
	_nom_courant.erase(canal)
	if flux == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = flux
	p.bus = BUS[canal]
	p.volume_db = SILENCE_DB if fondu > 0.0 else 0.0
	add_child(p)
	p.play()
	if fondu > 0.0:
		create_tween().tween_property(p, "volume_db", 0.0, fondu).set_trans(Tween.TRANS_SINE)
	_courant[canal] = p
	_nom_courant[canal] = fichier


func _eteindre(p: AudioStreamPlayer, fondu: float) -> void:
	if p == null or not is_instance_valid(p):
		return
	if fondu <= 0.0:
		p.queue_free()
		return
	var t := create_tween()
	t.tween_property(p, "volume_db", SILENCE_DB, fondu).set_trans(Tween.TRANS_SINE)
	t.tween_callback(p.queue_free)


func _flux_bruitage(nom: String) -> AudioStream:
	var seul := _charger("sfx_" + nom, false)
	if seul:
		return seul
	var variantes: Array[AudioStream] = []
	for i in range(1, 100):
		var v := _charger("sfx_%s_%02d" % [nom, i], false)
		if v == null:
			break
		variantes.append(v)
	return variantes.pick_random() if not variantes.is_empty() else null


func _charger(fichier: String, boucle: bool) -> AudioStream:
	if not actif:
		return null
	var cle := fichier + ("@boucle" if boucle else "")
	if _cache.has(cle):
		return _cache[cle]
	var chemin := DOSSIER + fichier + ".ogg"
	var flux: AudioStream = null
	if ResourceLoader.exists(chemin):
		flux = load(chemin)
		if boucle and flux is AudioStreamOggVorbis:
			flux = flux.duplicate()
			(flux as AudioStreamOggVorbis).loop = true
	_cache[cle] = flux
	return flux
