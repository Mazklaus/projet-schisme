class_name FormatDialogue
extends RefCounted
## Analyseur du format de dialogue en texte (.dlg), écrit par la narration.
##
##   // commentaire (ligne ignorée, comme les lignes vides)
##   === nom_du_noeud                 début d'un nœud
##   LOKEN: Les ordres sont arrivés.  réplique (nom en majuscules, puis « : »)
##   TARIK (inquiet): Isstvan…        réplique avec une humeur (pose, expression)
##   > La flotte quitte l'orbite.     narration, sans personnage
##   * Obéir -> obeir                 choix ; les « * » consécutifs forment un seul menu
##   * Refuser -> refus [si loyal]    condition : drapeau vrai ([si non loyal] : faux,
##                                    [si relation_dremm >= 2] : comparaison à un entier)
##   *! 8 -> obeir                    délai du menu : sans réponse en 8 s, saute à « obeir »
##   ~ loyal = true                   affecte un drapeau (true, false, entier, "texte")
##   ~ relation_dremm += 1            ajoute (ou « -= » retire) à un drapeau entier
##   -> suite                         saut ; « -> FIN » termine le dialogue
##   -> trahison [si non loyal]       saut conditionnel
##   @cine isstvan_ouverture          commande pour la scène (ciné, caméra, son, lumière…) ;
##                                    les mots suivants sont ses arguments
##
## Le résultat : {"noeuds": {nom: [instructions]}, "ordre": [noms], "erreurs": [texte]}.
## Une instruction est un dictionnaire {"type": …, "ligne": n, …}.

const FIN := "FIN"

static var _re_noeud := RegEx.create_from_string("^===\\s*([A-Za-z0-9_]+)\\s*$")
static var _re_replique := RegEx.create_from_string("^([A-ZÀ-ÖØ-Þ0-9_' -]+?)\\s*(?:\\(([^)]*)\\))?\\s*:\\s*(.+)$")
static var _re_choix := RegEx.create_from_string("^\\*\\s*(.+?)\\s*->\\s*([A-Za-z0-9_]+)\\s*(?:\\[si\\s+([^\\]]+)\\])?\\s*$")
static var _re_delai := RegEx.create_from_string("^\\*!\\s*([0-9]+(?:\\.[0-9]+)?)\\s*->\\s*([A-Za-z0-9_]+)\\s*$")
static var _re_saut := RegEx.create_from_string("^->\\s*([A-Za-z0-9_]+)\\s*(?:\\[si\\s+([^\\]]+)\\])?\\s*$")
static var _re_affect := RegEx.create_from_string("^~\\s*([A-Za-z0-9_]+)\\s*(=|\\+=|-=)\\s*(.+)$")
static var _re_condition := RegEx.create_from_string("^(non\\s+)?([A-Za-z0-9_]+)\\s*(?:(>=|<=|==|!=|>|<)\\s*(-?[0-9]+|true|false|vrai|faux))?$")
static var _re_commande := RegEx.create_from_string("^@([A-Za-z0-9_]+)\\s*(.*)$")


## Charge un .dlg. Une ligne « @inclure <fichier.dlg> » avant le premier nœud reprend les nœuds
## d'un autre dialogue (chemin relatif au fichier) : les nœuds du fichier courant priment, ce
## qui permet de réutiliser une scène et d'en réécrire seulement la sortie. « @reprendre
## <fichier>:<nœud> » saute à un nœud repris.
static func charger(chemin: String, _deja: Array = []) -> Dictionary:
	if not FileAccess.file_exists(chemin):
		return {"noeuds": {}, "ordre": [], "erreurs": ["fichier introuvable : " + chemin]}
	var texte := FileAccess.get_file_as_string(chemin)
	var d := analyser(texte)
	for ligne in texte.split("\n"):
		var l := ligne.strip_edges()
		if l.begins_with("==="):
			break
		if not l.begins_with("@inclure "):
			continue
		var autre := chemin.get_base_dir().path_join(l.trim_prefix("@inclure ").strip_edges())
		if autre in _deja:
			d.erreurs.append("inclusion circulaire : " + autre)
			continue
		var inclus := charger(autre, _deja + [chemin])
		for e in inclus.erreurs:
			d.erreurs.append("%s : %s" % [autre.get_file(), e])
		for nom in inclus.ordre:
			if not d.noeuds.has(nom):
				d.noeuds[nom] = inclus.noeuds[nom]
				d.ordre.append(nom)
	# Les cibles vers des nœuds inclus ne sont connues qu'ici.
	d.erreurs = d.erreurs.filter(func(e: String): return not (e.contains("cible « ") and e.contains(" inconnue")))
	_verifier_cibles(d.noeuds, d.erreurs)
	return d


static func analyser(texte: String) -> Dictionary:
	var noeuds := {}
	var ordre: Array[String] = []
	var erreurs: Array[String] = []
	var courant: Array = []
	var nom_courant := ""
	var lignes := texte.split("\n")
	for n in lignes.size():
		var num := n + 1
		var l := lignes[n].strip_edges()
		if l.is_empty() or l.begins_with("//"):
			continue
		var m := _re_noeud.search(l)
		if m:
			nom_courant = m.get_string(1)
			courant = []
			if noeuds.has(nom_courant):
				# Le doublon est analysé (pour signaler ses erreurs) mais n'écrase pas le premier.
				erreurs.append("ligne %d : nœud « %s » en double" % [num, nom_courant])
			else:
				noeuds[nom_courant] = courant
				ordre.append(nom_courant)
			continue
		if nom_courant.is_empty():
			if not l.begins_with("@inclure "):
				erreurs.append("ligne %d : texte avant le premier « === nœud »" % num)
			continue
		var instr := _instruction(l)
		if instr.is_empty():
			erreurs.append("ligne %d : syntaxe inconnue : %s" % [num, l])
			continue
		instr["ligne"] = num
		# Les choix consécutifs (et leur délai) se regroupent en un seul menu.
		if instr.type == "delai":
			if courant.is_empty() or courant[-1].type != "menu":
				erreurs.append("ligne %d : délai « *! » hors d'un menu de choix" % num)
			else:
				courant[-1].delai = instr.secondes
				courant[-1].cible_delai = instr.cible
			continue
		if instr.has("erreur"):
			erreurs.append("ligne %d : %s" % [num, instr.erreur])
			continue
		if instr.type == "choix":
			if not courant.is_empty() and courant[-1].type == "menu":
				courant[-1].options.append(instr)
			else:
				courant.append({"type": "menu", "ligne": num, "options": [instr]})
		else:
			courant.append(instr)
	_verifier_cibles(noeuds, erreurs)
	return {"noeuds": noeuds, "ordre": ordre, "erreurs": erreurs}


static func _instruction(l: String) -> Dictionary:
	var m: RegExMatch
	if l.begins_with(">"):
		return {"type": "replique", "personnage": "", "humeur": "", "texte": l.substr(1).strip_edges()}
	if l.begins_with("*!"):
		m = _re_delai.search(l)
		if m:
			return {"type": "delai", "secondes": m.get_string(1).to_float(), "cible": m.get_string(2)}
		return {}
	if l.begins_with("*"):
		m = _re_choix.search(l)
		if m:
			return _avec_condition({"type": "choix", "texte": m.get_string(1), "cible": m.get_string(2)}, m.get_string(3))
		return {}
	if l.begins_with("->"):
		m = _re_saut.search(l)
		if m:
			return _avec_condition({"type": "saut", "cible": m.get_string(1)}, m.get_string(2))
		return {}
	if l.begins_with("~"):
		m = _re_affect.search(l)
		if m:
			var v = _valeur(m.get_string(3).strip_edges())
			var op := m.get_string(2)
			if op != "=" and typeof(v) != TYPE_INT:
				return {"type": "affectation", "erreur": "« %s » demande un entier" % op}
			return {"type": "affectation", "nom": m.get_string(1), "op": op, "valeur": v}
		return {}
	if l.begins_with("@"):
		m = _re_commande.search(l)
		if m:
			var args := m.get_string(2).strip_edges()
			# « @reprendre <fichier>:<nœud> » : saut vers un nœud repris par @inclure.
			if m.get_string(1) == "reprendre" and args.contains(":"):
				return _avec_condition({"type": "saut", "cible": args.get_slice(":", 1).strip_edges()}, "")
			return {"type": "commande", "nom": m.get_string(1),
				"args": Array(args.split(" ", false)) if not args.is_empty() else []}
		return {}
	m = _re_replique.search(l)
	if m:
		return {"type": "replique", "personnage": m.get_string(1).strip_edges(),
			"humeur": m.get_string(2).strip_edges(), "texte": m.get_string(3).strip_edges()}
	return {}


## Ajoute la condition [si …] à une instruction. Sans condition : "condition" vide.
static func _avec_condition(instr: Dictionary, texte: String) -> Dictionary:
	instr["condition"] = ""
	instr["negation"] = false
	instr["op"] = ""
	instr["seuil"] = 0
	texte = texte.strip_edges()
	if texte.is_empty():
		return instr
	var m := _re_condition.search(texte)
	if m == null:
		instr["erreur"] = "condition illisible : [si %s]" % texte
		return instr
	instr.condition = m.get_string(2)
	instr.negation = not m.get_string(1).is_empty()
	instr.op = m.get_string(3)
	# « == true » / « == false » (vrai, faux) : comparés comme 1 et 0.
	var seuil := m.get_string(4)
	instr.seuil = 1 if seuil in ["true", "vrai"] else (0 if seuil in ["false", "faux"] else seuil.to_int())
	return instr


## Évalue une condition préparée par _avec_condition sur les drapeaux de la partie.
static func evaluer(instr: Dictionary, drapeaux: Dictionary) -> bool:
	if instr.get("condition", "").is_empty():
		return true
	var v = drapeaux.get(instr.condition, false)
	var r: bool
	if instr.op.is_empty():
		r = bool(v)
	else:
		var n := int(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL] else 0
		match instr.op:
			">=": r = n >= instr.seuil
			"<=": r = n <= instr.seuil
			">": r = n > instr.seuil
			"<": r = n < instr.seuil
			"==": r = n == instr.seuil
			_: r = n != instr.seuil
	return r != instr.negation


static func _valeur(s: String) -> Variant:
	if s == "true":
		return true
	if s == "false":
		return false
	if s.is_valid_int():
		return s.to_int()
	if s.length() >= 2 and s.begins_with("\"") and s.ends_with("\""):
		return s.substr(1, s.length() - 2)
	return s


static func _verifier_cibles(noeuds: Dictionary, erreurs: Array[String]) -> void:
	for nom in noeuds:
		for instr in noeuds[nom]:
			var cibles: Array = []
			if instr.type == "saut":
				cibles = [instr]
			elif instr.type == "menu":
				cibles = instr.options.duplicate()
				if instr.has("cible_delai"):
					cibles.append({"cible": instr.cible_delai, "ligne": instr.ligne})
					# L'option par défaut d'un menu minuté (celle que suit le silence) n'est jamais
					# masquée : le silence doit toujours mener à un choix que le joueur voit.
					var vers_defaut: Array = instr.options.filter(func(o): return o.cible == instr.cible_delai)
					if not vers_defaut.is_empty() and vers_defaut.all(func(o): return not String(o.get("condition", "")).is_empty()):
						erreurs.append("ligne %d : l'option par défaut « %s » du menu minuté ne peut pas être conditionnelle" % [vers_defaut[0].ligne, vers_defaut[0].texte])
			for c in cibles:
				if c.cible != FIN and not noeuds.has(c.cible):
					erreurs.append("ligne %d : cible « %s » inconnue" % [c.ligne, c.cible])
