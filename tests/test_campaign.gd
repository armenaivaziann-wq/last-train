extends TestSuite
## Кампания: дедлайн 20 минут, звёзды, разовые награды, открытие следующего дела,
## сохранение времени, сцена раскрытия маньяка.


func _start_level(level_id: String, seed_value: int = 7) -> Node:
	SaveManager.prepare_level(level_id)
	SaveManager.pending_seed = seed_value
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await wait_frames(2)
	game.ui.close_all()
	await wait_frames(1)
	return game


func _inv() -> InvestigationManager:
	return game.investigation


func test_deadline_is_20_minutes() -> void:
	await _start_level("level_01")
	check(absf(_inv().arrival_time - _inv().start_time - 20.0) < 0.001, "дедлайн 20 игровых минут")
	_inv().hold("test")
	var t0: float = _inv().clock
	await wait_seconds(0.5)
	check_eq(_inv().clock, t0, "пауза останавливает отсчёт")
	_inv().release("test")


func test_timeout_once_and_no_negative_time() -> void:
	await _start_level("level_01")
	var finished: Array = []
	_inv().finished.connect(func(r: Dictionary) -> void: finished.append(r))
	_inv().advance(25.0)
	_inv().advance(5.0)
	check_eq(finished.size(), 1, "поражение срабатывает один раз")
	check(_inv().minutes_left() >= 0.0, "время не уходит в минус")
	check_eq(int(finished[0]["stars"]), 0, "поражение — 0 звёзд")
	check(not ProgressionManager.level_completed("level_01"), "уровень не пройден")
	check(ProgressionManager.level_unlocked("level_01"), "уровень доступен для повтора")
	await wait_seconds(4.0)
	check(game.ui.top() != null and game.ui.top().name == "result_screen", "экран итога")


## Оценка доски обвинения: 3 улики → «всё верно» (3★), 1 → «кто и монстр» (2★), 0 → «только кто» (1★).
func _solve(elapsed: float, mistakes: int, key: Array) -> Dictionary:
	for id in key:
		_inv().give(id)
	_inv().mistakes = mistakes
	_inv().clock = _inv().start_time + elapsed
	var score: int = 3 if key.size() >= 3 else (2 if key.size() >= 1 else 1)
	return _inv().finish("solved", {"key": key.size(), "strong": true, "score": score})


func test_three_stars() -> void:
	await _start_level("level_01")
	var r: Dictionary = _solve(11.0, 0, ["d_robert_stub", "p_torn_page", "d_receipt"])
	check_eq(int(r["stars"]), 3, "всё верно на доске — 3 звезды")


func test_two_stars() -> void:
	await _start_level("level_01")
	var r: Dictionary = _solve(15.0, 1, ["d_robert_stub"])
	check_eq(int(r["stars"]), 2, "верны кто и монстр — 2 звезды")


func test_one_star() -> void:
	await _start_level("level_01")
	var r: Dictionary = _solve(18.0, 0, [])
	check_eq(int(r["stars"]), 1, "верен только кто — 1 звезда")


func test_unlock_next_and_no_duplicate_rewards() -> void:
	await _start_level("level_01")
	check(not ProgressionManager.level_unlocked("level_02"), "дело 2 закрыто")
	var r1: Dictionary = _solve(18.0, 0, [])
	check_eq(r1["unlocked_next"], "level_02", "дело 2 открылось сразу")
	check(ProgressionManager.level_unlocked("level_02"), "дело 2 доступно")
	check_eq(int(r1["new_stars"]), 1, "1 новая звезда")
	game.queue_free()
	await wait_frames(2)
	await _start_level("level_01")
	var r2: Dictionary = _solve(18.0, 0, [])
	check_eq(int(r2["new_stars"]), 0, "повтор с тем же результатом — без награды за звёзды")
	game.queue_free()
	await wait_frames(2)
	await _start_level("level_01")
	var r3: Dictionary = _solve(10.0, 0, ["d_robert_stub", "p_torn_page", "d_receipt"])
	check_eq(int(r3["new_stars"]), 2, "улучшение рекорда — награда только за 2 новые звезды")
	check_eq(ProgressionManager.level_stars("level_01"), 3, "сохранён лучший результат")


func test_next_case_button() -> void:
	await _start_level("level_01")
	_solve(18.0, 0, [])
	await wait_seconds(3.5)
	var scr: Node = game.ui.top()
	check(scr != null and scr.name == "result_screen", "экран итога")
	var found: bool = false
	for b in scr.find_children("*", "Button", true, false):
		if (b as Button).text == "Следующее дело":
			found = true
	check(found, "есть кнопка «Следующее дело»")


func test_save_restores_remaining_time() -> void:
	SaveManager.enabled = true
	SaveManager.save_path = "user://test_campaign_save.json"
	await _start_level("level_01", 123)
	_inv().advance(6.5)
	var left: float = _inv().minutes_left()
	game.autosave()
	game.queue_free()
	game = null
	await wait_frames(2)
	SaveManager.load_game()
	SaveManager.pending_resume = true
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await wait_frames(2)
	check(absf(_inv().minutes_left() - left) < 0.02, "оставшееся время восстановлено (%.2f / %.2f)" % [_inv().minutes_left(), left])
	check_eq(_inv().level_id, "level_01", "уровень восстановлен")
	check_eq(_inv().case_seed, 123, "seed попытки восстановлен")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_campaign_save.json"))
	SaveManager.enabled = false
	SaveManager.save_path = SaveManager.SAVE_PATH


func test_black_cloak_reveal() -> void:
	await _start_level("level_01")
	for id in ["d_robert_stub", "p_torn_page", "x_signature"]:
		_inv().give(id)
	game.accuse("robert", ["x_signature", "p_torn_page"], "")
	await wait_seconds(1.9)
	var npc: NPCController = game.npcs["robert"]
	var form: Node = npc.get_node_or_null("TrueForm")
	check(form != null, "появилась истинная форма")
	check(form != null and (form as AnimatedSprite2D).sprite_frames == Db.villain_frames("black_cloak"), "это Человек в чёрном плаще")
	check(not npc.sprite.visible, "обычный спрайт исчез")
	await wait_seconds(3.0)
	check(_inv().ended, "после сцены — итог")


func test_deadline_warnings_once() -> void:
	await _start_level("level_01")
	for i in 40:
		_inv().advance(0.5)
		if _inv().ended:
			break
	check_eq(_inv()._warned, [10, 5, 1], "пороги 10, 5 и 1 минута сработали по порядку")
