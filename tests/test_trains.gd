extends TestSuite
## Составы поездов: у каждой миссии свой состав, вагоны соединены, все улики, багаж и
## объекты достижимы героем, расписания и записи камер соответствуют геометрии.


func _cases() -> Array:
	var out: Array = []
	for l: Dictionary in Db.levels():
		out.append([l["id"], Db.resolve_case(Db.level_case_ref(l), 7)])
	return out


func test_every_level_has_unique_train() -> void:
	var seen: Dictionary = {}
	for pair: Array in _cases():
		var key: String = ",".join(PackedStringArray(pair[1]["carriages"]))
		check(not seen.has(key), "%s: состав %s уже у %s" % [pair[0], key, seen.get(key, "")])
		seen[key] = pair[0]


func test_carriages_differ_within_train() -> void:
	for pair: Array in _cases():
		var ids: Array = pair[1]["carriages"]
		var uniq: Dictionary = {}
		for c in ids:
			uniq[c] = true
		check_eq(uniq.size(), ids.size(), "%s: вагоны в составе не повторяются" % pair[0])
		for c in ids:
			check(not Db.layout(str(c)).is_empty(), "%s: есть разметка вагона %s" % [pair[0], c])


func test_trains_are_walkable() -> void:
	for pair: Array in _cases():
		for p: String in TrainValidator.problems(pair[1]):
			check(false, "%s: %s" % [pair[0], p])


func test_daily_trains_are_walkable() -> void:
	for v in ["black_cloak", "ghost", "witch"]:
		for p: String in TrainValidator.problems(Db.resolve_case("gen:" + v, 11)):
			check(false, "дело дня %s: %s" % [v, p])


func test_validator_catches_problems() -> void:
	var c: Dictionary = Db.resolve_case("level_02", 7)
	c["extra_items"].append({"id": "obj_in_wall", "carriage": c["carriages"][0], "pos": [300, 20], "sprite": "note"})
	c["schedules"]["agata"].append(["02:10", "no_such_spot", "idle"])
	var p: Array[String] = TrainValidator.problems(c)
	check(p.any(func(s: String) -> bool: return s.contains("obj_in_wall")), "предмет в стене обнаружен")
	check(p.any(func(s: String) -> bool: return s.contains("no_such_spot")), "несуществующая точка обнаружена")
	var c2: Dictionary = c.duplicate(true)
	c2["carriages"] = [c["carriages"][0], c["carriages"][2]]
	c2["extra_items"] = []
	check(TrainValidator.problems(c2).size() > 0, "разорванный состав (без точек расписания тамбура) обнаружен")
