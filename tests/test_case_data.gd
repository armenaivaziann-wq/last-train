extends TestSuite
## Честность дела: данные согласованы, записи камер совпадают с хронологией,
## виновника можно вычислить по нескольким независимым уликам.

const CASES: PackedStringArray = ["case_01"]


func _case(id: String) -> Dictionary:
	return Db.case_data(id)


func _layout(c: Dictionary) -> TrainLayout:
	return TrainLayout.build(PackedStringArray(c["carriages"]))


func test_case_files_parse() -> void:
	for id in CASES:
		var c: Dictionary = _case(id)
		check(not c.is_empty(), "дело %s загружается" % id)
		check(c["culprit"] in c["suspects"], "%s: виновник среди подозреваемых" % id)
		check(Db.monsters.has(c["monster"]), "%s: монстр есть в бестиарии" % id)
		for s: String in c["suspects"]:
			check(Db.characters.has(s), "%s: персонаж %s описан" % [id, s])
			check(c["dialogues"].has(s), "%s: у %s есть диалоги" % [id, s])
			check(c["schedules"].has(s), "%s: у %s есть расписание" % [id, s])


func test_schedule_spots_exist() -> void:
	for id in CASES:
		var c: Dictionary = _case(id)
		var tl := _layout(c)
		for npc: String in c["schedules"]:
			for e: Array in c["schedules"][npc]:
				check(tl.spots.has(str(e[1])), "%s/%s: точка %s существует" % [id, npc, e[1]])
		for lw: Dictionary in c.get("luggage_world", []):
			check(tl.slots.has(str(lw["slot"])), "%s: слот багажа %s" % [id, lw["slot"]])


func _all_clue_refs(c: Dictionary) -> Array:
	var refs: Array = []
	refs.append_array(c["brief"].get("gives", []))
	for who: String in c["dialogues"]:
		for t: Dictionary in c["dialogues"][who]["topics"]:
			refs.append_array(t.get("gives", []))
			refs.append_array(t.get("requires", []))
			refs.append_array(t.get("requires_any", []))
	for who: String in c["documents"]:
		var d: Dictionary = c["documents"][who]
		if d.has("on_open"):
			refs.append(d["on_open"])
		for h: Dictionary in d.get("hotspots", []):
			refs.append(h["clue"])
	for who: String in c["luggage"]:
		for item: Dictionary in c["luggage"][who].get("items", []):
			if item.has("on_open"):
				refs.append(item["on_open"])
			if item.has("hotspot"):
				refs.append(item["hotspot"]["clue"])
	for oid: String in c["objects"]:
		var o: Dictionary = c["objects"][oid]
		if o.has("on_open"):
			refs.append(o["on_open"])
		for h: Dictionary in o.get("hotspots", []):
			refs.append(h["clue"])
	for cc: Dictionary in c["camera_clues"]:
		refs.append(cc["id"])
	for d: Dictionary in c["deductions"]:
		refs.append(d["result"])
		refs.append_array(d["a"])
		refs.append_array(d["b"])
	refs.append_array(c["key_clues"])
	return refs


func test_all_clue_references_exist() -> void:
	for id in CASES:
		var c: Dictionary = _case(id)
		for ref in _all_clue_refs(c):
			check(c["clues"].has(str(ref)), "%s: улика %s описана" % [id, ref])
		for cid: String in c["clues"]:
			var clue: Dictionary = c["clues"][cid]
			check(clue["type"] in UiTheme.CLUE_TYPE_NAMES, "%s: тип улики %s" % [id, cid])
			for p in clue.get("points_to", []):
				check(str(p) in c["suspects"], "%s: %s указывает на существующего персонажа" % [id, cid])


func test_every_clue_is_obtainable() -> void:
	## Каждая улика должна иметь источник (иначе её нельзя найти).
	for id in CASES:
		var c: Dictionary = _case(id)
		var sources: Array = []
		sources.append_array(c["brief"].get("gives", []))
		for who: String in c["dialogues"]:
			for t: Dictionary in c["dialogues"][who]["topics"]:
				sources.append_array(t.get("gives", []))
		for who: String in c["documents"]:
			var d: Dictionary = c["documents"][who]
			if d.has("on_open"):
				sources.append(d["on_open"])
			for h: Dictionary in d.get("hotspots", []):
				sources.append(h["clue"])
		for who: String in c["luggage"]:
			for item: Dictionary in c["luggage"][who].get("items", []):
				if item.has("on_open"):
					sources.append(item["on_open"])
				if item.has("hotspot"):
					sources.append(item["hotspot"]["clue"])
		for oid: String in c["objects"]:
			var o: Dictionary = c["objects"][oid]
			if o.has("on_open"):
				sources.append(o["on_open"])
			for h: Dictionary in o.get("hotspots", []):
				sources.append(h["clue"])
		for cc: Dictionary in c["camera_clues"]:
			sources.append(cc["id"])
		for d: Dictionary in c["deductions"]:
			sources.append(d["result"])
		for cid: String in c["clues"]:
			check(cid in sources, "%s: у улики %s есть источник" % [id, cid])


func test_camera_clues_match_timeline() -> void:
	## Каждая «камерная» улика должна быть видна на записи: NPC в кадре камеры в своём окне.
	for id in CASES:
		var c: Dictionary = _case(id)
		var tl := _layout(c)
		var timeline := CaseTimeline.new(c, tl)
		var start: float = Db.parse_time(c["start"])
		for cc: Dictionary in c["camera_clues"]:
			var cam: Dictionary = tl.camera(cc["camera"])
			check(not cam.is_empty(), "%s: камера %s существует" % [id, cc["camera"]])
			if cam.is_empty():
				continue
			for w: Array in cc["windows"]:
				var t0: float = Db.parse_time(w[0])
				var t1: float = Db.parse_time(w[1])
				check(t1 <= start, "%s: запись %s в прошлом (до начала дела)" % [id, cc["id"]])
				var visible_count: int = 0
				var samples: int = 0
				var t: float = t0
				while t <= t1:
					samples += 1
					if cam["rect"].has_point(timeline.position_at(cc["npc"], t)):
						visible_count += 1
					t += 1.0 / 60.0
				check(visible_count * 2 >= samples, "%s: %s виден на %s в окне %s–%s (%d/%d)" % [id, cc["npc"], cc["camera"], w[0], w[1], visible_count, samples])


func test_robert_timeline_story() -> void:
	## Ключевая последовательность дела 1 вытекает из расписания.
	var c: Dictionary = _case("case_01")
	var tl := _layout(c)
	var timeline := CaseTimeline.new(c, tl)
	var svc: Rect2 = tl.camera("cam2")["rect"]
	check(not svc.has_point(timeline.position_at("robert", Db.parse_time("01:37"))), "в 01:37 Хейл не в служебном купе")
	check(svc.has_point(timeline.position_at("robert", Db.parse_time("01:40:30"))), "в 01:40:30 Хейл в служебном купе")
	check(not svc.has_point(timeline.position_at("john", Db.parse_time("01:40"))), "в 01:40 Джона в служебном купе нет")
	var vest: Rect2 = tl.camera("cam3")["rect"]
	check(vest.has_point(timeline.position_at("john", Db.parse_time("01:40"))), "в 01:40 Джон в тамбуре")
	check(vest.has_point(timeline.position_at("nina", Db.parse_time("01:42"))), "в 01:42 Нина в тамбуре")
	var agata: Vector2 = timeline.position_at("agata", Db.parse_time("01:40"))
	check(agata.x > tl.offsets["restaurant"], "в 01:40 Агата в ресторане")
	var tikhon: Vector2 = timeline.position_at("tikhon", Db.parse_time("01:40"))
	check(tikhon.x > tl.offsets["restaurant"], "в 01:40 Тихон в ресторане")


func test_culprit_has_independent_evidence() -> void:
	## Виновника подтверждают улики минимум трёх разных типов — решение не угадывается.
	for id in CASES:
		var c: Dictionary = _case(id)
		var types: Dictionary = {}
		for k: String in c["key_clues"]:
			var clue: Dictionary = c["clues"][k]
			check(c["culprit"] in clue.get("points_to", []), "%s: ключевая улика %s указывает на виновника" % [id, k])
			types[clue["type"]] = true
		check(types.size() >= 3, "%s: ключевые улики разных типов (%d)" % [id, types.size()])


func test_innocents_have_explanations() -> void:
	## Подозрительное поведение невиновных объясняется найденными фактами.
	var c: Dictionary = _case("case_01")
	for who in ["louis", "klara", "tikhon", "nina", "john"]:
		var explained: bool = false
		for cid: String in c["clues"]:
			if who in c["clues"][cid].get("points_to", []) and not cid in c["key_clues"]:
				explained = true
		check(explained, "у %s есть объясняющие улики" % who)
