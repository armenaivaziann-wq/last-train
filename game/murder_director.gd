class_name MurderDirector
extends RefCounted
## Убийства в туннелях. Сценарии — в данных дела (раздел "murders"): вагон, жертва, место
## убийцы, свидетели, улики, тело. Первое убийство постановочное, следующие — каждые
## 7–10 игровых минут с ограниченным случайным выбором из пула (без повторных жертв).
## Убийца и свидетели физически приходят на место по хронологии дела — камеры показывают
## это честно, а виновник не раскрывается автоматически.
##
## Стадии события (каждая срабатывает ровно один раз):
##   tunnel_in → flicker → kill (крик) → tunnel_out; discovered — когда игрок дошёл до места.

const TO_FLICKER: float = 0.08   # игровые минуты от въезда в туннель
const TO_KILL: float = 0.15
const TUNNEL_LEN: float = 0.75
const WITNESS_DELAY: float = 0.12
const WITNESS_STAY: float = 3.0
const MURDERER_STAY: float = 0.08
const STAGES: PackedStringArray = ["tunnel_in", "flicker", "kill", "tunnel_out"]

var murders: Array = []       # [{index, id, scenario, victim, t: {stage: минута}, scene_pos}]
var excursions: Array = []    # [[npc, depart, spot, act, back]]
var seed_value: int = 0
var stages_done: Array = []   # "индекс:стадия"
var discovered: Array = []    # индексы найденных мест преступления
var murderer: String = ""


## Спланировать убийства дела. data — копия данных дела (сюда добавятся объекты,
## улики и камерные записи сценариев с подставленным временем).
func plan(data: Dictionary, layout: TrainLayout, timeline: CaseTimeline, start: float, arrival: float, rng_seed: int = -1) -> void:
	var cfg: Dictionary = data.get("murders", {})
	if cfg.is_empty():
		return
	seed_value = rng_seed if rng_seed >= 0 else randi() % 1000000
	murderer = str(cfg.get("murderer", data["culprit"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var scenarios: Dictionary = cfg["scenarios"]
	var pool: Array = cfg.get("pool", []).duplicate()
	var dead: Array = []
	var t: float = start + float(cfg.get("first_after", 3.0))
	var latest: float = arrival - float(cfg.get("min_left", 2.5))
	var interval: Array = cfg.get("interval", [7, 10])
	while t <= latest:
		var sid: String = ""
		if murders.is_empty() and cfg.has("staged"):
			sid = str(cfg["staged"])
		else:
			var options: Array = []
			for p in pool:
				var v: String = str(scenarios[p]["victim"])
				if not v in dead and v != "detective" and not v in data.get("suspects", []):
					options.append(p)
			if options.is_empty():
				break
			sid = str(options[rng.randi_range(0, options.size() - 1)])
			pool.erase(sid)
		var sc: Dictionary = scenarios[sid]
		dead.append(str(sc["victim"]))
		var m: Dictionary = {"index": murders.size(), "id": sid, "scenario": sc, "victim": str(sc["victim"]),
			"t": {"tunnel_in": t, "flicker": t + TO_FLICKER, "kill": t + TO_KILL, "tunnel_out": t + TUNNEL_LEN},
			"scene_pos": Vector2(layout.offsets[sc["carriage"]] + float(sc["body"][0]), float(sc["body"][1]))}
		murders.append(m)
		_route_people(m, timeline)
		_inject_data(m, data)
		t += rng.randf_range(float(interval[0]), float(interval[1]))


## Убийца приходит к жертве ровно к моменту убийства, свидетели сбегаются после крика.
func _route_people(m: Dictionary, timeline: CaseTimeline) -> void:
	var sc: Dictionary = m["scenario"]
	var kill: float = m["t"]["kill"]
	var spot: String = str(sc["murderer_spot"])
	var depart: float = kill - timeline.travel_minutes(murderer, kill - 0.5, spot) - 0.02
	depart = kill - timeline.travel_minutes(murderer, depart, spot) - 0.02
	_excursion([murderer, depart, spot, "hide_evidence", kill + MURDERER_STAY], timeline)
	for w: Dictionary in sc.get("witnesses", []):
		_excursion([str(w["npc"]), kill + WITNESS_DELAY, str(w["spot"]), "shocked", kill + WITNESS_STAY], timeline)


func _excursion(e: Array, timeline: CaseTimeline) -> void:
	excursions.append(e)
	timeline.add_excursion(e[0], e[1], e[2], e[3], e[4])


## Повторно проложить вылазки NPC после смены его расписания (например, при усилении).
func reapply_after(npc: String, t: float, timeline: CaseTimeline) -> void:
	for e: Array in excursions:
		if e[0] == npc and float(e[1]) > t:
			timeline.add_excursion(e[0], e[1], e[2], e[3], e[4])


func _fill(text: String, m: Dictionary) -> String:
	return text.replace("{time}", Db.format_time(m["t"]["kill"])).replace("{where}", str(m["scenario"]["where"]))


func _inject_data(m: Dictionary, data: Dictionary) -> void:
	var sc: Dictionary = m["scenario"]
	var ids: Array = [sc["scene_clue"], sc.get("camera_clue", "")]
	var bo: Dictionary = sc["body_object"]
	ids.append(bo.get("on_open", ""))
	for h: Dictionary in bo.get("hotspots", []):
		ids.append(h["clue"])
	for it: Dictionary in sc.get("items", []):
		ids.append(it.get("on_open", ""))
	for w: Dictionary in sc.get("witnesses", []):
		for t: Dictionary in data["dialogues"].get(w["npc"], {}).get("topics", []):
			if sc["scene_clue"] in t.get("requires", []):
				ids.append_array(t.get("gives", []))
	for id in ids:
		if data["clues"].has(id):
			var c: Dictionary = data["clues"][id]
			c["title"] = _fill(str(c["title"]), m)
			c["text"] = _fill(str(c["text"]), m)
			if c.has("time"):
				c["time"] = _fill(str(c["time"]), m)
	var body: Dictionary = bo.duplicate(true)
	body["kind"] = "document"
	var fields: Array = []
	for f: Array in body.get("fields", []):
		fields.append([f[0], _fill(str(f[1]), m)])
	body["fields"] = fields
	data["objects"][body_object_id(m)] = body
	for it: Dictionary in sc.get("items", []):
		data["objects"][it["id"]] = {"title": it["title"], "kind": "item", "text": it["text"], "on_open": it["on_open"], "hotspots": []}
	if sc.has("camera_clue"):
		var k: float = m["t"]["kill"]
		data["camera_clues"].append({"id": sc["camera_clue"], "camera": sc["camera"], "npc": murderer,
			"windows": [[Db.format_time(k - 0.06, true), Db.format_time(k + 0.05, true)]]})


static func body_object_id(m: Dictionary) -> String:
	return "obj_%s_body" % m["id"]


## Стадии, время которых наступило (по порядку). Каждая отдаётся один раз.
func due(clock: float) -> Array:
	var out: Array = []
	for m: Dictionary in murders:
		for st in STAGES:
			var key: String = "%d:%s" % [m["index"], st]
			if not key in stages_done and clock >= float(m["t"][st]):
				stages_done.append(key)
				out.append([m, st])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[0]["t"][a[1]] < b[0]["t"][b[1]])
	return out


func stage_done(m: Dictionary, stage: String) -> bool:
	return "%d:%s" % [m["index"], stage] in stages_done


func killed() -> Array:
	return murders.filter(func(m: Dictionary) -> bool: return stage_done(m, "kill"))


## Мёртв ли персонаж в момент t (для живого мира и для записей камер).
func dead_at(npc: String, t: float) -> bool:
	for m: Dictionary in murders:
		if m["victim"] == npc and stage_done(m, "kill") and t >= float(m["t"]["kill"]):
			return true
	return false


func is_victim(npc: String) -> bool:
	for m: Dictionary in murders:
		if m["victim"] == npc:
			return true
	return false


func undiscovered() -> Array:
	return killed().filter(func(m: Dictionary) -> bool: return not int(m["index"]) in discovered)


func serialize() -> Dictionary:
	return {"seed": seed_value, "stages_done": stages_done, "discovered": discovered}


func restore(s: Dictionary) -> void:
	stages_done = s.get("stages_done", []).duplicate()
	discovered = []
	for i in s.get("discovered", []):
		discovered.append(int(i))
