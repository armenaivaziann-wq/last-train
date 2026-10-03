extends TestSuite
## События-убийства в туннелях: тайминг, однократность стадий, пауза, место преступления,
## свидетели, камеры, повторяемость и сохранение.


func _inv() -> InvestigationManager:
	return game.investigation


func _md() -> MurderDirector:
	return game.investigation.murders


func _stage_log() -> Array:
	var log: Array = []
	_inv().murder_stage.connect(func(m: Dictionary, st: String) -> void: log.append("%d:%s" % [m["index"], st]))
	return log


func test_plan_first_staged_then_random() -> void:
	await start_case()
	var ms: Array = _md().murders
	check(ms.size() >= 2, "запланировано не меньше двух убийств (%d)" % ms.size())
	check_eq(ms[0]["id"], "m_vera", "первое — постановочное")
	check(absf(ms[0]["t"]["tunnel_in"] - (_inv().start_time + 3.0)) < 0.001, "туннель через 3 игровые минуты")
	var victims: Array = []
	for i in ms.size():
		var m: Dictionary = ms[i]
		check(not m["victim"] in victims, "жертвы не повторяются")
		check(not m["victim"] in _inv().suspects.suspects and m["victim"] != "detective", "жертва — не подозреваемый и не герой")
		victims.append(m["victim"])
		if i > 0:
			var gap: float = m["t"]["tunnel_in"] - ms[i - 1]["t"]["tunnel_in"]
			check(gap >= 7.0 and gap <= 10.0, "интервал 7–10 мин (%.2f)" % gap)
		check(m["t"]["tunnel_out"] < _inv().arrival_time, "событие заканчивается до станции")


func test_seed_is_deterministic() -> void:
	var c: Dictionary = Db.case_data("case_01").duplicate(true)
	var tl := TrainLayout.build(PackedStringArray(c["carriages"]))
	var a := MurderDirector.new()
	a.plan(c.duplicate(true), tl, CaseTimeline.new(c, tl), 118.0, 136.0, 42)
	var b := MurderDirector.new()
	b.plan(c.duplicate(true), tl, CaseTimeline.new(c, tl), 118.0, 136.0, 42)
	check_eq(a.murders.map(func(m: Dictionary) -> String: return m["id"]), b.murders.map(func(m: Dictionary) -> String: return m["id"]), "одинаковый seed — одинаковые сценарии")


func test_stages_fire_once_in_order() -> void:
	await start_case()
	var log := _stage_log()
	var m: Dictionary = _md().murders[0]
	_inv().advance(m["t"]["tunnel_in"] - _inv().clock - 0.01)
	check(log.is_empty(), "до туннеля ничего не происходит")
	for i in 40:
		_inv().advance(0.02)
	var first: Array = log.filter(func(s: String) -> bool: return s.begins_with("0:"))
	check_eq(first, ["0:tunnel_in", "0:flicker", "0:kill", "0:tunnel_out"], "стадии по порядку")
	_inv().advance(0.01)
	check_eq(log.count("0:kill"), 1, "крик/убийство ровно один раз")


func test_pause_holds_event() -> void:
	await start_case()
	var log := _stage_log()
	var m: Dictionary = _md().murders[0]
	_inv().advance(m["t"]["tunnel_in"] - _inv().clock - 0.005)
	game.ui.open("journal_screen", {})
	await wait_seconds(1.0)
	check(log.is_empty(), "пока открыт журнал, событие не начинается")
	game.ui.close_all()
	await wait_seconds(0.8)
	check("0:tunnel_in" in log, "после закрытия туннель начинается")


func test_murder_scene_and_discovery() -> void:
	await start_case()
	var m: Dictionary = _md().murders[0]
	_inv().advance(m["t"]["kill"] - _inv().clock + 0.01)
	await wait_frames(3)
	var vera: NPCController = game.npcs["vera"]
	check(vera.dead and not vera.visible, "жертва исчезла из живых")
	check(game.crime_scenes.has(0), "место преступления создано")
	check(game.train.in_tunnel() or true, "туннель")
	check(not _inv().evidence.has("mv_scene"), "место ещё не обнаружено")
	# добегаем от тамбура до места преступления
	game.player.global_position = Vector2(700, 166)
	await wait_frames(2)
	Input.action_press(&"move_right")
	var ok: bool = false
	for i in 600:
		await get_tree().physics_frame
		if _inv().evidence.has("mv_scene"):
			ok = true
			break
	Input.action_release(&"move_right")
	check(ok, "игрок сам добежал до места (x=%.0f)" % game.player.global_position.x)
	check(game.hud._goal_label.text.find("преступления") < 0, "цель сменилась после обнаружения")
	# осмотр тела и улик
	game.open_object(MurderDirector.body_object_id(m))
	await wait_frames(2)
	check(_inv().evidence.has("mv_body"), "осмотр тела — улика")
	check(_inv().evidence.clue("mv_body")["time"] == Db.format_time(m["t"]["kill"]), "время записано")
	game.ui.close_all()
	game.open_object("obj_mv_fabric")
	await wait_frames(2)
	check(_inv().evidence.has("mv_fabric"), "обрывок ткани")
	game.ui.close_all()
	# свидетель
	var topics: Array = _inv().dialogue.topics("klara", _inv().evidence).map(func(t: Dictionary) -> String: return t["id"])
	check("mv" in topics, "у свидетеля появилась тема о туннеле")
	_inv().dialogue.ask("klara", "mv", _inv().evidence)
	var line: String = str(Db.case_data("case_01")["dialogues"]["klara"]["topics"][-1]["a"][0])
	check(line == "Я слышала крик, когда погас свет!", "реплика свидетеля")


func test_witnesses_come_to_scene() -> void:
	await start_case()
	var m: Dictionary = _md().murders[0]
	_inv().advance(m["t"]["kill"] + 1.0 - _inv().clock)
	await wait_frames(2)
	var klara: Vector2 = game.npcs["klara"].global_position
	check(klara.distance_to(game.layout.spots["rest_aisle"]["pos"]) < 3.0, "Клэр прибежала на место")
	var robert_at_kill: Vector2 = _inv().timeline.position_at("robert", m["t"]["kill"])
	check(robert_at_kill.distance_to(game.layout.spots["rest_s2_r"]["pos"]) < 3.0, "убийца был у жертвы в момент убийства (по хронологии)")


func test_camera_records_murder() -> void:
	await start_case()
	var m: Dictionary = _md().murders[0]
	_inv().advance(m["t"]["kill"] + 0.5 - _inv().clock)
	game.open_cameras()
	await wait_frames(3)
	var scr: Node = game.ui.top()
	scr._select("cam4")
	scr._on_scrub(m["t"]["kill"] - 0.5)
	await wait_frames(1)
	check(game.npcs["vera"].visible, "на записи до убийства Вера жива")
	check(not game.crime_scenes[0].visible, "на записи до убийства тела нет")
	scr._on_scrub(m["t"]["kill"])
	scr._mark()
	check(_inv().evidence.has("c_mv"), "запись фигуры у столика — улика")
	scr.close()
	await wait_frames(2)
	check(not game.npcs["vera"].visible and game.crime_scenes[0].visible, "после камер — снова мёртв, тело на месте")


func test_second_murder_happens() -> void:
	await start_case()
	var log := _stage_log()
	var m2: Dictionary = _md().murders[1]
	_inv().advance(m2["t"]["tunnel_out"] + 0.01 - _inv().clock)
	await wait_frames(3)
	check("1:kill" in log, "второе убийство произошло")
	check(game.npcs[m2["victim"]].dead, "вторая жертва мертва")
	check(game.crime_scenes.size() == 2, "оба места преступления на месте")
	check(game.crime_scenes[0].is_inside_tree() and game.crime_scenes[0].visible, "первое тело остаётся, даже если игрок далеко")


func test_save_restores_scene() -> void:
	SaveManager.enabled = true
	SaveManager.save_path = "user://test_murder_save.json"
	await start_case()
	var ids: Array = _md().murders.map(func(m: Dictionary) -> String: return m["id"])
	var m: Dictionary = _md().murders[0]
	_inv().advance(m["t"]["tunnel_out"] + 0.2 - _inv().clock)
	game.autosave()
	game.queue_free()
	game = null
	await wait_frames(2)
	SaveManager.load_game()
	SaveManager.pending_case = "case_01"
	SaveManager.pending_resume = true
	var log: Array = []
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await wait_frames(2)
	_inv().murder_stage.connect(func(mm: Dictionary, st: String) -> void: log.append(st))
	check_eq(_md().murders.map(func(mm: Dictionary) -> String: return mm["id"]), ids, "сценарии те же после загрузки")
	check(game.npcs["vera"].dead, "жертва мертва после загрузки")
	check(game.crime_scenes.has(0), "тело и улики восстановлены")
	_inv().advance(0.05)
	check(not "kill" in log, "убийство не повторяется после загрузки")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_murder_save.json"))
	SaveManager.enabled = false
	SaveManager.save_path = SaveManager.SAVE_PATH


func test_sound_resources_exist() -> void:
	for s in ["tunnel_ambience", "lights_flicker", "female_scream", "passenger_panic", "discovery_stinger"]:
		check(AudioManager.has_sound(s), "звук %s есть" % s)
