class_name CaseBuilder
extends RefCounted
## Сборщик авторских дел кампании (data/cases/level_XX.json).
## Авторский файл описывает только своё: историю, роли и реплики пассажиров, улики, выводы,
## события. Общий поезд и распорядок берутся из базы ("extends": "_base"), а то, что должно
## совпадать с хронологией, вычисляется здесь:
##   • "excursions"   — куда и когда ходили люди (переносится в расписание дела);
##   • "auto_cameras" — улики-записи камер: окно записи считается по реальному маршруту,
##                      поэтому запись всегда показывает то, что в ней описано.
## Если запись не получилась (человека нет в кадре) — ошибка видна в тестах.

const STRIP_BASE: PackedStringArray = ["clues", "deductions", "key_clues", "truth", "camera_clues", "murders", "escalation", "glitch", "brief", "variants"]


## База + авторский файл (без вычисляемых частей).
static func extend(base: Dictionary, lvl: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	if lvl.get("neutral_base", true):
		_neutralize(out)
	for key: String in lvl:
		var v: Variant = lvl[key]
		match key:
			"extends", "neutral_base":
				continue
			"clues", "objects":
				if not out.has(key):
					out[key] = {}
				for k: String in v:
					out[key][k] = v[k]
			"documents", "luggage", "schedules":
				if not out.has(key):
					out[key] = {}
				for k: String in v:
					out[key][k] = (v[k] as Variant).duplicate(true) if v[k] is Dictionary or v[k] is Array else v[k]
			"dialogues":
				for npc: String in v:
					var d: Dictionary = v[npc]
					var cur: Dictionary = out["dialogues"].get(npc, {"greet": "...", "topics": []})
					for dk: String in d:
						cur[dk] = (d[dk] as Variant).duplicate(true) if d[dk] is Dictionary or d[dk] is Array else d[dk]
					out["dialogues"][npc] = cur
			_:
				out[key] = (v as Variant).duplicate(true) if v is Dictionary or v is Array else v
	# Состав дела ("cast"): в поезде едут только эти пассажиры (расписания — из файла дела).
	if lvl.has("cast"):
		var cast: Array = lvl["cast"]
		for npc: String in out["schedules"].keys():
			if not npc in cast:
				out["schedules"].erase(npc)
		for c: String in cast:
			if not out["schedules"].has(c):
				push_error("Дело %s: нет расписания для %s" % [lvl.get("id", "?"), c])
		if not lvl.has("suspects"):
			out["suspects"] = out["suspects"].filter(func(s: String) -> bool: return s in cast)
		var cars: Array = out["carriages"]
		out["luggage_world"] = out.get("luggage_world", []).filter(func(lw: Dictionary) -> bool:
			return lw["owner"] in cast and str(lw["slot"]).get_slice(":", 0) in cars)
	for k in ["clues", "objects", "deductions", "key_clues", "truth", "camera_clues", "extra_items", "events"]:
		if not out.has(k):
			out[k] = {} if k in ["clues", "objects"] else []
	return out


## Убрать из базы улики дела 1, оставив поезд, людей, их вещи и распорядок.
static func _neutralize(d: Dictionary) -> void:
	for k in STRIP_BASE:
		d.erase(k)
	d["clues"] = {}
	for npc: String in d.get("documents", {}):
		var doc: Dictionary = d["documents"][npc]
		doc.erase("on_open")
		doc.erase("gives")
		doc["hotspots"] = []
	for npc: String in d.get("luggage", {}):
		for it: Dictionary in d["luggage"][npc].get("items", []):
			it.erase("hotspot")
			it.erase("on_open")
		d["luggage"][npc]["items"] = d["luggage"][npc].get("items", []).filter(func(it: Dictionary) -> bool: return not it.has("requires_upgrade"))
	for oid: String in d.get("objects", {}):
		var o: Dictionary = d["objects"][oid]
		o.erase("on_open")
		o["hotspots"] = []
	for npc: String in d.get("dialogues", {}):
		d["dialogues"][npc]["topics"] = []
	var barks: Dictionary = d.get("barks", {})
	barks["agata"] = ["Чай кому?", "Ох, мои нервы...", "Билеты, пожалуйста."]
	barks["robert"] = ["Хм.", "Время — деньги.", "Не мешайте, я занят."]
	barks["nina"] = ["Ля... нет, си-бемоль.", "Надо повторить этюд.", "Ах, извините!"]
	d["wrong_reactions"] = {}
	d["events"] = d.get("events", []).filter(func(e: Dictionary) -> bool: return e.get("type") in ["rain_start", "station_approach"])


## Вычисляемые части: маршруты → расписание, записи камер → окна по хронологии.
static func finish(d: Dictionary) -> void:
	var layout := TrainLayout.build(PackedStringArray(d["carriages"]))
	var timeline := CaseTimeline.new(d, layout)
	for e: Dictionary in d.get("excursions", []):
		var at: float = Db.parse_time(str(e["at"]))
		var spot: String = str(e["spot"])
		var depart: float = at - timeline.travel_minutes(str(e["npc"]), at - 0.6, spot) - 0.05
		timeline.add_excursion(str(e["npc"]), depart, spot, str(e.get("act", "idle")), at + float(e.get("stay", 1.0)))
	for npc in timeline.npc_ids():
		var out: Array = []
		for en: Array in timeline.entries(npc):
			out.append([fmt(en[0]), en[1], en[2]])
		d["schedules"][npc] = out
	for c: Dictionary in d.get("auto_cameras", []):
		if c.has("window"):
			# Запись без человека в кадре (тень, свет): окно задано явно.
			d["camera_clues"].append({"id": c["id"], "camera": c["camera"], "npc": str(c.get("npc", "")), "windows": [c["window"]]})
			d["clues"][c["id"]] = {"type": "camera", "title": str(c["title"]).replace("{cam}", "К" + str(c["camera"]).substr(3)),
				"text": str(c["text"]).replace("{cam}", "К" + str(c["camera"]).substr(3)), "points_to": c.get("points_to", []),
				"time": Db.format_time(Db.parse_time(c["window"][0]))}
			if c.get("key", false) and not c["id"] in d["key_clues"]:
				d["key_clues"].append(c["id"])
			continue
		var at2: float = Db.parse_time(str(c["at"]))
		var npc2: String = str(c["npc"])
		var cam: String = str(c.get("camera", ""))
		if cam == "":
			cam = camera_at(layout, timeline.position_at(npc2, at2))
		var w: Array = window(layout, timeline, cam, npc2, at2, float(c.get("before", 0.4)), float(c.get("after", 0.8)))
		if w.is_empty():
			push_error("Запись %s: %s не в кадре %s около %s" % [c["id"], npc2, cam, c["at"]])
			continue
		d["camera_clues"].append({"id": c["id"], "camera": cam, "npc": npc2, "windows": [w]})
		var clue := {"type": "camera", "title": str(c["title"]).replace("{cam}", "К" + cam.substr(3)),
			"text": str(c["text"]).replace("{cam}", "К" + cam.substr(3)), "points_to": c.get("points_to", []),
			"time": Db.format_time(Db.parse_time(w[0]))}
		d["clues"][c["id"]] = clue
		if c.get("key", false) and not c["id"] in d["key_clues"]:
			d["key_clues"].append(c["id"])


static func fmt(t: float) -> String:
	var total: float = t * 60.0
	return "%02d:%02d:%05.2f" % [int(total / 3600.0), int(fmod(total, 3600.0) / 60.0), fmod(total, 60.0)]


static func camera_at(layout: TrainLayout, pos: Vector2) -> String:
	var best: String = ""
	var area: float = INF
	for cam in layout.cameras:
		var r: Rect2 = cam["rect"]
		if r.has_point(pos) and r.get_area() < area:
			area = r.get_area()
			best = str(cam["id"])
	return best


static func window(layout: TrainLayout, timeline: CaseTimeline, cam: String, npc: String, t: float, before: float, after: float) -> Array:
	if cam == "":
		return []
	var rect: Rect2 = layout.camera(cam)["rect"]
	for iv: Array in timeline.presence(npc, rect, t - before, t + after, 1.0 / 120.0):
		if iv[0] <= t + after and iv[1] >= t - before and iv[1] - iv[0] > 0.04:
			return [fmt(iv[0] + 0.01), fmt(iv[1] - 0.01)]
	return []
