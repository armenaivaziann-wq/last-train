extends TestSuite
## Авторские дела кампании (уровни 2–10): каждое проходится от начала до решения.
## «Решатель» действует как игрок — без доступа к ответу: каждую игровую минуту открывает
## всё, что доступно (документы, багаж, предметы мира, темы разговоров, реакции на улики,
## записи камер, выводы), и проверяет:
##   • все ключевые улики получаемы до прибытия;
##   • против виновника есть ≥3 связанных доказательства и хотя бы один вывод;
##   • верное обвинение с верным мотивом и способом даёт победу, неверное — ошибку;
##   • повторный туннель не повторяет события, сохранение/загрузка не ломает дело;
##   • истечение времени — поражение.




## Все авторские дела кампании, кроме первого (у него свой набор тестов).
var AUTHORED: Array:
	get:
		return Db.levels().filter(func(l: Dictionary) -> bool: return str(l.get("case", "gen")) != "gen" and l["id"] != "level_01").map(func(l: Dictionary) -> String: return str(l["id"]))


func _start_level(level_id: String, seed_value: int = 7) -> void:
	SaveManager.prepare_level(level_id)
	SaveManager.pending_seed = seed_value
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await wait_frames(2)
	game.ui.close_all()
	await wait_frames(1)


func _inv() -> InvestigationManager:
	return game.investigation


func _world_objects() -> Array:
	var out: Array = game.world_items.keys()
	for l: Dictionary in _inv().data.get("shadow_ghost", {}).get("linger", []):
		if _inv().clock >= Db.parse_time(str(l["from"])) and _inv().clock < Db.parse_time(str(l["to"])):
			out.append(l["object"])
	for cid in game.layout.carriage_ids:
		for it: Dictionary in Db.layout(cid).get("interactables", []):
			out.append(it["id"])
	return out


## Один проход «как игрок» по всему, что доступно прямо сейчас. Возвращает, найдено ли новое.
func _sweep() -> bool:
	var inv: InvestigationManager = _inv()
	var d: Dictionary = inv.data
	var ev: EvidenceSystem = inv.evidence
	var before: int = ev.found.size()
	for npc: String in d.get("documents", {}):
		var doc: Dictionary = d["documents"][npc]
		if doc.has("on_open"):
			inv.give(str(doc["on_open"]))
		inv.give_all(doc.get("gives", []))
		for h: Dictionary in doc.get("hotspots", []):
			inv.give(str(h["clue"]))
	for npc: String in d.get("luggage", {}):
		for it: Dictionary in d["luggage"][npc].get("items", []):
			if it.has("requires_upgrade"):
				continue
			if it.has("on_open"):
				inv.give(str(it["on_open"]))
			if it.has("hotspot"):
				inv.give(str(it["hotspot"]["clue"]))
	for oid: String in _world_objects():
		var o: Dictionary = d["objects"].get(oid, {})
		if o.is_empty():
			continue
		var locked: bool = false
		for r: String in o.get("requires", []):
			if not ev.has(r):
				locked = true
		var any: Array = o.get("requires_any", [])
		if not any.is_empty() and not any.any(func(r: String) -> bool: return ev.has(r)):
			locked = true
		if locked:
			if o.has("locked_clue"):
				inv.give(str(o["locked_clue"]))
			continue
		if o.has("on_open"):
			inv.give(str(o["on_open"]))
		for h: Dictionary in o.get("hotspots", []):
			inv.give(str(h["clue"]))
	for npc: String in d.get("dialogues", {}):
		if inv.state_of(npc) in ["dead", "missing"]:
			continue
		var ctx: Dictionary = inv.dialogue_ctx(npc)
		for t: Dictionary in inv.dialogue.topics(npc, ev, ctx):
			inv.dialogue.ask(npc, t["id"], ev, ctx)
			inv.give_all(t.get("gives", []))
		for cid: String in d["dialogues"][npc].get("reactions", {}):
			if ev.has(cid):
				inv.present(npc, cid)
	for cc: Dictionary in d.get("camera_clues", []):
		if Db.parse_time(cc["windows"][0][0]) <= inv.clock:
			inv.give(str(cc["id"]))
	for x: Dictionary in d.get("deductions", []):
		if ev.has(x["result"]):
			continue
		for a: String in x["a"]:
			for b: String in x["b"]:
				if ev.has(a) and ev.has(b) and not ev.has(x["result"]):
					inv.deduce(a, b)
	return ev.found.size() > before


func _solve_all() -> void:
	var inv: InvestigationManager = _inv()
	while inv.clock < inv.arrival_time - 0.6:
		while _sweep():
			pass
		inv.advance(0.5)
	while _sweep():
		pass


## Статическая проверка данных дела: ссылки, тексты, выводы, вердикт.
func _check_data(level_id: String) -> void:
	var d: Dictionary = _inv().data
	var tag: String = level_id + ": "
	check(d.has("verdict") and d["verdict"]["motives"].size() >= 3 and d["verdict"]["methods"].size() >= 3, tag + "мотив и способ в вердикте")
	check(d["suspects"].has(d["culprit"]), tag + "виновник среди подозреваемых")
	for id: String in d["key_clues"]:
		check(d["clues"].has(id), tag + "ключевая улика описана: " + id)
	for x: Dictionary in d.get("deductions", []):
		check(d["clues"].has(x["result"]), tag + "вывод описан: " + str(x["result"]))
		for id: String in x["a"] + x["b"]:
			check(d["clues"].has(id), tag + "улика вывода описана: " + id)
	for id: String in d["clues"]:
		var c: Dictionary = d["clues"][id]
		check(str(c.get("title", "")) != "" and str(c.get("text", "")) != "", tag + "текст улики " + id)
		check(not "страниц" in str(c["text"]) or not "подпис" in str(c["text"]), tag + "нет сюжета первого дела в " + id)
	var against: int = 0
	for id: String in d["key_clues"]:
		if d["culprit"] in d["clues"][id].get("points_to", []):
			against += 1
	check(against >= 3, tag + "≥3 ключевых улик против виновника (%d)" % against)


func _play(level_id: String, seed_value: int) -> void:
	await _start_level(level_id, seed_value)
	var inv: InvestigationManager = _inv()
	_check_data(level_id)
	check(inv.data.get("murders", {}).get("victim_pool", []).is_empty(), level_id + ": в туннелях не убивают (если не задумано)")
	_solve_all()
	var d: Dictionary = inv.data
	var missing: Array = d["key_clues"].filter(func(id: String) -> bool: return not inv.evidence.has(id))
	check(missing.is_empty(), "%s/%d: все ключевые улики достижимы, не найдены: %s" % [level_id, seed_value, missing])
	var against: Array = d["key_clues"].filter(func(id: String) -> bool: return inv.evidence.has(id) and d["culprit"] in d["clues"][id].get("points_to", []))
	print("  %s/%d: найдено %d улик, ключевых %d/%d, против виновника %d, событий %s" % [level_id, seed_value, inv.evidence.found.size(), inv.evidence.key_found_count(), d["key_clues"].size(), against.size(), inv.story.done])
	var deductions: Array = against.filter(func(id: String) -> bool: return d["clues"][id]["type"] == "contradiction")
	check(against.size() >= 3 and deductions.size() >= 1, "%s: связанная цепочка против виновника (%d улик, %d выводов)" % [level_id, against.size(), deductions.size()])
	# Повторные туннели и события не срабатывают второй раз.
	var fired: int = inv.story.done.size()
	inv.advance(0.0)
	check_eq(inv.story.done.size(), fired, level_id + ": события не повторяются")
	# Сохранение / загрузка посреди дела.
	var snap: Dictionary = inv.snapshot()
	var found: int = inv.evidence.found.size()
	inv.restore(JSON.parse_string(JSON.stringify(snap)))
	check_eq(inv.evidence.found.size(), found, level_id + ": загрузка сохраняет улики")
	check_eq(inv.story.done.size(), fired, level_id + ": загрузка сохраняет события")
	inv.clock = inv.start_time + 10.0  # решатель шёл до конца; обвинение — посреди дела
	# Верное обвинение с верным мотивом и способом.
	var vd: Dictionary = d["verdict"]
	var r: Dictionary = inv.accuse(d["culprit"], against.slice(0, 3), "", int(vd["motive"]), int(vd["method"]))
	check(r["correct"] and r.get("strong", false) and inv.verdict_ok, level_id + ": верное обвинение с мотивом и способом")
	game.queue_free()
	game = null
	await wait_frames(2)


func test_levels_solvable() -> void:
	for level_id: String in AUTHORED:
		if Db.level(level_id).get("case", "gen") == "gen":
			continue
		await _play(level_id, 7)
		await _play(level_id, 1234)


func test_levels_timeout() -> void:
	for level_id: String in AUTHORED:
		if Db.level(level_id).get("case", "gen") == "gen":
			continue
		await _start_level(level_id, 3)
		var res: Array = []
		# Подсказки: три ступени для одной цели, тексты есть, рейтинг снижается.
		var levels: Array = []
		for i in 3:
			var h: Dictionary = _inv().take_hint()
			check(str(h.get("text", "")).length() > 10, "%s: подсказка %d с текстом" % [level_id, i + 1])
			levels.append(int(h["level"]))
		check_eq(levels, [1, 2, 3], level_id + ": подсказки становятся точнее")
		check(_inv().compute_stars(true) <= 1, level_id + ": 3 подсказки снижают рейтинг")
		_inv().finished.connect(func(x: Dictionary) -> void: res.append(x))
		_inv().advance(21.0)
		check(res.size() == 1 and res[0]["outcome"] == "timeout" and int(res[0]["stars"]) == 0, level_id + ": время вышло — поражение")
		game.queue_free()
		game = null
		await wait_frames(2)


func test_levels_wrong_accusation() -> void:
	for level_id: String in AUTHORED:
		if Db.level(level_id).get("case", "gen") == "gen":
			continue
		await _start_level(level_id, 5)
		var inv: InvestigationManager = _inv()
		var d: Dictionary = inv.data
		var res: Array = []
		inv.finished.connect(func(x: Dictionary) -> void: res.append(x))
		var wrong: String = d["suspects"].filter(func(s: String) -> bool: return s != d["culprit"])[0]
		var r: Dictionary = inv.accuse(wrong, [], "", 0, 0)
		check(not r["correct"] and inv.mistakes == 1, level_id + ": неверное обвинение засчитано ошибкой")
		if inv.max_mistakes() > 1:
			check(not inv.ended, level_id + ": после первой ошибки дело продолжается")
			check(inv.dialogue_ctx(wrong)["wrong"], level_id + ": обвинённый помнит ошибку (реплика после обвинения)")
		else:
			check(inv.ended and res.size() == 1 and res[0]["outcome"] == "mistakes" and int(res[0]["stars"]) == 0, level_id + ": права на ошибку нет — поражение")
		game.queue_free()
		game = null
		await wait_frames(2)


## Продолжение авторского дела после выхода: события, предметы из событий, состояния NPC,
## осмотренные объекты и время восстанавливаются, события не повторяются.
func test_levels_resume_after_exit() -> void:
	SaveManager.enabled = true
	SaveManager.save_path = "user://test_resume.json"
	# Дело 2: пузырёк, выброшенный в первом туннеле.
	await _start_level("level_02", 9)
	var inv: InvestigationManager = _inv()
	inv.advance(float(inv.murders.murders[0]["t"]["tunnel_out"]) - inv.clock + 0.1)
	await wait_frames(2)
	check(game.world_items.has("obj_l2_vial"), "дело 2: пузырёк появился после туннеля")
	inv.mark_opened("obj_l2_cart")
	game.autosave()
	var clock: float = inv.clock
	var done: Array = inv.story.done.duplicate()
	game.queue_free()
	game = null
	await wait_frames(2)
	SaveManager.load_game()
	SaveManager.pending_level = "level_02"
	SaveManager.pending_case = "level_02"
	SaveManager.pending_resume = true
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await wait_frames(2)
	game.ui.close_all()
	inv = _inv()
	check(game.world_items.has("obj_l2_vial"), "дело 2: пузырёк на месте после загрузки")
	check(absf(inv.clock - clock) < 0.05, "дело 2: время восстановлено")
	check_eq(inv.story.done, done, "дело 2: события восстановлены")
	check("obj_l2_cart" in inv.opened, "дело 2: осмотренные объекты восстановлены")
	inv.advance(0.2)
	check_eq(inv.story.done.size(), done.size(), "дело 2: события не повторяются после загрузки")
	game.queue_free()
	game = null
	await wait_frames(2)
	# Дело 4: спасённая Вера остаётся спасённой.
	SaveManager.prepare_level("level_04")
	SaveManager.pending_seed = 9
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await wait_frames(2)
	game.ui.close_all()
	check(not game.npcs["vera"].visible, "дело 4: Вера пропала")
	_inv().give("p_l4_vera_found")
	await wait_frames(2)
	check(game.npcs["vera"].visible and _inv().state_of("vera") == "rescued", "дело 4: Вера спасена")
	game.autosave()
	game.queue_free()
	game = null
	await wait_frames(2)
	SaveManager.load_game()
	SaveManager.pending_level = "level_04"
	SaveManager.pending_case = "level_04"
	SaveManager.pending_resume = true
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await wait_frames(2)
	check(game.npcs["vera"].visible and _inv().state_of("vera") == "rescued", "дело 4: после загрузки Вера на месте")
	game.queue_free()
	game = null
	await wait_frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_resume.json"))
	SaveManager.enabled = false
	SaveManager.save_path = SaveManager.SAVE_PATH
