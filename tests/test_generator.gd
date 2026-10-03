extends TestSuite
## Сгенерированные дела (уровни 2–10, дело дня) честные и решаемые при любом seed:
## улики описаны и доступны, записи камер совпадают с хронологией, у виновника минимум
## три ключевые улики разных типов, предметы лежат в играбельных вагонах, вариантов несколько.

const SEEDS: Array = [1, 2, 3, 17, 4242, 99991]


func _levels() -> Array:
	return Db.levels().filter(func(l: Dictionary) -> bool: return l["case"] == "gen")


func _sources(c: Dictionary) -> Array:
	var s: Array = []
	s.append_array(c["brief"].get("gives", []))
	for who: String in c["dialogues"]:
		for t: Dictionary in c["dialogues"][who]["topics"]:
			s.append_array(t.get("gives", []))
	for who: String in c["documents"]:
		var dd: Dictionary = c["documents"][who]
		if dd.has("on_open"):
			s.append(dd["on_open"])
		s.append_array(dd.get("gives", []))
		for h: Dictionary in dd.get("hotspots", []):
			s.append(h["clue"])
	for who: String in c["luggage"]:
		for it: Dictionary in c["luggage"][who].get("items", []):
			if it.has("on_open"):
				s.append(it["on_open"])
			if it.has("hotspot"):
				s.append(it["hotspot"]["clue"])
	for oid: String in c["objects"]:
		if c["objects"][oid].has("on_open"):
			s.append(c["objects"][oid]["on_open"])
	for cc: Dictionary in c["camera_clues"]:
		s.append(cc["id"])
	for x: Dictionary in c["deductions"]:
		s.append(x["result"])
	return s


func _murder_clue(c: Dictionary, id: String) -> bool:
	for sid: String in c["murders"]["scenarios"]:
		var pre: String = str(c["murders"]["scenarios"][sid]["prefix"])
		if id.begins_with(pre + "_") or id == "c_" + pre or id.begins_with("x_" + pre + "_"):
			return true
	return false


func _check_case(c: Dictionary, label: String) -> void:
	var tl := TrainLayout.build(PackedStringArray(c["carriages"]))
	var timeline := CaseTimeline.new(c, tl)
	var culprit: String = c["culprit"]
	check(culprit in c["suspects"], "%s: виновник среди подозреваемых" % label)
	check(Db.monsters.has(c["monster"]), "%s: злодей описан" % label)
	var src: Array = _sources(c)
	# все ссылки на улики существуют
	for x: Dictionary in c["deductions"]:
		for id in x["a"] + x["b"] + [x["result"]]:
			check(c["clues"].has(id), "%s: вывод ссылается на улику %s" % [label, id])
	for id in src:
		check(c["clues"].has(str(id)), "%s: источник даёт описанную улику %s" % [label, id])
	# ключевые улики: доступны (кроме улик убийств — они появляются при убийстве), указывают на виновника
	var types: Dictionary = {}
	for id: String in c["key_clues"]:
		check(c["clues"].has(id), "%s: ключевая %s описана" % [label, id])
		if not c["clues"].has(id):
			continue
		check(culprit in c["clues"][id]["points_to"], "%s: ключевая %s указывает на виновника" % [label, id])
		if not _murder_clue(c, id):
			check(id in src, "%s: ключевую %s можно найти" % [label, id])
			types[c["clues"][id]["type"]] = true
	check(types.size() >= 3, "%s: ключевые улики минимум трёх типов (%s)" % [label, types.keys()])
	# записи камер совпадают с хронологией
	for cc: Dictionary in c["camera_clues"]:
		var cam: Dictionary = tl.camera(cc["camera"])
		check(not cam.is_empty(), "%s: камера %s" % [label, cc["camera"]])
		for w: Array in cc["windows"]:
			var t0: float = Db.parse_time(w[0])
			var t1: float = Db.parse_time(w[1])
			check(t1 <= Db.parse_time(c["start"]), "%s: запись %s в прошлом" % [label, cc["id"]])
			var seen: int = 0
			var n: int = 0
			var t: float = t0
			while t <= t1:
				n += 1
				if cam["rect"].has_point(timeline.position_at(cc["npc"], t)):
					seen += 1
				t += 1.0 / 120.0
			check(n > 0 and seen * 10 >= n * 9, "%s: %s видно на записи %s (%d/%d)" % [label, cc["npc"], cc["id"], seen, n])
	# предметы-улики — в играбельных вагонах, на полу, не в стене
	for it: Dictionary in c.get("extra_items", []):
		check(it["carriage"] in c["carriages"], "%s: предмет %s в играбельном вагоне" % [label, it["id"]])
		var y: float = float(it["pos"][1])
		check(y > 60.0 and y < 190.0, "%s: предмет %s на полу" % [label, it["id"]])
		for r: Array in Db.layout(it["carriage"])["colliders"]:
			var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
			check(not rect.has_point(Vector2(float(it["pos"][0]), y)), "%s: предмет %s не внутри мебели" % [label, it["id"]])
	# убийства: жертва не виновник/герой/подозреваемый, свидетели не виновник
	for sid: String in c["murders"]["scenarios"]:
		var sc: Dictionary = c["murders"]["scenarios"][sid]
		check(not sc["victim"] in c["suspects"], "%s: жертва не подозреваемый" % label)
		for w: Dictionary in sc["witnesses"]:
			check(w["npc"] != culprit, "%s: свидетель убийства — не виновник" % label)
	for npc: String in c["schedules"]:
		for e: Array in c["schedules"][npc]:
			check(tl.spots.has(str(e[1])), "%s: точка расписания %s" % [label, e[1]])


func test_all_generated_levels_are_fair() -> void:
	for l: Dictionary in _levels():
		for s in SEEDS:
			var c: Dictionary = Db.resolve_case(Db.level_case_ref(l), s)
			_check_case(c, "%s/%d" % [l["id"], s])
		if failures.size() > 30:
			return


func test_daily_cases_are_fair() -> void:
	for v in ["black_cloak", "shadow", "mimic"]:
		_check_case(Db.resolve_case("gen:" + v, 777), "daily " + v)


func test_variants_differ_by_seed() -> void:
	for l: Dictionary in _levels():
		var keys: Dictionary = {}
		for s in SEEDS:
			var c: Dictionary = Db.resolve_case(Db.level_case_ref(l), s)
			keys["%s|%s" % [c["culprit"], c["clues"]["g_incident"]["text"]]] = true
		check(keys.size() >= 2, "%s: минимум 2 варианта дела (%d)" % [l["id"], keys.size()])


func test_same_seed_same_case() -> void:
	var a: Dictionary = Db.resolve_case("gen:level_05", 31)
	var b: Dictionary = Db.resolve_case("gen:level_05", 31)
	check_eq(a["culprit"], b["culprit"], "тот же seed — тот же виновник")
	check_eq(JSON.stringify(a["schedules"]), JSON.stringify(b["schedules"]), "и то же расписание")


func test_fixed_culprits() -> void:
	check_eq(Db.resolve_case("gen:level_08", 5)["culprit"], "agata", "двойник проводницы — в форме Агаты")
	check_eq(Db.resolve_case("gen:level_10", 5)["culprit"], "tikhon", "пассажир ноль — человек без имени")


func test_generated_level_plays() -> void:
	SaveManager.profile["campaign"]["unlocked"] = 10
	for lid in ["level_02", "level_06", "level_10"]:
		SaveManager.prepare_level(lid)
		SaveManager.pending_seed = 11
		game = load("res://game/game.tscn").instantiate()
		add_child(game)
		await wait_frames(2)
		game.ui.close_all()
		var inv: InvestigationManager = game.investigation
		check_eq(inv.level_id, lid, "%s запущен" % lid)
		inv.advance(2.0)
		check(not inv.ended, "%s идёт" % lid)
		var key: Array = inv.data["key_clues"].filter(func(id: String) -> bool: return inv.murder_scenario_of_clue(id) == "").slice(0, 3)
		for id in key:
			inv.give(id)
		var r: Dictionary = inv.accuse(inv.data["culprit"], key, inv.data["monster"])
		check(r["correct"], "%s: виновника можно задержать" % lid)
		game.queue_free()
		game = null
		await wait_frames(2)
