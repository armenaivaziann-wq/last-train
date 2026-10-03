extends Node
## Долгосрочная прогрессия: вагоны, оборудование, косметика, бестиарий, коллекция пассажиров,
## архив дел, статистика, ежедневные/еженедельные задания, достижения и сезонные события.
## Улучшения открывают новые способы расследования, а не автоматическое раскрытие.

const DAILY_COUNT: int = 3


func _ready() -> void:
	Events.stat_added.connect(_on_stat)
	refresh_quests()


func _p() -> Dictionary:
	return SaveManager.profile


# --- вагоны ---------------------------------------------------------------------------------
func has_carriage(id: String) -> bool:
	return id in _p()["carriages"]


func carriage_unlock_check(id: String) -> String:
	## Пустая строка — можно открыть, иначе причина.
	var c: Dictionary = Db.prog_item("carriages", id)
	if c.is_empty() or has_carriage(id):
		return "Уже открыт"
	if EconomyManager.reputation() < int(c.get("reputation", 0)):
		return "Нужна репутация %d" % int(c.get("reputation", 0))
	if not EconomyManager.can_afford("coins", int(c.get("cost", 0))):
		return "Не хватает монет"
	return ""


func unlock_carriage(id: String) -> bool:
	if carriage_unlock_check(id) != "":
		return false
	var c: Dictionary = Db.prog_item("carriages", id)
	EconomyManager.spend("coins", int(c.get("cost", 0)))
	_p()["carriages"].append(id)
	SaveManager.save_game()
	Events.profile_changed.emit()
	return true


# --- оборудование --------------------------------------------------------------------------
func equipment_level(id: String) -> int:
	return int(_p()["equipment"].get(id, 0))


func equipment_cost(id: String) -> int:
	var e: Dictionary = Db.prog_item("equipment", id)
	var lvl: int = equipment_level(id)
	var costs: Array = e.get("costs", [])
	if lvl >= int(e.get("max", 1)) or lvl >= costs.size():
		return -1
	var cost: int = int(costs[lvl])
	if has_carriage("service"):
		cost = int(round(cost * 0.8))
	return cost


func upgrade_equipment(id: String) -> bool:
	var cost: int = equipment_cost(id)
	if cost < 0 or not EconomyManager.spend("coins", cost):
		return false
	_p()["equipment"][id] = equipment_level(id) + 1
	SaveManager.save_game()
	Events.profile_changed.emit()
	return true


# --- косметика -----------------------------------------------------------------------------
func owns_cosmetic(id: String) -> bool:
	return id in _p()["cosmetics"]["owned"]


func buy_cosmetic(id: String) -> bool:
	var item: Dictionary = Db.prog_item("cosmetics", id)
	if item.is_empty() or owns_cosmetic(id):
		return false
	if not EconomyManager.spend("crystals", int(item.get("cost", 0))):
		return false
	_p()["cosmetics"]["owned"].append(id)
	SaveManager.save_game()
	Events.profile_changed.emit()
	return true


func give_cosmetic(id: String) -> void:
	if id != "" and not owns_cosmetic(id):
		_p()["cosmetics"]["owned"].append(id)


func equip_cosmetic(id: String) -> void:
	var item: Dictionary = Db.prog_item("cosmetics", id)
	if item.is_empty() or not owns_cosmetic(id):
		return
	var slot: String = "outfit" if item.get("kind") == "outfit" else "lens"
	_p()["cosmetics"][slot] = id
	SaveManager.save_game()
	Events.profile_changed.emit()


func outfit() -> String:
	return str(_p()["cosmetics"].get("outfit", "detective"))


func lens_color() -> Color:
	var item: Dictionary = Db.prog_item("cosmetics", str(_p()["cosmetics"].get("lens", "lens_silver")))
	return Color(str(item.get("color", "#c9d2de")))


# --- коллекции -----------------------------------------------------------------------------
func meet(character_id: String) -> void:
	if character_id in _p()["met"] or character_id == "detective":
		return
	_p()["met"].append(character_id)
	Events.add_stat("met", 1)


func has_met(character_id: String) -> bool:
	return character_id in _p()["met"]


func record_monster(monster_id: String) -> bool:
	## true — монстр пойман впервые (новая запись бестиария).
	var b: Dictionary = _p()["bestiary"]
	var first: bool = not b.has(monster_id)
	b[monster_id] = int(b.get(monster_id, 0)) + 1
	Events.add_stat("caught_" + monster_id, 1)
	return first


func monster_caught(monster_id: String) -> int:
	return int(_p()["bestiary"].get(monster_id, 0))


func add_archive(entry: Dictionary) -> void:
	_p()["archive"].push_front(entry)
	if _p()["archive"].size() > 100:
		_p()["archive"].pop_back()


func case_solved_before(case_id: String) -> bool:
	for e: Dictionary in _p()["archive"]:
		if e.get("case_id") == case_id and e.get("solved", false):
			return true
	return false


func route_unlocked(route: Dictionary) -> bool:
	return EconomyManager.reputation() >= int(route.get("reputation", 0))


func stat(name: String) -> int:
	return int(_p()["stats"].get(name, 0))


# --- кампания -------------------------------------------------------------------------------
func _camp() -> Dictionary:
	return _p()["campaign"]


func level_number(level_id: String) -> int:
	return int(Db.level(level_id).get("number", 0))


func level_unlocked(level_id: String) -> bool:
	var n: int = level_number(level_id)
	return n > 0 and n <= int(_camp()["unlocked"])


func level_stars(level_id: String) -> int:
	return int(_camp()["stars"].get(level_id, 0))


func level_completed(level_id: String) -> bool:
	return level_stars(level_id) > 0


func level_best_time(level_id: String) -> float:
	return float(_camp()["best_time"].get(level_id, -1.0))


func total_stars() -> int:
	var n: int = 0
	for l: Dictionary in Db.levels():
		n += level_stars(l["id"])
	return n


## Записать итог попытки. Звёзды и награда за них начисляются один раз: повтор может
## улучшить рекорд, но платит только за новые звёзды. Успех сразу открывает следующее дело.
func record_level(level_id: String, solved: bool, stars: int, elapsed: float) -> Dictionary:
	var c: Dictionary = _camp()
	c["attempts"][level_id] = int(c["attempts"].get(level_id, 0)) + 1
	var out: Dictionary = {"new_stars": 0, "unlocked_next": "", "best": 0}
	if level_id == "daily":
		var day: String = Time.get_date_string_from_system()
		var dl: Dictionary = c["daily"]
		if dl.get("day", "") != day:
			dl["day"] = day
			dl["best_stars"] = 0
		out["new_stars"] = maxi(0, stars - int(dl["best_stars"]))
		dl["best_stars"] = maxi(int(dl["best_stars"]), stars)
		out["best"] = dl["best_stars"]
		return out
	if not solved:
		out["best"] = level_stars(level_id)
		return out
	var prev_rewarded: int = int(c["rewarded_stars"].get(level_id, 0))
	out["new_stars"] = maxi(0, stars - prev_rewarded)
	c["rewarded_stars"][level_id] = maxi(prev_rewarded, stars)
	c["stars"][level_id] = maxi(level_stars(level_id), stars)
	var bt: float = level_best_time(level_id)
	if bt < 0.0 or elapsed < bt:
		c["best_time"][level_id] = elapsed
	out["best"] = c["stars"][level_id]
	var n: int = level_number(level_id)
	if n >= int(c["unlocked"]) and not Db.next_level(level_id).is_empty():
		c["unlocked"] = n + 1
		out["unlocked_next"] = str(Db.next_level(level_id)["id"])
	if stars >= 3:
		Events.add_stat("three_stars")
	return out


## Коллекция маскировок: в чьём облике был пойман злодей.
func record_disguise(villain: String, character: String) -> void:
	var dg: Dictionary = _camp()["disguises"]
	if not dg.has(villain):
		dg[villain] = []
	if not character in dg[villain]:
		dg[villain].append(character)


func disguises(villain: String) -> Array:
	return _camp()["disguises"].get(villain, [])


# --- задания и достижения ------------------------------------------------------------------
func _day_key() -> String:
	return Time.get_date_string_from_system()


func _week_key() -> String:
	var days: int = int(Time.get_unix_time_from_system() / 86400.0)
	return "w%d" % int((days + 3) / 7)


func refresh_quests() -> void:
	var q: Dictionary = _p()["quests"]
	var day: String = _day_key()
	if q.get("day", "") != day:
		q["day"] = day
		var pool: Array = Db.prog_list("daily_pool").duplicate()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(day)
		var picked: Array = []
		while picked.size() < DAILY_COUNT and not pool.is_empty():
			var item: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
			picked.append({"id": item["id"], "progress": 0, "claimed": false})
		q["daily"] = picked
	var week: String = _week_key()
	if q.get("week", "") != week:
		q["week"] = week
		var weekly: Array = []
		for item: Dictionary in Db.prog_list("weekly"):
			weekly.append({"id": item["id"], "progress": 0, "claimed": false})
		q["weekly"] = weekly
	if not q.has("event_progress"):
		q["event_progress"] = {}


func _on_stat(stat_name: String, amount: int) -> void:
	var stats: Dictionary = _p()["stats"]
	stats[stat_name] = int(stats.get(stat_name, 0)) + amount
	refresh_quests()
	var q: Dictionary = _p()["quests"]
	for list_key: String in ["daily", "weekly"]:
		var defs: String = "daily_pool" if list_key == "daily" else "weekly"
		for entry: Dictionary in q[list_key]:
			var d: Dictionary = Db.prog_item(defs, entry["id"])
			if d.get("stat") == stat_name and not entry["claimed"]:
				var before: int = int(entry["progress"])
				entry["progress"] = mini(int(d["goal"]), before + amount)
				if before < int(d["goal"]) and int(entry["progress"]) >= int(d["goal"]):
					Events.notify("Задание выполнено: " + str(d["text"]), "quest")
	for ev: Dictionary in active_events():
		if ev["task"]["stat"] == stat_name:
			var ep: Dictionary = q["event_progress"]
			ep[ev["id"]] = int(ep.get(ev["id"], 0)) + amount
	for a: Dictionary in Db.prog_list("achievements"):
		if a["stat"] == stat_name and stat(stat_name) >= int(a["goal"]) and stat(stat_name) - amount < int(a["goal"]):
			Events.notify("Достижение: " + str(a["name"]), "medal")
	SaveManager.save_game()


func quest_entries(list_key: String) -> Array:
	refresh_quests()
	var defs: String = "daily_pool" if list_key == "daily" else "weekly"
	var out: Array = []
	for entry: Dictionary in _p()["quests"][list_key]:
		var d: Dictionary = Db.prog_item(defs, entry["id"])
		if d.is_empty():
			continue
		var full: Dictionary = d.duplicate()
		full["progress"] = entry["progress"]
		full["claimed"] = entry["claimed"]
		out.append(full)
	return out


func claim_quest(list_key: String, quest_id: String) -> bool:
	var defs: String = "daily_pool" if list_key == "daily" else "weekly"
	for entry: Dictionary in _p()["quests"][list_key]:
		if entry["id"] != quest_id or entry["claimed"]:
			continue
		var d: Dictionary = Db.prog_item(defs, quest_id)
		if int(entry["progress"]) < int(d["goal"]):
			return false
		entry["claimed"] = true
		EconomyManager.grant({"coins": int(d.get("coins", 0)), "crystals": int(d.get("crystals", 0))})
		Events.profile_changed.emit()
		return true
	return false


func achievement_claimed(id: String) -> bool:
	return id in _p()["quests"]["claimed_achievements"]


func claim_achievement(id: String) -> bool:
	var a: Dictionary = Db.prog_item("achievements", id)
	if a.is_empty() or achievement_claimed(id) or stat(str(a["stat"])) < int(a["goal"]):
		return false
	_p()["quests"]["claimed_achievements"].append(id)
	EconomyManager.grant({"crystals": int(a.get("crystals", 0))})
	Events.profile_changed.emit()
	return true


func active_events() -> Array:
	var today: String = _day_key()
	var out: Array = []
	for ev: Dictionary in Db.prog_list("events"):
		if today >= str(ev["from"]) and today <= str(ev["to"]):
			out.append(ev)
	return out


func event_progress(event_id: String) -> int:
	refresh_quests()
	return int(_p()["quests"]["event_progress"].get(event_id, 0))


func event_claimed(event_id: String) -> bool:
	return event_id in _p()["quests"]["claimed_events"]


func claim_event(event_id: String) -> bool:
	var ev: Dictionary = Db.prog_item("events", event_id)
	if ev.is_empty() or event_claimed(event_id) or event_progress(event_id) < int(ev["task"]["goal"]):
		return false
	_p()["quests"]["claimed_events"].append(event_id)
	give_cosmetic(str(ev.get("reward_cosmetic", "")))
	EconomyManager.grant({"crystals": int(ev.get("crystals", 0))})
	Events.profile_changed.emit()
	return true
