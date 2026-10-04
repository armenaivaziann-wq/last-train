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


func test_continue_generated_case_title() -> void:
	SaveManager.profile["case_progress"] = {"case_id": "gen:level_04", "level": "level_04", "clock": 124.0, "seed": 5}
	check_eq(load("res://ui/screens/main_menu.gd").case_title(SaveManager.profile["case_progress"]), "Дело 4: Мимик багажа", "название сгенерированного дела берётся из кампании")
	SaveManager.profile["case_progress"] = {"case_id": "gen:shadow", "level": "daily", "clock": 124.0, "seed": 5}
	check_eq(load("res://ui/screens/main_menu.gd").case_title(SaveManager.profile["case_progress"]), "Дело дня", "дело дня")
	var menu: Control = load("res://ui/screens/main_menu.tscn").instantiate()
	add_child(menu)
	await wait_frames(3)
	var found: bool = false
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text == "Продолжить дело":
			found = (b as Button).tooltip_text.begins_with("«Дело дня»")
	check(found, "кнопка «Продолжить дело» с правильным названием")
	menu.queue_free()
	SaveManager.profile["case_progress"] = {}
