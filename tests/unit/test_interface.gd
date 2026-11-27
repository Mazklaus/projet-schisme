extends GutTest
## Interface (UI/UX) : noms affichés, typographie française, carton de lieu, chiffres romains.

const NBSP := " "


func test_nom_sans_numero_et_vox() -> void:
	assert_eq(BoiteDialogue.nom_affiche({"personnage": "FRÈRE 1", "humeur": ""}), "Frère")
	assert_eq(BoiteDialogue.nom_affiche({"personnage": "DREMM", "humeur": "vox"}), "Dremm, au vox")
	assert_eq(BoiteDialogue.nom_affiche({"personnage": "", "humeur": ""}), "")


func test_espaces_insecables() -> void:
	assert_eq(BoiteDialogue.typographie("Tu triches ?"), "Tu triches" + NBSP + "?")
	assert_eq(BoiteDialogue.typographie("Regarde. Là!"), "Regarde. Là" + NBSP + "!")
	assert_eq(BoiteDialogue.typographie("« Cela suffit. »"), "«" + NBSP + "Cela suffit." + NBSP + "»")
	assert_eq(BoiteDialogue.typographie("Vraiment ?!"), "Vraiment" + NBSP + "?!")


func test_lieu_decoupe() -> void:
	assert_eq(Chapitre.decouper_lieu("Ullanor. 000.M31."), PackedStringArray(["ULLANOR", "000.M31"]))
	assert_eq(Chapitre.decouper_lieu("017.M31."), PackedStringArray(["017.M31", ""]))


func test_chiffres_romains() -> void:
	assert_eq(StyleSchisme.romain(2), "II")
	assert_eq(StyleSchisme.romain(14), "XIV")


func test_choix_garde_la_derniere_replique() -> void:
	var d := FormatDialogue.analyser("=== a\nDREMM: Et maintenant ?\n* x -> b\n* y -> b\n=== b\nA: b")
	var boite := BoiteDialogue.new()
	add_child_autofree(boite)
	boite.lancer(LecteurDialogue.new(d), "a")
	boite._texte.visible_ratio = 1.0
	boite._suivant()
	assert_eq(boite._choix.get_child_count(), 2)
	assert_string_contains(boite._texte.text, "Et maintenant")
	assert_eq(boite._nom.text, "Dremm")
