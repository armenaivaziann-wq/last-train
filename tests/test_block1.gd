extends TestSuite
## Блок 1: расследование сложнее. Тайны невиновных раскрываются, подставы опровергаются,
## доска передвижений находит ложное алиби, второе преступление случается, если тянуть,
## камеры: маскировки, невидимость вампира, повреждённые записи, вагоны без камер.

const SolverSuite := preload("res://tests/test_levels.gd")


func _start(level_id: String, seed_value: int = 7) -> void:
	SaveManager.prepare_level(level_id)
	SaveManager.pending_seed = seed_value
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await wait_frames(2)
	game.ui.close_all()
	await wait_frames(1)


func _end() -> void:
	game.queue_free()
	game = null
	await wait_frames(2)


func _solve() -> void:
	var s: Node = SolverSuite.new()
	s.game = game
	s._solve_all()
	s.free()


func test_innocent_secrets_are_revealed() -> void:
	for n in range(2, 15):
		var lid: String = "level_%02d" % n
		await _start(lid)
		_solve()
		var d: Dictionary = game.investigation.data
		var secrets: Array = d["clues"].keys().filter(func(id: String) -> bool: return id.ends_with("_secret"))
		check(secrets.size() >= 2, "%s: минимум 2 невиновных с тайной (%d)" % [lid, secrets.size()])
		for id: String in secrets:
			check(game.investigation.evidence.has(id), "%s: тайна раскрывается — %s" % [lid, d["clues"][id]["title"]])
			check(str(d["clues"][id]["title"]).begins_with("Не убийца, но скрывал"), "%s: вывод «Не убийца, но скрывал…» (%s)" % [lid, id])
		await _end()


func test_frames_are_refuted() -> void:
	for pair in [["level_02", "x_l2_double"], ["level_05", "x_l5_framed"], ["level_08", "x_l8_not_agata"], ["level_12", "x_l12_invisible"]]:
		await _start(pair[0])
		_solve()
		check(game.investigation.evidence.has(pair[1]), "%s: подстава опровергается выводом %s" % pair)
		await _end()


func test_movement_board_breaks_alibi() -> void:
	await _start("level_02")
	var inv: InvestigationManager = game.investigation
	inv.give("s_l2_louis_alibi")
	var car: String = inv.layout.carriage_ids[1]   # служебный тамбур буфета
	inv.board_set("louis", 3, inv.layout.carriage_ids[2])   # 01:45 — ресторан (неверно)
	var r0: Dictionary = inv.check_board()
	check(r0["conflicts"].is_empty() and not inv.evidence.has("x_l2_alibi"), "неверная расстановка ничего не доказывает")
	inv.board_set("louis", 3, car)                # 01:45–01:50 — тамбур (так и было)
	var r: Dictionary = inv.check_board()
	check(r["conflicts"].has("louis"), "доска находит противоречие в алиби Луи")
	check(inv.evidence.has("x_l2_alibi") and inv.evidence.status("s_l2_louis_alibi") == "refuted", "алиби опровергнуто, вывод получен")
	await _end()


func test_late_crime_when_player_stalls() -> void:
	await _start("level_12")
	var inv: InvestigationManager = game.investigation
	inv.advance(12.2)
	await wait_frames(2)
	check(inv.state_of("professor") == "dead", "дело 12: пока тянули — вампир добрался до профессора")
	check(game.world_items.has("obj_l12_prof_body"), "на месте — новая улика")
	check(not game.npcs["professor"].visible, "жертва выбыла")
	_solve()
	var missing: Array = inv.data["key_clues"].filter(func(id: String) -> bool: return not inv.evidence.has(id))
	check(missing.is_empty(), "дело всё ещё решаемо: %s" % [missing])
	await _end()
	await _start("level_12")
	_solve()
	check(game.investigation.state_of("professor") != "dead", "быстрый детектив успевает — второго преступления нет")
	await _end()


func test_camera_tricks() -> void:
	SaveManager.profile["settings"]["difficulty"] = "normal"
	await _start("level_02")
	game.open_cameras()
	await wait_frames(3)
	var scr: Node = game.ui.top()
	scr._select("cam3")
	scr._on_scrub(Db.parse_time("01:47:20"))
	await wait_frames(1)
	check(scr._status.text.contains("Агата"), "дело 2: на записи у тележки — «Агата» (%s)" % scr._status.text)
	check(not scr._status.text.contains("Луи"), "перевёртыш не назван своим именем")
	scr.close()
	await _end()
	await _start("level_12")
	game.open_cameras()
	await wait_frames(3)
	scr = game.ui.top()
	scr._select("cam5")
	scr._on_scrub(Db.parse_time("01:45:20"))
	await wait_frames(1)
	check(game.npcs["robert"].sprite.modulate.a < 0.05, "дело 12: вампира на записи не видно")
	check(not scr._status.text.contains("Хейл"), "вампира нет в списке «В кадре»")
	scr.close()
	await wait_frames(2)
	check(game.npcs["robert"].sprite.modulate.a > 0.9, "вживую вампир виден")
	await _end()


func test_damaged_record_and_unfilmed_carriages() -> void:
	await _start("level_14")
	var inv: InvestigationManager = game.investigation
	check(not inv.camera_gap("cam4", Db.parse_time("01:46:30")).is_empty(), "дело 14: запись К4 повреждена в 01:46")
	var got: Array[String] = inv.mark_camera("cam4", Db.parse_time("01:46:30"))
	check(got.has("c_l14_damaged"), "отметка повреждённого отрезка даёт улику «Запись»")
	await _end()
	await _start("level_13")
	var ids: Array = game.camera_system.cameras().map(func(c: Dictionary) -> String: return str(c["id"]))
	check(not ids.has("cam1") and not ids.has("cam2"), "дело 13: пассажирский вагон без камер — ни миниатюры, ни записи")
	check(ids.has("cam6"), "багажный вагон снимается")
	await _end()


func test_hidden_details_need_magnifier() -> void:
	await _start("level_04")
	game.open_object("obj_l4_drag")
	await wait_frames(2)
	var scr: Node = game.ui.top()
	var texts: Array = scr.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	check(not texts.any(func(t: String) -> bool: return t.contains("Блёстка")), "без лупы блёстку не видно вовсе")
	scr._toggle_lens()
	await wait_frames(1)
	texts = scr.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	check(texts.any(func(t: String) -> bool: return t.contains("Блёстка")), "под лупой деталь появилась")
	await _end()


func test_action_costs_and_modes() -> void:
	SaveManager.profile["settings"]["difficulty"] = "normal"
	await _start("level_05")
	var inv: InvestigationManager = game.investigation
	var t0: float = inv.clock
	game.open_dialogue("agata")
	await wait_frames(2)
	var scr: Node = game.ui.top()
	var btn: Button = scr.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text.contains("· 0.5 мин"))[0]
	check(btn != null, "цена вопроса на кнопке")
	scr._ask(inv.dialogue.topics("agata", inv.evidence, inv.dialogue_ctx("agata"))[0]["id"])
	check(absf(inv.clock - t0 - 0.5) < 0.01, "новый вопрос стоит 0.5 мин")
	await _end()
	SaveManager.profile["settings"]["difficulty"] = "detective"
	await _start("level_05")
	check(int(game.investigation.profile["hints"]) == 0 and str(game.investigation.profile["markers"]) == "none", "детектив: без подсказок и подсветки")
	check(absf(game.investigation.wrong_penalty() - 2.0 * InvestigationManager.WRONG_TIME_PENALTY) < 0.01, "детектив: ошибка стоит вдвое больше")
	await _end()
	SaveManager.profile["settings"]["difficulty"] = "easy"
	await _start("level_05")
	check(not game.investigation.profile["blind_zones"] and game.investigation.profile["hints_free"], "лёгкий: без слепых зон, подсказки бесплатно")
	await _end()
	SaveManager.profile["settings"]["difficulty"] = "normal"


func test_old_save_gets_easy_new_gets_normal() -> void:
	SaveManager.enabled = true
	SaveManager.save_path = "user://test_mig.json"
	var f := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "settings": {"music": 0.5}, "economy": {"coins": 999}}))
	f.close()
	SaveManager.load_game()
	check_eq(str(SaveManager.setting("difficulty")), "easy", "старое сохранение — лёгкий, прогресс не ломается")
	check_eq(int(SaveManager.profile["economy"]["coins"]), 999, "монеты из старого сохранения на месте")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.save_path))
	SaveManager.load_game()
	check_eq(str(SaveManager.setting("difficulty")), "normal", "новый игрок — нормальный")
	SaveManager.enabled = false
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.profile = SaveManager.default_profile()
