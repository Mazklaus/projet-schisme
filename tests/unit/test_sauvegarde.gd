extends GutTest


func before_each() -> void:
	for i in Sauvegarde.NB_EMPLACEMENTS:
		Sauvegarde.effacer(i)


func test_ecrire_puis_lire() -> void:
	var e := Sauvegarde.etat_vierge()
	e.episode = "ep00_prologue"
	e.drapeaux = {"soldate_vivante": true, "relation_capitaine": 2}
	assert_eq(Sauvegarde.ecrire(1, e), OK)
	var l := Sauvegarde.lire(1)
	assert_eq(l.episode, "ep00_prologue")
	assert_eq(int(l.drapeaux.relation_capitaine), 2)
	assert_eq(int(l.version), Sauvegarde.VERSION)
	assert_false(FileAccess.file_exists(Sauvegarde.chemin(1) + ".tmp"))


func test_emplacement_vide() -> void:
	assert_eq(Sauvegarde.lire(2), {})


func test_sauvegarde_plus_recente_refusee() -> void:
	assert_eq(Sauvegarde.migrer({"version": Sauvegarde.VERSION + 1}), {})
	assert_eq(Sauvegarde.migrer({"episode": "x"}), {})


func test_cles_manquantes_completees() -> void:
	var m := Sauvegarde.migrer({"version": Sauvegarde.VERSION, "episode": "x"})
	assert_eq(m.episode, "x")
	assert_eq(m.drapeaux, {})
	assert_eq(m.episodes_termines, [])


func test_fichier_corrompu() -> void:
	DirAccess.make_dir_recursive_absolute(Sauvegarde.dossier)
	var f := FileAccess.open(Sauvegarde.chemin(3), FileAccess.WRITE)
	f.store_string("{pas du json")
	f.close()
	assert_eq(Sauvegarde.lire(3), {})
