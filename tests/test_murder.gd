extends TestSuite
## Убийства в туннелях: один въезд — одно убийство случайного живого допустимого пассажира;
## погибших повторно не выбирают; стадии срабатывают один раз; улики и подсказки — из фактов
## события; всё переживает сохранение; без допустимых жертв туннель проходит безопасно.

const OLD_TEXTS: PackedStringArray = ["третьей кабинк", "третьему столику", "Х. — не тот", "коричнев"]


func _inv() -> InvestigationManager:
	return game.investigation


func _md() -> MurderDirector:
	return game.investigation.murders


func _start_level(level_id: String, seed_value: int) -> void:
	SaveManager.profile["campaign"]["unlocked"] = 10
	SaveManager.prepare_level(level_id)
	SaveManager.pending_seed = seed_value
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await wait_frames(2)
	game.ui.close_all()
	await wait_frames(1)


func _stage_log() -> Array:
	var log: Array = []
	_inv().murder_stage.connect(func(m: Dictionary, st: String) -> void: log.append("%d:%s" % [m["index"], st]))
	return log


func test_each_tunnel_kills_new_allowed_victim() -> void:
	for s in [1, 7, 42, 1000]:
		await _start_level("level_01", s)
		var pool: Array = MurderDirector.victim_pool(_inv().data)
		var victims: Array = []
		check(_md().murders.size() >= 2, "seed %d: минимум два туннеля" % s)
		for m: Dictionary in _md().murders:
			if m["victim"] == "":
				continue
			check(m["victim"] in pool, "seed %d: жертва %s допустима" % [s, m["victim"]])
			check(not m["victim"] in victims, "seed %d: погибших повторно не выбирают" % s)
			check(not m["victim"] in ["robert", "agata", "john", "klara", "nina", "tikhon", "detective"], "seed %d: защищённые сюжетные NPC не погибают" % s)
			victims.append(m["victim"])
		check(absf(_md().murders[0]["t"]["tunnel_in"] - (_inv().start_time + 3.0)) < 0.001, "первый туннель через 3 игровые минуты")
		game.queue_free()
		game = null
		await wait_frames(2)


func test_victims_vary_between_seeds() -> void:
	var firsts: Dictionary = {}
	for s in [1, 2, 3, 4, 5, 6, 7, 8]:
		var c: Dictionary = Db.resolve_case("case_01", s)
		var tl := TrainLayout.build(PackedStringArray(c["carriages"]))
		var md := MurderDirector.new()
		md.plan(c, tl, CaseTimeline.new(c, tl), 118.0, 138.0, s)
		firsts[md.murders[0]["victim"]] = true
	check(firsts.size() >= 2, "первая жертва случайна (%s)" % [firsts.keys()])


func test_one_murder_per_tunnel_and_once() -> void:
	await _start_level("level_01", 7)
	var log := _stage_log()
	var m: Dictionary = _md().murders[0]
	_inv().advance(m["t"]["tunnel_in"] - _inv().clock - 0.01)
	check(log.is_empty(), "до туннеля ничего не происходит")
	for i in 60:
		_inv().advance(0.02)
	var first: Array = log.filter(func(s: String) -> bool: return s.begins_with("0:"))
	check_eq(first, ["0:tunnel_in", "0:flicker", "0:kill", "0:tunnel_out"], "стадии по порядку, по одному разу")
	_inv().advance(0.01)
	check_eq(log.count("0:kill"), 1, "одно убийство на въезд")
	# меню и камеры не перезапускают событие
	game.open_journal()
	await wait_frames(3)
	game.ui.close_all()
	game.open_cameras()
	await wait_frames(3)
	game.ui.top().close()
	await wait_frames(3)
	check_eq(log.count("0:kill"), 1, "после меню и камер — всё ещё одно убийство")


func test_second_murder_other_victim() -> void:
	await _start_level("level_01", 11)
	var m1: Dictionary = _md().murders[0]
	var m2: Dictionary = _md().murders[1]
	_inv().advance(m2["t"]["tunnel_out"] + 0.01 - _inv().clock)
	await wait_frames(3)
	check(m1["victim"] != m2["victim"], "вторая жертва — другой пассажир")
	check(game.npcs[m1["victim"]].dead and game.npcs[m2["victim"]].dead, "обе жертвы мертвы")
	check(game.crime_scenes.size() == 2, "два места преступления")
	check(game.crime_scenes[0].is_inside_tree() and game.crime_scenes[0].visible, "первое тело остаётся на месте")


func test_texts_are_personal_and_case_specific() -> void:
	for lvl in ["level_01", "level_02", "level_05"]:
		await _start_level(lvl, 3)
		for m: Dictionary in _md().murders:
			if m["victim"] == "":
				continue
			var pre: String = m["prefix"]
			for id in [pre + "_scene", pre + "_body", pre + "_fibers", pre + "_steps"]:
				var c: Dictionary = _inv().data["clues"][id]
				var t: String = str(c["title"]) + " " + str(c["text"])
				for bad in OLD_TEXTS:
					check(t.find(bad) < 0, "%s %s: нет чужого текста «%s»" % [lvl, id, bad])
				check(t.find(Db.char_name(m["victim"])) >= 0 or id.ends_with("_steps") or id.ends_with("_fibers"), "%s %s: упоминает жертву" % [lvl, id])
			check(str(_inv().data["clues"][pre + "_scene"]["text"]).find(str(m["where"])) >= 0, "%s: указан вагон" % lvl)
			check(str(_inv().data["clues"][pre + "_scene"]["text"]).find(Db.format_time(m["t"]["kill"])) >= 0, "%s: указано время" % lvl)
		if lvl == "level_01":
			var fib: String = _inv().data["clues"]["mk0_fibers"]["text"]
			check(fib.find("чёрн") >= 0, "в первой локации — чёрные волокна плаща маньяка")
		game.queue_free()
		game = null
		await wait_frames(2)


func test_steps_lead_where_murderer_went() -> void:
	await _start_level("level_01", 5)
	for m: Dictionary in _md().murders:
		if m["victim"] == "":
			continue
		var after: Dictionary = _inv().timeline.state_at(_md().murderer, m["t"]["kill"] + 0.5)
		var expect: String = CaseGenerator.spot_direction(str(after["spot"]))
		check(str(_inv().data["clues"][m["prefix"] + "_steps"]["text"]).find(expect) >= 0, "следы ведут туда, куда ушёл убийца (%s)" % expect)


func test_goal_follows_investigation_stage() -> void:
	await _start_level("level_01", 9)
	var m: Dictionary = _md().murders[0]
	_inv().advance(m["t"]["kill"] - _inv().clock + 0.02)
	game.player.global_position = Vector2(game.layout.offsets["passenger"] + 40, 166) if m["carriage"] != "passenger" else Vector2(game.layout.offsets["restaurant"] + 300, 166)
	await wait_frames(2)
	game.update_goal()
	check(game.hud._goal_label.text.find("идите в") >= 0, "игрок в другом вагоне — цель «идите в …» (%s)" % game.hud._goal_label.text)
	game.player.global_position = m["scene_pos"] + Vector2(0, -2)
	await wait_frames(3)
	check(_inv().evidence.has(m["prefix"] + "_scene"), "место обнаружено")
	game.update_goal()
	check(game.hud._goal_label.text.find("осмотрите тело") >= 0, "дальше — осмотреть тело (%s)" % game.hud._goal_label.text)
	game.open_object(MurderDirector.body_object_id(m))
	await wait_frames(2)
	game.ui.close_all()
	game.update_goal()
	check(game.hud._goal_label.text.find("следы") >= 0, "после тела — следы (%s)" % game.hud._goal_label.text)
	game.open_object("obj_%s_steps" % m["prefix"])
	await wait_frames(2)
	game.ui.close_all()
	game.update_goal()
	var g: String = game.hud._goal_label.text
	check(g.find("свидетел") >= 0 or g.find("камеры") >= 0 or g.find("Цель") >= 0, "дальше — свидетель или камера (%s)" % g)
	# Найденная улика не показывается как новая
	var n: int = _inv().evidence.found.size()
	game.ui.close_all()
	game.open_object(MurderDirector.body_object_id(m))
	await wait_frames(2)
	check_eq(_inv().evidence.found.size(), n, "повторный осмотр не даёт «новую» улику")


func test_camera_records_murder() -> void:
	await _start_level("level_01", 13)
	var m: Dictionary = _md().murders[0]
	_inv().advance(m["t"]["kill"] + 0.5 - _inv().clock)
	game.open_cameras()
	await wait_frames(3)
	var scr: Node = game.ui.top()
	scr._select(str(m["camera"]))
	scr._on_scrub(m["t"]["kill"] - 0.5)
	await wait_frames(1)
	check(game.npcs[m["victim"]].visible, "на записи до убийства жертва жива")
	check(not game.crime_scenes[0].visible, "до убийства тела нет")
	scr._on_scrub(m["t"]["kill"])
	scr._mark()
	check(_inv().evidence.has("c_" + m["prefix"]), "запись убийцы у жертвы — улика")
	scr.close()
	await wait_frames(2)
	check(not game.npcs[m["victim"]].visible and game.crime_scenes[0].visible, "после камер — тело на месте")


func test_pause_holds_event() -> void:
	await _start_level("level_01", 7)
	var log := _stage_log()
	var m: Dictionary = _md().murders[0]
	_inv().advance(m["t"]["tunnel_in"] - _inv().clock - 0.005)
	game.ui.open("journal_screen", {})
	await wait_seconds(1.0)
	check(log.is_empty(), "пока открыт журнал, событие не начинается")
	game.ui.close_all()
	await wait_seconds(0.8)
	check("0:tunnel_in" in log, "после закрытия туннель начинается")


func test_save_restores_murders_and_clues() -> void:
	SaveManager.enabled = true
	SaveManager.save_path = "user://test_murder_save.json"
	await _start_level("level_01", 21)
	var victims: Array = _md().murders.map(func(m: Dictionary) -> String: return m["victim"])
	var m: Dictionary = _md().murders[0]
	_inv().advance(m["t"]["tunnel_out"] + 0.2 - _inv().clock)
	_inv().discover_murder(m)
	_inv().give(m["prefix"] + "_body")
	game.autosave()
	game.queue_free()
	game = null
	await wait_frames(2)
	SaveManager.load_game()
	SaveManager.pending_resume = true
	var log: Array = []
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await wait_frames(2)
	_inv().murder_stage.connect(func(mm: Dictionary, st: String) -> void: log.append(st))
	check_eq(_md().murders.map(func(mm: Dictionary) -> String: return mm["victim"]), victims, "те же жертвы после загрузки")
	check(game.npcs[m["victim"]].dead, "жертва мертва после загрузки")
	check(game.crime_scenes.has(0), "тело и улики на месте")
	check(_inv().evidence.has(m["prefix"] + "_body"), "найденная улика сохранена")
	check(_inv().data["clues"].has(m["prefix"] + "_steps"), "улики события восстановлены")
	_inv().advance(0.05)
	check(not "kill" in log and not "discovered" in log, "события не повторяются после загрузки")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_murder_save.json"))
	SaveManager.enabled = false
	SaveManager.save_path = SaveManager.SAVE_PATH


func test_no_victims_left_is_safe() -> void:
	var c: Dictionary = Db.resolve_case("case_01", 3)
	c["murders"]["victim_pool"] = ["vera"]
	var tl := TrainLayout.build(PackedStringArray(c["carriages"]))
	var md := MurderDirector.new()
	md.plan(c, tl, CaseTimeline.new(c, tl), 118.0, 138.0, 3)
	check(md.murders.size() >= 2, "туннелей больше, чем жертв")
	check_eq(md.murders[0]["victim"], "vera", "первая жертва — единственная допустимая")
	check_eq(md.murders[1]["victim"], "", "дальше жертв нет — туннель без убийства")
	md.stages_done.clear()
	var stages: Array = md.due(200.0).map(func(p: Array) -> String: return "%d:%s" % [p[0]["index"], p[1]])
	check(not "1:kill" in stages, "без жертвы стадии убийства нет")
	check("1:tunnel_in" in stages, "но туннель есть")


func test_sound_resources_exist() -> void:
	for s in ["tunnel_ambience", "lights_flicker", "female_scream", "passenger_panic", "discovery_stinger"]:
		check(AudioManager.has_sound(s), "звук %s есть" % s)
