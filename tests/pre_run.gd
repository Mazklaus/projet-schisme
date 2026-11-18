extends GutHookScript
## Pré-hook GUT : les tests n'écrivent jamais dans les vraies sauvegardes et ne changent pas de scène.


func run() -> void:
	var racine := (Engine.get_main_loop() as SceneTree).root
	racine.get_node(^"Sauvegarde").isoler_pour_tests()
	racine.get_node(^"Jeu").changer_de_scene = false
