extends TestSuite
## Способности злодеев во время игры: облик перевёртыша, зеркала, мимик, ложные вызовы, тень.


func _start(level_id: String, seed_value: int = 21) -> void:
	SaveManager.profile["campaign"]["unlocked"] = 10
	# Общие способности злодеев живут в сгенерированных делах (дело дня); уровни кампании —
	# авторские и описывают проявления злодея сами.
	SaveManager.prepare_daily()
	SaveManager.pending_case = "gen:" + str(Db.level(level_id)["villain"])
	SaveManager.pending_seed = seed_value
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await wait_frames(2)
	game.ui.close_all()
	await wait_frames(1)


func _inv() -> InvestigationManager:
	return game.investigation


func _hook_cameras_valid(label: String) -> void:
	for cc: Dictionary in _inv().data["camera_clues"]:
		if not str(cc["id"]).begins_with("h_"):
			continue
		var rect: Rect2 = _inv().layout.camera(cc["camera"])["rect"]
		for w: Array in cc["windows"]:
			var t0: float = Db.parse_time(w[0])
			var t1: float = Db.parse_time(w[1])
			var seen: int = 0
			var n: int = 0
			var t: float = t0
			while t <= t1:
				n += 1
				if rect.has_point(_inv().timeline.position_at(cc["npc"], t)):
					seen += 1
				t += 1.0 / 240.0
			check(n > 0 and seen * 10 >= n * 9, "%s: запись %s совпадает с хронологией (%d/%d)" % [label, cc["id"], seen, n])


func test_shapeshifter_changes_look_in_tunnels() -> void:
	await _start("level_02")
	var h: VillainHooks = _inv().hooks
	var culprit: String = _inv().data["culprit"]
	var npc: NPCController = game.npcs[culprit]
	var first: String = h.disguise_at(_inv().clock)
	check(first != culprit, "перевёртыш с самого начала в чужом облике")
	await wait_frames(1)
	check_eq(npc.look_id, first, "спрайт показывает этот облик")
	check_eq(game.appearance(culprit), first, "карточка показывает этот облик")
	var m: Dictionary = _inv().murders.murders[0]
	_inv().advance(m["t"]["tunnel_in"] - _inv().clock + 0.01)
	await wait_frames(1)
	check_eq(npc.look_id, first, "до вспышки облик прежний")
	_inv().advance(MurderDirector.TO_FLICKER + 0.02)
	await wait_frames(2)
	check(npc.look_id != first, "после вспышки в туннеле облик сменился")
	check(_inv().data["clues"].has("h_shift_0"), "запись смены облика есть")
	_hook_cameras_valid("перевёртыш")
	var text_before: String = _inv().data["clues"]["h_shift_0"]["text"]
	_inv().give("h_shift_0")
	_inv().advance(8.0)
	check_eq(_inv().data["clues"]["h_shift_0"]["text"], text_before, "найденная улика не меняется задним числом")


func test_shapeshifter_deterministic() -> void:
	await _start("level_02", 77)
	var a: Array = _inv().hooks.disguises.map(func(e: Array) -> String: return e[1])
	game.queue_free()
	game = null
	await wait_frames(2)
	await _start("level_02", 77)
	var b: Array = _inv().hooks.disguises.map(func(e: Array) -> String: return e[1])
	check_eq(a, b, "тот же seed — те же облики")


func test_shapeshifter_playback_shows_past_look() -> void:
	await _start("level_02")
	var culprit: String = _inv().data["culprit"]
	var first: String = _inv().hooks.disguise_at(_inv().clock)
	var m: Dictionary = _inv().murders.murders[0]
	_inv().advance(m["t"]["tunnel_out"] - _inv().clock + 0.2)
	await wait_frames(1)
	game.open_cameras()
	await wait_frames(2)
	game.ui.top()._on_scrub(m["t"]["tunnel_in"] - 0.5)
	check_eq(game.npcs[culprit].look_id, first, "на записи до туннеля — прежний облик")
	game.ui.top().close()
	await wait_frames(2)
	check(game.npcs[culprit].look_id != first, "после записи — текущий облик")


func test_mirror_has_no_reflection() -> void:
	await _start("level_03")
	var culprit: String = _inv().data["culprit"]
	check(not _inv().hooks.has_reflection(culprit), "у зеркальника нет отражения")
	check(_inv().hooks.has_reflection("detective"), "у детектива отражение есть")
	var at_mirror: bool = false
	var t: float = _inv().start_time
	while t < _inv().arrival_time:
		if _inv().timeline.state_at(culprit, t)["spot"] == "end_mirror" and not _inv().timeline.state_at(culprit, t)["moving"]:
			at_mirror = true
			break
		t += 0.1
	check(at_mirror, "во время игры зеркальник подходит к зеркалу")
	# детектив у зеркала — его отражение видно
	game.player.global_position = Vector2(611, 104)
	await wait_frames(3)
	check(game.villain_world._mirrors[0]["sprite"].visible, "отражение детектива видно")


func test_mimic_bag_moves_and_gives_clue() -> void:
	await _start("level_04")
	var h: VillainHooks = _inv().hooks
	var before: Array = h.mimic_at(_inv().clock)
	var m: Dictionary = _inv().murders.murders[0]
	var after: Array = h.mimic_at(m["t"]["kill"] + 0.1)
	check(str(before) != str(after), "в туннеле чемодан переполз")
	game.open_object("obj_mimic_bag")
	await wait_frames(2)
	check(_inv().evidence.has("g_tag"), "бирка без рейса — улика")


func test_voice_false_call() -> void:
	await _start("level_06")
	var h: VillainHooks = _inv().hooks
	check(not h.calls.is_empty(), "запланирован ложный вызов")
	var c: Dictionary = h.calls[0]
	var log: Array = []
	_inv().case_event.connect(func(ev: Dictionary) -> void:
		if ev["type"] == "false_call":
			log.append(ev))
	_inv().advance(c["t"] - _inv().clock + 0.02)
	_inv().advance(0.5)
	check_eq(log.size(), 1, "вызов срабатывает один раз")
	check(_inv().evidence.has("h_call_0"), "вызов записан в журнал")
	var ids: Array = _inv().dialogue.topics(c["owner"], _inv().evidence).map(func(t: Dictionary) -> String: return t["id"])
	check("h_call_0" in ids, "у того, чей голос слышали, есть вопрос")
	_hook_cameras_valid("голос")


func test_shadow_wrong_shadow() -> void:
	await _start("level_05")
	var npc: NPCController = game.npcs[_inv().data["culprit"]]
	check(npc.shadow_wrong, "тень теневика неправильная")
	await wait_frames(3)
	check(npc._shadow.position.x > 4.0, "тень смещена к лампе")


func test_hook_cameras_valid_many_seeds() -> void:
	for lvl in ["level_02", "level_06"]:
		for s in [3, 14, 159]:
			await _start(lvl, s)
			_hook_cameras_valid("%s/%d" % [lvl, s])
			game.queue_free()
			game = null
			await wait_frames(2)
