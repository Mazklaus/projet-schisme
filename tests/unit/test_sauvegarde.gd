extends GutTest


func before_each() -> void:
	for i in Sauvegarde.NB_EMPLACEMENTS:
		Sauvegarde.effacer(i)


func test_ecrire_puis_lire() -> void:
	var e := Sauvegarde.etat_vierge()
	e.episode = "ep00_prologue"
	e.drapeaux = {"vivant_ilse": true, "relation_capitaine": 2}
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


func test_migration_v1_vers_v2_renomme_les_cles_de_la_tranche() -> void:
	var v1 := {"version": 1, "episode": "ep01_ullanor", "drapeaux": {"choix_ullanor": 1,
		"soldate_vivante": true, "soldate_connait_sauveur": true, "relation_dremm": -1}}
	var d := Sauvegarde.migrer(v1)
	assert_eq(int(d.version), Sauvegarde.VERSION)
	assert_eq(d.drapeaux, {"choix_ep01_ullanor": 1, "vivant_ilse": true, "connait_ilse_sauveur": true,
		"relation_dremm": -1})
