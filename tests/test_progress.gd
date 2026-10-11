extends TestSuite
## Профиль и прогрессия: чистый первый запуск, сохранение настроек, переход во вторую главу,
## сворачивание приложения во время дела.


func test_clean_profile_first_launch() -> void:
	SaveManager.profile = SaveManager.default_profile()
	check(ProgressionManager.level_unlocked("level_01"), "открыто первое дело")
	check(not ProgressionManager.level_unlocked("level_02"), "второе дело закрыто")
	check(not ProgressionManager.level_unlocked("level_11"), "вторая глава закрыта")
	check(not SaveManager.has_case_progress(), "нет незавершённого дела")
	var menu: Control = load("res://ui/screens/main_menu.tscn").instantiate()
	add_child(menu)
	await wait_frames(3)
	var texts: Array = menu.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	check(not "Продолжить дело" in texts, "в меню нет «Продолжить» на чистом профиле")
	menu.ui.open("route_map_screen")
	await wait_frames(3)
	check(menu.ui.top() != null and menu.ui.top().name == "route_map_screen", "карта кампании открывается")
	menu.queue_free()
	await wait_frames(2)


func test_settings_persist() -> void:
	SaveManager.enabled = true
	SaveManager.save_path = "user://test_settings.json"
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.set_setting("music", 0.25)
	SaveManager.set_setting("vibration", false)
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.load_game()
	check(absf(float(SaveManager.setting("music")) - 0.25) < 0.001, "громкость музыки сохранилась")
	check(SaveManager.setting("vibration") == false, "вибрация сохранилась")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings.json"))
	SaveManager.enabled = false
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.profile = SaveManager.default_profile()


func test_chapter_two_unlocks_after_finale() -> void:
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.profile["campaign"]["unlocked"] = 10
	var out: Dictionary = ProgressionManager.record_level("level_10", true, 2, 14.0)
	check_eq(str(out["unlocked_next"]), "level_11", "после финала открывается первое дело второй главы")
	check(ProgressionManager.level_unlocked("level_11"), "глава 2 открыта")
	var again: Dictionary = ProgressionManager.record_level("level_10", true, 2, 13.0)
	check_eq(int(again["new_stars"]), 0, "повтор без новых звёзд не даёт награды снова")


func test_app_background_saves_and_pauses() -> void:
	SaveManager.enabled = true
	SaveManager.save_path = "user://test_bg.json"
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.prepare_level("level_01")
	SaveManager.pending_seed = 3
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await wait_frames(2)
	game.ui.close_all()
	game.investigation.give("d_receipt")
	game.investigation.advance(1.0)
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await wait_frames(2)
	check(SaveManager.has_case_progress(), "дело сохранено при сворачивании")
	check("d_receipt" in SaveManager.profile["case_progress"]["evidence"]["found"], "улика в сохранении")
	check(game.ui.has_modal() and game.ui.top().name == "pause_menu", "открыта пауза")
	var t: float = game.investigation.clock
	await wait_seconds(0.5)
	check_eq(game.investigation.clock, t, "время не идёт, пока игра свёрнута")
	game.queue_free()
	game = null
	await wait_frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_bg.json"))
	SaveManager.enabled = false
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.profile = SaveManager.default_profile()
