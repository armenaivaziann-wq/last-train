extends TestSuite
## Главное меню и экраны прогрессии открываются без ошибок.

func test_menu_and_meta_screens_open() -> void:
	var menu: Control = load("res://ui/screens/main_menu.tscn").instantiate()
	add_child(menu)
	await wait_frames(3)
	for s in ["route_map_screen", "train_screen", "collection_screen", "quests_screen", "settings_screen", "help_screen"]:
		var scr: GameScreen = menu.ui.open(s)
		await wait_frames(2)
		check(is_instance_valid(scr) and scr.is_inside_tree(), "открыт " + s)
		menu.ui.close_all()
		await wait_frames(1)
	menu.queue_free()
