extends GutTest

const PLANS := [
	{"position": [0, 0], "zoom": 1.0, "duree": 0},
	{"position": [100, 0], "zoom": 2.0, "duree": 2.0, "courbe": "lineaire"},
	{"position": [100, 100], "zoom": 2.0, "duree": 1.0, "tremblement": 10},
]


func test_echantillonnage() -> void:
	assert_eq(CameraCine.duree_totale(PLANS), 3.0)
	var e := CameraCine.echantillonner(PLANS, 1.0)
	assert_eq(e.index, 1)
	assert_almost_eq(e.position.x, 50.0, 0.01)
	assert_almost_eq(e.zoom, 1.5, 0.01)
	e = CameraCine.echantillonner(PLANS, 2.0)
	assert_eq(e.index, 2)
	assert_almost_eq(e.tremblement, 10.0, 0.01, "tremblement maximal au début du plan")
	e = CameraCine.echantillonner(PLANS, 99.0)
	assert_eq(e.position, Vector2(100, 100))
	assert_eq(e.tremblement, 0.0)


func test_coupe_franche() -> void:
	var e := CameraCine.echantillonner([{"position": [5, 5], "duree": 0}], 0.0)
	assert_eq(e.position, Vector2(5, 5))


func test_passer_termine_la_sequence() -> void:
	var c := CameraCine.new()
	add_child_autofree(c)
	watch_signals(c)
	c.jouer(PLANS)
	assert_true(c.en_cours)
	c.passer()
	assert_false(c.en_cours)
	assert_signal_emitted(c, "sequence_terminee")
	assert_eq(c.position, Vector2(100, 100))
