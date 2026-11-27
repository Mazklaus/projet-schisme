extends GutTest

const TEXTE := """
// commentaire
=== debut
LOKEN: Bonjour.
TARIK (inquiet): Isstvan…
> Narration.
~ loyal = true
~ score += 2
@cine ouverture lente
* Obéir -> obeir
* Refuser -> refus [si non loyal]
* Parler -> obeir [si score >= 2]
*! 8 -> obeir
-> FIN
=== obeir
-> FIN
=== refus
-> FIN
"""


func test_analyse_complete() -> void:
	var d := FormatDialogue.analyser(TEXTE)
	assert_eq(d.erreurs, [] as Array[String])
	assert_eq(d.ordre, ["debut", "obeir", "refus"] as Array[String])
	var i: Array = d.noeuds.debut
	assert_eq(i[0].personnage, "LOKEN")
	assert_eq(i[1].humeur, "inquiet")
	assert_eq(i[2].personnage, "")
	assert_eq(i[3].valeur, true)
	assert_eq(i[4].op, "+=")
	assert_eq(i[5].args, ["ouverture", "lente"])
	assert_eq(i[6].type, "menu")
	assert_eq(i[6].options.size(), 3)
	assert_eq(i[6].delai, 8.0)
	assert_eq(i[6].cible_delai, "obeir")
	assert_true(i[6].options[1].negation)
	assert_eq(i[6].options[2].op, ">=")
	assert_eq(i[6].options[2].seuil, 2)


func test_erreurs_signalees_avec_ligne() -> void:
	var d := FormatDialogue.analyser("LOKEN: avant\n=== a\n-> inconnu\nblabla minuscule\n*! 3 -> a\n=== a\n~ x += vrai")
	var t := "\n".join(d.erreurs)
	assert_string_contains(t, "ligne 1 : texte avant")
	assert_string_contains(t, "cible « inconnu »")
	assert_string_contains(t, "ligne 4 : syntaxe inconnue")
	assert_string_contains(t, "ligne 5 : délai")
	assert_string_contains(t, "en double")
	assert_string_contains(t, "demande un entier")


func test_tous_les_dialogues_du_jeu_sont_valides() -> void:
	var n := 0
	for id in Catalogue.ordre:
		for c in Catalogue.episode(id).chapitres:
			if c.has("dialogue"):
				var d := FormatDialogue.charger(c.dialogue)
				assert_eq(d.erreurs, [] as Array[String], c.dialogue)
				n += 1
	assert_gt(n, 0)


func test_option_par_defaut_du_menu_minute_jamais_masquee() -> void:
	var d := FormatDialogue.analyser("=== a\n* Partir -> b\n* Obéir -> c [si x]\n*! 8 -> c\n=== b\nA: b\n=== c\nA: c")
	assert_eq(d.erreurs.size(), 1)
	assert_string_contains(d.erreurs[0], "option par défaut")
	var ok := FormatDialogue.analyser("=== a\n* Partir -> b [si x]\n* Obéir -> c\n*! 8 -> c\n=== b\nA: b\n=== c\nA: c")
	assert_eq(ok.erreurs, [] as Array[String])
