class_name MurderDirector
extends RefCounted
## Убийства в туннелях. Каждый въезд поезда в туннель (а туннели планирует только эта система —
## второго таймера нет) — одно событие: в темноте погибает случайный ЖИВОЙ пассажир из
## допустимых для дела (не герой, не уже погибший, не виновник и не защищённый сюжетный NPC).
## Если допустимых жертв не осталось — туннель проходит без убийства.
##
## Всё планируется заранее по seed попытки и проходит по тем же часам дела, поэтому:
##   • после загрузки сохранения выбор жертв тот же, а уже случившееся не повторяется;
##   • убийца и свидетели физически приходят на место по хронологии — камеры это показывают;
##   • улики создаются вместе с событием из его фактов: жертва, вагон, время, личная вещь,
##     волокна (зависят от злодея), следы туда, куда реально ушёл убийца, свидетели, запись.
##
## Стадии события (каждая срабатывает ровно один раз):
##   tunnel_in → flicker → kill (крик) → tunnel_out; discovered — игрок дошёл до тела.

const TO_FLICKER: float = 0.08   # игровые минуты от въезда в туннель
const TO_KILL: float = 0.15
const TUNNEL_LEN: float = 0.75
const WITNESS_DELAY: float = 0.12
const WITNESS_STAY: float = 3.0
const MURDERER_STAY: float = 0.08
const STAGES: PackedStringArray = ["warn", "tunnel_in", "flicker", "kill", "tunnel_out"]

## Волокна, которые злодей оставляет на жертве (по умолчанию — след одежды виновника).
const FIBERS: Dictionary = {
	"black_cloak": "чёрные плотные волокна от длинного плаща",
	"shadow": "тёмный, как сажа, налёт без единой нитки",
	"mirror": "мелкие стеклянные искры, как от разбитого зеркала",
	"mimic": "серый воск на ткани — тянется, как свечной, и пахнет ничем",
}

var murders: Array = []       # [{index, id, victim, carriage, t: {stage: минута}, scene_pos, ...}]
var excursions: Array = []    # [[npc, depart, spot, act, back]]
var seed_value: int = 0
var stages_done: Array = []   # "индекс:стадия"
var discovered: Array = []    # индексы найденных мест преступления
## Сорванные убийства: герой был рядом с жертвой, и убийца отступил (индексы).
var foiled: Array = []
var murderer: String = ""
var _layout: TrainLayout
var _timeline: CaseTimeline
var _cfg: Dictionary = {}


func plan(data: Dictionary, layout: TrainLayout, timeline: CaseTimeline, start: float, arrival: float, rng_seed: int = -1) -> void:
	var cfg: Dictionary = data.get("murders", {})
	if cfg.is_empty():
		return
	_layout = layout
	_timeline = timeline
	_cfg = cfg
	seed_value = rng_seed if rng_seed >= 0 else randi() % 1000000
	murderer = str(cfg.get("murderer", data["culprit"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pool: Array = victim_pool(data)
	var dead: Array = []
	var t: float = start + float(cfg.get("first_after", 3.0))
	var latest: float = arrival - float(cfg.get("min_left", 2.5))
	var interval: Array = cfg.get("interval", [7, 10])
	while t <= latest:
		var i: int = murders.size()
		var m: Dictionary = {"index": i, "id": "mk%d" % i, "prefix": "mk%d" % i, "victim": "",
			"t": {"tunnel_in": t, "flicker": t + TO_FLICKER, "kill": t + TO_KILL, "tunnel_out": t + TUNNEL_LEN}}
		var alive: Array = pool.filter(func(v: String) -> bool: return not v in dead)
		# Предупреждение «туннель близко, кто-то в опасности» — за warn_before минут до убийства.
		if float(cfg.get("warn_before", 0.0)) > 0.0:
			m["t"]["warn"] = maxf(start + 0.2, t + TO_KILL - float(cfg["warn_before"]))
		if not alive.is_empty():
			# Сначала те, кто в момент убийства не идёт по вагону (сидит или стоит).
			var still: Array = alive.filter(func(v: String) -> bool: return not timeline.state_at(v, t + TO_KILL)["moving"])
			var from: Array = still if not still.is_empty() else alive
			m["victim"] = str(from[rng.randi_range(0, from.size() - 1)])
			dead.append(m["victim"])
			_place(m)
			_route_people(m, dead)
			_inject(m, data)
		murders.append(m)
		t += rng.randf_range(float(interval[0]), float(interval[1]))


## Кто может стать жертвой: список дела или все пассажиры, кроме защищённых. Никогда —
## главный герой и виновник.
static func victim_pool(data: Dictionary) -> Array:
	var cfg: Dictionary = data.get("murders", {})
	var protected: Array = cfg.get("protected", [])
	var out: Array = []
	for v in cfg.get("victim_pool", data.get("schedules", {}).keys()):
		var id: String = str(v)
		if id != "detective" and id != str(data.get("culprit", "")) and not id in protected and data["schedules"].has(id):
			out.append(id)
	return out


func _place(m: Dictionary) -> void:
	var kill: float = m["t"]["kill"]
	var pos: Vector2 = _timeline.position_at(m["victim"], kill)
	var car: String = _layout.carriage_at(pos.x)
	var local := free_floor(car, Vector2(pos.x - _layout.offsets[car], pos.y + 8.0))
	m["carriage"] = car
	m["where"] = _layout.carriage_name(car)
	m["scene_pos"] = Vector2(_layout.offsets[car] + local.x, local.y)
	m["victim_spot"] = str(_timeline.state_at(m["victim"], kill)["spot"])


## Ближайшая свободная точка пола (не в мебели и не в стене) в локальных координатах вагона.
static func free_floor(carriage: String, local: Vector2) -> Vector2:
	var cols: Array = Db.layout(carriage)["colliders"]
	for r in range(0, 90, 4):
		for dir: Vector2 in [Vector2.ZERO, Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var p: Vector2 = local + dir * r
			if p.y < 66.0 or p.y > 184.0 or p.x < 14.0 or p.x > float(Db.layout(carriage)["size"][0]) - 14.0:
				continue
			var blocked: bool = false
			for c: Array in cols:
				if Rect2(float(c[0]) - 6, float(c[1]) - 4, float(c[2]) + 12, float(c[3]) + 8).has_point(p):
					blocked = true
					break
			if not blocked:
				return p.round()
	return Vector2(round(local.x), 166.0)


func _stand_spot_near(pos: Vector2, exclude: Array) -> String:
	var best: String = ""
	var bd: float = INF
	for sid: String in _layout.spots:
		if sid in exclude or _layout.spots[sid]["pose"] != "stand":
			continue
		var d: float = (_layout.spots[sid]["pos"] as Vector2).distance_to(pos)
		if d >= 10.0 and d < bd:
			bd = d
			best = sid
	return best


## Убийца приходит к жертве к моменту убийства; рядом стоящие пассажиры сбегаются на крик.
func _route_people(m: Dictionary, dead: Array) -> void:
	var kill: float = m["t"]["kill"]
	var spot: String = _stand_spot_near(m["scene_pos"], [m["victim_spot"]])
	m["murderer_spot"] = spot
	# "murderer_stays": убивает не сам человек, а его тварь (тень, отражение, голос, копия),
	# а он остаётся на месте — и у своих вещей.
	if not bool(_cfg.get("murderer_stays", false)):
		var depart: float = kill - _timeline.travel_minutes(murderer, kill - 0.5, spot) - 0.02
		depart = kill - _timeline.travel_minutes(murderer, depart, spot) - 0.02
		_excursion([murderer, depart, spot, "hide_evidence", kill + MURDERER_STAY])
	# Куда ушёл убийца — туда и ведут следы.
	m["escape_spot"] = str(_timeline.state_at(murderer, kill + MURDERER_STAY + 0.3)["spot"])
	# Свидетели — до двух ближайших живых пассажиров (не убийца, не жертва).
	var cands: Array = []
	for npc in _timeline.npc_ids():
		if npc == murderer or npc in dead:
			continue
		var d: float = _timeline.position_at(npc, kill).distance_to(m["scene_pos"])
		if d < 280.0:
			cands.append([d, npc])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var used: Array = [m["victim_spot"], spot]
	m["witnesses"] = []
	for c: Array in cands.slice(0, 2):
		var ws: String = _stand_spot_near(m["scene_pos"], used)
		if ws == "":
			continue
		used.append(ws)
		_excursion([c[1], kill + WITNESS_DELAY, ws, "shocked", kill + WITNESS_STAY])
		m["witnesses"].append(c[1])


func _excursion(e: Array) -> void:
	excursions.append(e)
	_timeline.add_excursion(e[0], e[1], e[2], e[3], e[4])


## Повторно проложить вылазки NPC после смены его расписания (например, при усилении).
func reapply_after(npc: String, t: float, timeline: CaseTimeline) -> void:
	for e: Array in excursions:
		if e[0] == npc and float(e[1]) > t:
			timeline.add_excursion(e[0], e[1], e[2], e[3], e[4])


func _g(id: String, m_form: String, f_form: String) -> String:
	return f_form if str(Db.character(id).get("gender", "m")) == "f" else m_form


## Улики события — только из его фактов и только те, что лежат в мире или даны свидетелями.
func _inject(m: Dictionary, data: Dictionary) -> void:
	var cfg: Dictionary = data["murders"]
	var pre: String = m["prefix"]
	var v: String = m["victim"]
	var vname: String = Db.char_name(v)
	var vch: Dictionary = Db.character(v)
	var tt: String = Db.format_time(m["t"]["kill"])
	var where: String = m["where"]
	var villain: String = str(data.get("monster", ""))
	var look: String = str(cfg.get("murderer_look", Db.character(murderer).get("look", "")))
	# Кого описывают свидетели: в авторских делах — примета, подходящая двоим (не имя).
	var wpoints: Array = cfg.get("witness_points", [murderer])
	var fibers: String = str(FIBERS.get(villain, Db.character(murderer).get("trace", "чужие волокна")))
	var escape_place: String = CaseGenerator.spot_direction(m["escape_spot"])
	var car: String = m["carriage"]
	var local: Vector2 = m["scene_pos"] - Vector2(_layout.offsets[car], 0)
	m["blood"] = [[local.x + 12, local.y + 9, 0], [local.x - 15, local.y - 3, 1]]
	var steps_local: Vector2 = free_floor(car, local + Vector2(30 if _layout.spots.get(m["escape_spot"], {}).get("pos", Vector2.ZERO).x >= m["scene_pos"].x else -30, -6))
	m["items"] = [{"id": "obj_%s_steps" % pre, "sprite": "footprints", "pos": [steps_local.x, steps_local.y], "label": "Осмотреть следы"}]
	var clues: Dictionary = data["clues"]
	var keys: Array = data["key_clues"]
	var dead_word: String = _g(v, "погиб", "погибла")
	clues[pre + "_scene"] = {"type": "physical", "title": "Убийство: " + vname,
		"text": "%s, %s. Во время туннеля %s %s (%s)." % [where, tt, dead_word, vname, str(vch.get("role", "")).to_lower()],
		"time": tt, "points_to": []}
	clues[pre + "_body"] = {"type": "physical", "title": "Осмотр тела: " + vname,
		"text": "%s лежит на полу (%s). Рядом — %s. На лице испуг: нападения не ждали." % [vname, where.to_lower(), vch.get("item", "личные вещи")],
		"time": tt, "points_to": []}
	clues[pre + "_fibers"] = {"type": "physical", "title": "Волокна на одежде: " + vname,
		"text": "На рукаве %s — %s." % [_g(v, "погибшего", "погибшей"), fibers], "points_to": []}
	clues[pre + "_steps"] = {"type": "physical", "title": "Следы от тела: " + vname,
		"text": "Свежие следы ведут от тела %s." % escape_place, "time": tt, "points_to": []}
	data["objects"][body_object_id(m)] = {"title": "Тело: " + vname, "kind": "document",
		"fields": [["Погиб" + _g(v, "ший", "шая"), "%s, %s" % [vname, str(vch.get("role", "")).to_lower()]], ["Время", tt], ["Вагон", where]],
		"text": "Рядом — %s." % vch.get("item", "личные вещи"), "on_open": pre + "_body",
		"hotspots": [{"id": "sleeve", "label": "Рукав одежды", "text": "На рукаве — %s." % fibers, "clue": pre + "_fibers"}]}
	data["objects"]["obj_%s_steps" % pre] = {"title": "Следы обуви", "kind": "item",
		"text": "Свежие следы в темноте вели от тела %s." % escape_place, "on_open": pre + "_steps", "hotspots": []}
	# Запись камеры: в туннеле камера вагона слепнет (помехи), поэтому на записи видно только,
	# кто был в вагоне ДО туннеля, — круг подозреваемых, а не готовый ответ.
	var cam_id: String = ""
	var area: float = INF
	for cam in _layout.cameras:
		var r: Rect2 = cam["rect"]
		if r.has_point(m["scene_pos"]) and r.get_area() < area:
			area = r.get_area()
			cam_id = str(cam["id"])
	m["camera"] = cam_id
	if cam_id != "":
		var rect: Rect2 = _layout.camera(cam_id)["rect"]
		var before: float = float(m["t"]["tunnel_in"]) - 0.05
		var present: Array = []
		for id: String in _timeline.npc_ids():
			if id != m["victim"] and id != "detective" and rect.has_point(_timeline.position_at(id, before)) and not murders.any(func(o: Dictionary) -> bool: return o["victim"] == id):
				present.append(id)
		if not present.is_empty():
			var names: PackedStringArray = []
			for id in present:
				names.append(Db.char_name(id))
			data["camera_clues"].append({"id": "c_" + pre, "camera": cam_id, "npc": "",
				"windows": [[Db.format_time(float(m["t"]["tunnel_in"]) - 0.4, true), Db.format_time(float(m["t"]["tunnel_in"]) - 0.02, true)]]})
			clues["c_" + pre] = {"type": "camera", "title": "К%s: перед туннелем рядом с %s" % [cam_id.substr(3), vname],
				"text": "Камера %s, %s: перед самым туннелем в кадре были %s и %s. Дальше — помехи: в туннеле камера ослепла." % [
					cam_id.substr(3), Db.format_time(float(m["t"]["tunnel_in"])), vname, ", ".join(names)],
				"time": Db.format_time(float(m["t"]["tunnel_in"])), "points_to": _camera_points(present, data)}
			keys.append("c_" + pre)
	# Если герой окажется рядом с жертвой, убийца отступит — герой заметит только примету.
	clues["s_%s_foiled" % pre] = {"type": "testimony", "title": "Убийца отступил: " + vname,
		"text": "Когда погас свет, к %s кто-то подкрался — %s — и отступил, увидев вас." % [vname, look],
		"time": tt, "points_to": wpoints}
	# Свидетели: личные реплики, открываются после обнаружения места.
	for w: String in m["witnesses"]:
		var wid: String = "%s_w_%s" % [pre, w]
		var line: String = "Я слышал%s крик, когда погас свет! Мимо пробежал кто-то %s — %s." % [_g(w, "", "а"), look, escape_place]
		clues[wid] = {"type": "testimony", "title": "Свидетель: " + Db.char_name(w),
			"text": "%s: «%s»" % [Db.char_name(w), line], "time": tt, "points_to": wpoints}
		keys.append(wid)
		data["dialogues"][w]["topics"].append({"id": "m_" + pre, "q": "Что вы видели, когда погас свет (%s)?" % vname,
			"a": [line], "gives": [wid], "requires": [pre + "_scene"]})
	# Выводы: связи с уликами дела, указанными в данных (links), — без готового ответа.
	var cn: String = Db.char_name(murderer)
	var links: Dictionary = cfg.get("links", {})
	var steps_b: Array = _expand(links.get("steps", []), pre)
	# Вывод «следы ведут к месту виновника» — только если убийца действительно ушёл к своему месту.
	var homes: Array = _expand(links.get("home_spots", []), pre)
	if not steps_b.is_empty() and m["escape_spot"] in homes:
		clues["x_%s_steps" % pre] = {"type": "contradiction", "title": "Куда ушёл убийца",
			"text": "Следы от тела ведут %s — и именно туда, по уликам, вернулся %s." % [escape_place, cn], "points_to": [murderer]}
		keys.append("x_%s_steps" % pre)
		data["deductions"].append({"result": "x_%s_steps" % pre, "a": [pre + "_steps"], "b": steps_b})
	var fib_b: Array = _expand(links.get("fibers", []), pre)
	if not fib_b.is_empty():
		clues["x_%s_fibers" % pre] = {"type": "contradiction", "title": "Волокна и одежда убийцы",
			"text": "%s на теле совпадают с тем, что известно об убийце: %s." % [fibers.capitalize(), look], "points_to": [murderer]}
		keys.append("x_%s_fibers" % pre)
		data["deductions"].append({"result": "x_%s_fibers" % pre, "a": [pre + "_fibers"], "b": fib_b})


## Кого «показывает» запись перед туннелем: подозреваемые в кадре. Если в кадре один
## виновник — запись никого не называет (подозреваемых должно быть хотя бы двое).
func _camera_points(present: Array, data: Dictionary) -> Array:
	var sus: Array = present.filter(func(id: String) -> bool: return id in data.get("suspects", []))
	return sus if sus.size() >= 2 or not murderer in sus else []


func _expand(ids: Array, pre: String) -> Array:
	var out: Array = []
	for id in ids:
		out.append(str(id).replace("{pre}", pre).replace("{culprit}", murderer))
	return out


static func body_object_id(m: Dictionary) -> String:
	return "obj_%s_body" % m["id"]


## Стадии, время которых наступило (по порядку). Каждая отдаётся один раз.
## У туннеля без жертвы стадии kill нет.
func due(clock: float) -> Array:
	var out: Array = []
	for m: Dictionary in murders:
		for st in STAGES:
			if not m["t"].has(st):
				continue
			if (st == "kill" or st == "warn") and m["victim"] == "":
				continue
			var key: String = "%d:%s" % [m["index"], st]
			if not key in stages_done and clock >= float(m["t"][st]):
				stages_done.append(key)
				out.append([m, st])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[0]["t"][a[1]] < b[0]["t"][b[1]])
	return out


func stage_done(m: Dictionary, stage: String) -> bool:
	return "%d:%s" % [m["index"], stage] in stages_done


func killed() -> Array:
	return murders.filter(func(m: Dictionary) -> bool: return m["victim"] != "" and stage_done(m, "kill") and not int(m["index"]) in foiled)


func is_foiled(m: Dictionary) -> bool:
	return int(m["index"]) in foiled


func foil(m: Dictionary) -> void:
	if not int(m["index"]) in foiled:
		foiled.append(int(m["index"]))


## Ближайшее ещё не случившееся убийство с жертвой (для предупреждения на экране) или {}.
func upcoming(clock: float) -> Dictionary:
	for m: Dictionary in murders:
		if m["victim"] != "" and not is_foiled(m) and float(m["t"]["kill"]) > clock and m["t"].has("warn") and clock >= float(m["t"]["warn"]):
			return m
	return {}


## Мёртв ли персонаж в момент t (для живого мира и для записей камер).
func dead_at(npc: String, t: float) -> bool:
	for m: Dictionary in murders:
		if m["victim"] == npc and stage_done(m, "kill") and t >= float(m["t"]["kill"]) and not is_foiled(m):
			return true
	return false


func is_victim(npc: String) -> bool:
	for m: Dictionary in murders:
		if m["victim"] == npc:
			return true
	return false


func undiscovered() -> Array:
	return killed().filter(func(m: Dictionary) -> bool: return not int(m["index"]) in discovered)


## Убийство, к которому относится улика (по префиксу события), или {}.
func murder_of_clue(id: String) -> Dictionary:
	for m: Dictionary in murders:
		var pre: String = m["prefix"]
		if id.begins_with(pre + "_") or id == "c_" + pre or id.begins_with("x_" + pre + "_"):
			return m
	return {}


func serialize() -> Dictionary:
	return {"seed": seed_value, "stages_done": stages_done, "discovered": discovered.duplicate(), "foiled": foiled.duplicate(),
		"victims": murders.map(func(m: Dictionary) -> String: return m["victim"])}


func restore(s: Dictionary) -> void:
	stages_done = s.get("stages_done", []).duplicate()
	discovered = []
	for i in s.get("discovered", []):
		discovered.append(int(i))
	foiled = []
	for i in s.get("foiled", []):
		foiled.append(int(i))
