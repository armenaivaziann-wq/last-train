extends TestSuite
## Билеты (жизни): трата при поражении, восстановление по времени (подменяемые часы), защита
## от перевода часов назад, бесконечные билеты в полной версии, бесплатные дела, миграция.

const T0: int = 1_800_000_000


func before_each() -> void:
	SaveManager.profile = SaveManager.default_profile()
	Tickets.clock_override = T0
	SaveManager.profile["tickets"] = {"count": 5, "ts": T0, "full": false}


func after_each() -> void:
	Tickets.clock_override = -1
	SaveManager.profile = SaveManager.default_profile()


func test_spent_only_on_loss() -> void:
	before_each()
	SaveManager.profile["campaign"]["unlocked"] = 14
	SaveManager.prepare_level("level_03")
	SaveManager.pending_seed = 2
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await wait_frames(2)
	check_eq(Tickets.count(), 5, "вход в дело билет не тратит")
	var r: Dictionary = game.investigation.finish("timeout")
	check(r["ticket_spent"] and Tickets.count() == 4, "поражение по дедлайну — минус билет")
	game.queue_free()
	game = null
	await wait_frames(2)
	SaveManager.prepare_level("level_03")
	SaveManager.pending_seed = 3
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await wait_frames(2)
	game.investigation.finish("solved", {"score": 3})
	check_eq(Tickets.count(), 4, "победа билет не тратит")
	game.queue_free()
	game = null
	await wait_frames(2)
	check(not Tickets.spend_for_loss("level_01") and not Tickets.spend_for_loss("daily"), "обучение и дело дня — без билетов")
	check_eq(Tickets.count(), 4, "счётчик не изменился")
	after_each()


func test_regen_by_time() -> void:
	before_each()
	Tickets.spend_for_loss("level_05")
	Tickets.spend_for_loss("level_05")
	check_eq(Tickets.count(), 3, "два поражения — 3 билета")
	Tickets.clock_override = T0 + 29 * 60
	check_eq(Tickets.count(), 3, "через 29 минут ещё нет")
	check(Tickets.seconds_to_next() == 60, "до следующего — минута (%d)" % Tickets.seconds_to_next())
	Tickets.clock_override = T0 + 31 * 60
	check_eq(Tickets.count(), 4, "через 30 минут +1")
	Tickets.clock_override = T0 + 5 * 3600
	check_eq(Tickets.count(), 5, "через 5 часов — не больше 5")
	after_each()


func test_clock_rollback_protection() -> void:
	before_each()
	Tickets.spend_for_loss("level_05")
	Tickets.clock_override = T0 - 10 * 3600
	check_eq(Tickets.count(), 4, "часы назад — билеты не начисляются")
	Tickets.clock_override = T0 - 10 * 3600 + 20 * 60
	check_eq(Tickets.count(), 4, "отсчёт идёт заново от нового времени")
	Tickets.clock_override = T0 - 10 * 3600 + 31 * 60
	check_eq(Tickets.count(), 5, "через 30 минут после отката — +1")
	after_each()


func test_full_version_and_gating() -> void:
	before_each()
	for i in 5:
		Tickets.spend_for_loss("level_05")
	check_eq(Tickets.count(), 0, "билеты кончились")
	check(not Tickets.can_start("level_05"), "дело кампании не начать")
	check(Tickets.can_start("level_01") and Tickets.can_start("daily"), "обучение и дело дня доступны")
	EconomyManager.add("crystals", 100, false)
	check(Tickets.refill_for_crystals() and Tickets.count() == 5, "восполнение за кристаллы")
	for i in 5:
		Tickets.spend_for_loss("level_05")
	AdsService.show_rewarded(func(ok: bool) -> void: if ok: Tickets.add(1))
	check_eq(Tickets.count(), 1, "реклама (заглушка) даёт билет")
	Tickets.unlock_full_version()
	check(Tickets.can_start("level_05") and not Tickets.spend_for_loss("level_05"), "полная версия — бесконечные билеты")
	after_each()


func test_menu_shows_tickets_and_out_dialog() -> void:
	before_each()
	SaveManager.profile["campaign"]["unlocked"] = 14
	for i in 5:
		Tickets.spend_for_loss("level_05")
	var menu: Control = load("res://ui/screens/main_menu.tscn").instantiate()
	add_child(menu)
	await wait_frames(3)
	check(menu._tickets.text.begins_with("0/5"), "в меню счётчик билетов (%s)" % menu._tickets.text)
	menu.ui.open("route_map_screen")
	await wait_frames(2)
	menu.ui.top()._start("level_05")
	await wait_frames(2)
	check(menu.ui.top().name == "tickets_screen", "без билетов — окно «Билеты закончились»")
	check(menu.ui.top()._timer.text.contains("00:"), "таймер до следующего билета")
	menu.queue_free()
	await wait_frames(2)
	after_each()


func test_old_profile_gets_full_tickets() -> void:
	SaveManager.enabled = true
	SaveManager.save_path = "user://test_tk.json"
	var f := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "economy": {"coins": 5}}))
	f.close()
	SaveManager.load_game()
	Tickets.clock_override = T0
	check_eq(Tickets.count(), 5, "старый профиль — полные 5 билетов")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.save_path))
	SaveManager.enabled = false
	SaveManager.save_path = SaveManager.SAVE_PATH
	after_each()
