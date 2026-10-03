extends TestSuite
## Игровой цикл на реальной game.tscn: запуск, движение, двери, NPC по расписанию,
## допрос, документы, выводы, камеры, обвинения, итог, сохранение.


func _inv() -> InvestigationManager:
	return game.investigation


func test_case_starts() -> void:
	await start_case()
	check(game.player != null, "детектив создан")
	check_eq(game.npcs.size(), 11, "8 подозреваемых и 3 второстепенных пассажира")
	check(game.train.carriages.size() == 3, "три вагона (пассажирский, тамбур, ресторан)")
	check(not game.ui.has_modal(), "брифинг закрыт")
	var t0: float = _inv().clock
	await wait_seconds(0.6)
	check(_inv().clock > t0, "часы дела идут")


func test_brief_gives_clue_and_holds_clock() -> void:
	await start_case("case_01", false)
	check(game.ui.has_modal(), "брифинг открыт")
	var t0: float = _inv().clock
	await wait_seconds(0.4)
	check_eq(_inv().clock, t0, "во время брифинга часы стоят")
	var brief: Node = game.ui.top()
	for i in 12:
		if not is_instance_valid(brief) or brief.is_queued_for_deletion():
			break
		brief._on_next()
		await get_tree().process_frame
	check(not game.ui.has_modal(), "брифинг закрыт кнопкой")
	check(_inv().evidence.has("s_agata_brief"), "брифинг даёт первое показание")


func test_player_moves_and_collides() -> void:
	await start_case()
	var p: PlayerController = game.player
	p.global_position = Vector2(300, 170)
	await wait_frames(1)
	var x0: float = p.global_position.x
	Input.action_press(&"move_right")
	await wait_seconds(0.8)
	Input.action_release(&"move_right")
	check(p.global_position.x > x0 + 30.0, "движение вправо (%.1f → %.1f)" % [x0, p.global_position.x])
	Input.action_press(&"move_up")
	await wait_seconds(2.0)
	Input.action_release(&"move_up")
	check(p.global_position.y >= 56.0, "стена не пускает выше пола (y=%.1f)" % p.global_position.y)


func test_walk_through_vestibule_to_restaurant() -> void:
	await start_case()
	var p: PlayerController = game.player
	p.global_position = Vector2(620, 166)
	Input.action_press(&"move_right")
	await wait_seconds(2.2)
	Input.action_release(&"move_right")
	check_eq(game.layout.carriage_at(p.global_position.x), "restaurant", "дошёл до ресторана через тамбур (x=%.1f)" % p.global_position.x)


func test_locked_door_blocks() -> void:
	await start_case()
	var p: PlayerController = game.player
	p.global_position = Vector2(30, 166)
	Input.action_press(&"move_left")
	await wait_seconds(1.0)
	Input.action_release(&"move_left")
	check(p.global_position.x > 4.0, "запертая дверь в локомотив не пускает (x=%.1f)" % p.global_position.x)


func test_npcs_follow_schedule() -> void:
	await start_case()
	_inv().advance(Db.parse_time("02:05") - _inv().clock)
	await wait_frames(2)
	var klara: Vector2 = game.npcs["klara"].global_position
	var spot: Vector2 = game.layout.spots["rb4_l1"]["pos"]
	check(klara.distance_to(spot) < 2.0, "в 02:05 Клэр в ресторане за 4-м столиком")
	check_eq(game.npcs["klara"].state, "sitting", "Клэр сидит")
	var nina: NPCController = game.npcs["nina"]
	check(nina.global_position.distance_to(game.layout.spots["piano"]["pos"]) < 2.0, "Нина у пианино")


func test_interact_with_npc_opens_panel() -> void:
	await start_case()
	var agata: NPCController = game.npcs["agata"]
	game.player.global_position = agata.global_position + Vector2(-16, 0)
	game.player.facing = "right"
	await wait_frames(3)
	check(game.player.target != null and game.player.target.owner_id == "agata", "цель — Агата")
	game.interact()
	await wait_frames(2)
	check(game.ui.top() != null and game.ui.top().name == "passenger_screen", "открыта карточка пассажира")
	var t0: float = _inv().clock
	await wait_seconds(0.3)
	check_eq(_inv().clock, t0, "пока открыт интерфейс, время стоит")


func test_dialogue_gives_testimony() -> void:
	await start_case()
	game.open_dialogue("robert")
	await wait_frames(2)
	var scr: Node = game.ui.top()
	scr._ask("alibi")
	for i in 4:
		scr._advance()
		scr._advance()
	check(_inv().evidence.has("s_robert_alibi"), "алиби Хейла записано")
	check(_inv().suspects.flag("robert", "met"), "знакомство отмечено")
	var topics: Array = _inv().dialogue.topics("robert", _inv().evidence)
	var ids: Array = topics.map(func(t: Dictionary) -> String: return t["id"])
	check(not "coffee" in ids, "тема про кофе закрыта, пока нет улик")
	_inv().give("d_receipt")
	ids = _inv().dialogue.topics("robert", _inv().evidence).map(func(t: Dictionary) -> String: return t["id"])
	check("coffee" in ids, "чек открывает тему про кофе")


func test_documents_and_magnifier() -> void:
	await start_case()
	game.open_documents("robert")
	await wait_frames(2)
	check(_inv().evidence.has("d_robert_ticket"), "билет Хейла — улика")
	check(_inv().suspects.flag("robert", "docs"), "документы отмечены проверенными")
	var scr: Node = game.ui.top()
	var hs: Dictionary = game.case_data["documents"]["robert"]["hotspots"][0]
	scr._inspect(hs)
	check(not _inv().evidence.has("d_robert_stub"), "без лупы мелкая деталь не видна")
	scr._toggle_lens()
	scr._inspect(hs)
	check(_inv().evidence.has("d_robert_stub"), "лупа раскрывает подпись на корешке")


func test_object_and_luggage() -> void:
	await start_case()
	game.open_object("obj_trash")
	await wait_frames(2)
	check(_inv().evidence.has("p_torn_page"), "обрывок страницы в корзине")
	game.ui.close_all()
	game.open_luggage("klara")
	await wait_frames(2)
	var scr: Node = game.ui.top()
	scr._select(0)
	scr._toggle_lens()
	scr._inspect(scr._items[0]["hotspot"])
	check(_inv().evidence.has("i_klara_photo"), "снимок Клэр через лупу")


func test_deduction_by_player() -> void:
	await start_case()
	_inv().give("p_torn_page")
	_inv().give("d_robert_stub")
	_inv().give("s_klara_alibi")
	check_eq(_inv().deduce("s_klara_alibi", "p_torn_page"), "", "несвязанные улики не дают вывода")
	check_eq(_inv().deduce("d_robert_stub", "p_torn_page"), "x_signature", "подписи не совпадают")
	check(_inv().evidence.has("x_signature"), "вывод в журнале")
	_inv().give("s_robert_alibi")
	_inv().give("c_svc_robert")
	_inv().deduce("s_robert_alibi", "c_svc_robert")
	check_eq(_inv().evidence.status("s_robert_alibi"), "refuted", "алиби Хейла опровергнуто")


func test_camera_marks_real_events() -> void:
	await start_case()
	game.open_cameras()
	await wait_frames(3)
	var scr: Node = game.ui.top()
	check(game.camera_system.playback, "режим записи")
	scr._select("cam2")
	scr._on_scrub(Db.parse_time("01:40:30"))
	await wait_frames(2)
	var robert: NPCController = game.npcs["robert"]
	check(game.layout.camera("cam2")["rect"].has_point(robert.global_position), "на записи 01:40:30 Хейл в служебном купе")
	scr._mark()
	check(_inv().evidence.has("c_svc_robert"), "отметка даёт улику записи")
	scr._on_scrub(Db.parse_time("01:30"))
	var before: int = _inv().evidence.found.size()
	scr._mark()
	check_eq(_inv().evidence.found.size(), before, "пустой момент ничего не даёт")
	scr.close()
	await wait_frames(2)
	check(not game.camera_system.playback, "после закрытия — живой режим")


func test_wrong_accusation_penalty() -> void:
	await start_case()
	EconomyManager.add("reputation", 20)
	var t0: float = _inv().clock
	var r: Dictionary = _inv().accuse("louis", [], "")
	check(not r["correct"], "Луи не виновен")
	check_eq(_inv().mistakes, 1, "ошибка засчитана")
	check_eq(EconomyManager.reputation(), 15, "−5 репутации")
	check(_inv().clock >= t0 + 1.99, "−2 минуты")
	check(not _inv().ended, "дело продолжается")
	_inv().accuse("tikhon", [], "")
	check(_inv().ended, "вторая ошибка завершает дело")


func test_correct_accusation_rewards() -> void:
	await start_case()
	for id in ["d_robert_stub", "p_torn_page", "x_signature", "c_svc_robert"]:
		_inv().give(id)
	var coins0: int = EconomyManager.coins()
	game.accuse("robert", ["x_signature", "c_svc_robert", "p_torn_page"], "doppelganger")
	await wait_seconds(9.0)
	check(_inv().ended, "дело завершено")
	check_eq(ProgressionManager.monster_caught("black_cloak"), 1, "Чёрный плащ в бестиарии")
	check(EconomyManager.coins() > coins0 + 300, "монеты начислены (%d)" % (EconomyManager.coins() - coins0))
	check(game.ui.top() != null and game.ui.top().name == "result_screen", "экран итога")


func test_timeout_fails_case() -> void:
	await start_case()
	_inv().advance(30.0)
	check(_inv().ended, "прибытие завершает дело")
	await wait_seconds(3.0)
	check(game.ui.top() != null and game.ui.top().name == "result_screen", "экран итога при провале")


func test_save_and_resume() -> void:
	SaveManager.enabled = true
	SaveManager.save_path = "user://test_save.json"
	await start_case()
	_inv().give("d_receipt")
	_inv().give("p_torn_page")
	_inv().advance(2.0)
	game.player.global_position = Vector2(900, 166)
	game.autosave()
	var clock: float = _inv().clock
	game.queue_free()
	game = null
	await wait_frames(2)
	SaveManager.load_game()
	check(SaveManager.has_case_progress(), "прогресс дела сохранён")
	SaveManager.pending_case = "case_01"
	SaveManager.pending_resume = true
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await wait_frames(2)
	check(_inv().evidence.has("d_receipt") and _inv().evidence.has("p_torn_page"), "улики восстановлены")
	check(absf(_inv().clock - clock) < 0.05, "время восстановлено")
	check(game.player.global_position.distance_to(Vector2(900, 166)) < 4.0, "позиция героя восстановлена")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	SaveManager.enabled = false
	SaveManager.save_path = SaveManager.SAVE_PATH


func test_context_button_labels() -> void:
	await start_case()
	var hud: Hud = game.hud
	game.player.global_position = Vector2(300, 170)
	await wait_frames(3)
	check_eq(hud._interact_label.text, "Лупа", "без цели кнопка — лупа")
	var agata: NPCController = game.npcs["agata"]
	game.player.global_position = agata.global_position + Vector2(-16, 0)
	game.player.facing = "right"
	await wait_frames(3)
	check_eq(hud._interact_label.text, "Поговорить", "рядом пассажир")
	game.player.global_position = Vector2(372, 106)
	game.player.facing = "up"
	await wait_frames(3)
	check_eq(hud._interact_label.text, "Проверить", "рядом багаж")
	check(game.highlight.visible, "предмет подсвечен")


func test_camera_switching_keeps_marks() -> void:
	await start_case()
	game.open_cameras()
	await wait_frames(3)
	var scr: Node = game.ui.top()
	for id in ["cam1", "cam3", "cam4", "cam2"]:
		scr._select(id)
		await wait_frames(1)
		check_eq(scr._selected, id, "выбрана " + id)
	scr._on_scrub(Db.parse_time("01:42:30"))
	scr._select("cam4")
	scr._mark()
	check(_inv().evidence.has("c_rest_trash"), "отметка на К4 после переключения")
	scr._on_scrub(Db.parse_time("01:40:30"))
	scr._select("cam2")
	scr._mark()
	check(_inv().evidence.has("c_svc_robert"), "отметка на К2")
