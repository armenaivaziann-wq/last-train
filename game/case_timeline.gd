class_name CaseTimeline
extends RefCounted
## Хронология дела: где был каждый NPC в любой момент времени.
## Расписание задано в данных дела ([время, точка, занятие]); между точками NPC идёт по
## маршруту «точка → проход → коридор → проход → точка». Живые NPC и записи камер
## берут позиции отсюда, поэтому камеры всегда показывают реальные события дела.

const WALK_SPEED_PX_S: float = 46.0

var layout: TrainLayout
## Пикселей пути за игровую минуту (скорость ходьбы в игровом времени).
var px_per_min: float
var _entries: Dictionary = {}   # npc → Array[[t, spot, act]]
var _segments: Dictionary = {}  # npc → Array[Dictionary]


func _init(case_data: Dictionary, train_layout: TrainLayout) -> void:
	layout = train_layout
	px_per_min = WALK_SPEED_PX_S * float(case_data.get("seconds_per_minute", 30))
	var schedules: Dictionary = case_data.get("schedules", {})
	for npc: String in schedules:
		var list: Array = []
		for e: Array in schedules[npc]:
			if not layout.spots.has(str(e[1])):
				push_error("Расписание %s: нет точки %s" % [npc, e[1]])
				continue
			list.append([Db.parse_time(str(e[0])), str(e[1]), str(e[2]) if e.size() > 2 else "idle"])
		list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		_entries[npc] = list
		_rebuild(npc)


func npc_ids() -> Array:
	return _entries.keys()


func entries(npc: String) -> Array:
	return _entries.get(npc, [])


## Заменить расписание NPC начиная с момента t (усиление расследования, задержание).
func override_from(npc: String, t: float, spot: String, act: String) -> void:
	if not _entries.has(npc) or not layout.spots.has(spot):
		return
	var kept: Array = []
	for e: Array in _entries[npc]:
		if e[0] < t:
			kept.append(e)
	kept.append([t, spot, act])
	_entries[npc] = kept
	_rebuild(npc)


## Вылазка: в момент depart NPC идёт в spot, а в момент back возвращается туда, где был бы
## по исходному расписанию. Записи расписания внутри вылазки заменяются.
func add_excursion(npc: String, depart: float, spot: String, act: String, back: float) -> void:
	if not _entries.has(npc) or not layout.spots.has(spot) or back <= depart:
		return
	var ret: Dictionary = state_at(npc, back)
	var kept: Array = []
	for e: Array in _entries[npc]:
		if e[0] < depart or e[0] > back:
			kept.append(e)
	kept.append([depart, spot, act])
	kept.append([back, str(ret["spot"]), str(ret["act"]) if ret["act"] != "walk" else "idle"])
	kept.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_entries[npc] = kept
	_rebuild(npc)


## Сколько игровых минут NPC идёт из точки, где он находится в момент t, до точки spot.
func travel_minutes(npc: String, t: float, spot: String) -> float:
	var s: Dictionary = state_at(npc, t)
	if s.is_empty() or not layout.spots.has(spot):
		return 0.0
	var from_spot: Dictionary = {} if s["moving"] else layout.spots[s["spot"]]
	var path: PackedVector2Array = _route(s["pos"], from_spot, layout.spots[spot])
	var length: float = 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length / px_per_min


func _rebuild(npc: String) -> void:
	var segs: Array = []
	for e: Array in _entries[npc]:
		var t0: float = e[0]
		var spot: Dictionary = layout.spots[e[1]]
		var path := PackedVector2Array()
		if segs.is_empty():
			path.append(spot["pos"])
		else:
			var prev: Dictionary = segs[segs.size() - 1]
			var from_pos: Vector2 = _pos_on_segment(prev, t0)
			var from_spot: Dictionary = layout.spots[prev["spot"]] if t0 >= prev["t1"] else {}
			path = _route(from_pos, from_spot, spot)
		var cum := PackedFloat32Array([0.0])
		for i in range(1, path.size()):
			cum.append(cum[i - 1] + path[i - 1].distance_to(path[i]))
		var length: float = cum[cum.size() - 1]
		segs.append({"t0": t0, "t1": t0 + length / px_per_min, "path": path, "cum": cum,
			"spot": e[1], "act": e[2]})
	_segments[npc] = segs


func _route(from_pos: Vector2, from_spot: Dictionary, to_spot: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array([from_pos])
	var target: Vector2 = to_spot["pos"]
	if from_pos.distance_to(target) < 0.5:
		return pts
	var cy: float = layout.corridor_y
	if not from_spot.is_empty() and not is_nan(float(from_spot["via"])):
		pts.append(Vector2(float(from_spot["via"]), from_pos.y))
	var cur: Vector2 = pts[pts.size() - 1]
	var tvia: float = float(to_spot["via"])
	var end_x: float = target.x if is_nan(tvia) else tvia
	if absf(cur.y - cy) > 0.5:
		pts.append(Vector2(cur.x, cy))
	pts.append(Vector2(end_x, cy))
	pts.append(Vector2(end_x, target.y))
	if not is_nan(tvia):
		pts.append(target)
	var clean := PackedVector2Array([pts[0]])
	for i in range(1, pts.size()):
		if pts[i].distance_to(clean[clean.size() - 1]) > 0.25:
			clean.append(pts[i])
	return clean


func _pos_on_segment(seg: Dictionary, t: float) -> Vector2:
	var path: PackedVector2Array = seg["path"]
	if t >= seg["t1"] or path.size() == 1:
		return path[path.size() - 1]
	var d: float = maxf(0.0, (t - float(seg["t0"])) * px_per_min)
	var cum: PackedFloat32Array = seg["cum"]
	for i in range(1, path.size()):
		if d <= cum[i]:
			var seg_len: float = cum[i] - cum[i - 1]
			var k: float = 0.0 if seg_len <= 0.0 else (d - cum[i - 1]) / seg_len
			return path[i - 1].lerp(path[i], k)
	return path[path.size() - 1]


func _segment_at(npc: String, t: float) -> Dictionary:
	var segs: Array = _segments.get(npc, [])
	if segs.is_empty():
		return {}
	var found: Dictionary = segs[0]
	for s: Dictionary in segs:
		if s["t0"] <= t:
			found = s
		else:
			break
	return found


## Состояние NPC в момент t: {pos, facing, moving, pose, act, spot}.
func state_at(npc: String, t: float) -> Dictionary:
	var seg: Dictionary = _segment_at(npc, t)
	if seg.is_empty():
		return {}
	var spot: Dictionary = layout.spots[seg["spot"]]
	if t >= seg["t1"] or t < seg["t0"]:
		return {"pos": spot["pos"], "facing": spot["facing"], "moving": false,
			"pose": spot["pose"], "act": seg["act"], "spot": seg["spot"]}
	var pos: Vector2 = _pos_on_segment(seg, t)
	var ahead: Vector2 = _pos_on_segment(seg, minf(t + 0.004, seg["t1"]))
	return {"pos": pos, "facing": facing_for(ahead - pos), "moving": true,
		"pose": "stand", "act": "walk", "spot": seg["spot"]}


func position_at(npc: String, t: float) -> Vector2:
	var s: Dictionary = state_at(npc, t)
	return s.get("pos", Vector2.ZERO)


static func facing_for(dir: Vector2) -> String:
	if dir.length() < 0.001:
		return "down"
	if absf(dir.x) > absf(dir.y):
		return "right" if dir.x > 0 else "left"
	return "down" if dir.y > 0 else "up"


## Интервалы, когда NPC внутри прямоугольника (для меток движения на шкале камер).
func presence(npc: String, rect: Rect2, t_from: float, t_to: float, step_min: float = 1.0 / 30.0) -> Array:
	var out: Array = []
	var inside: bool = false
	var start: float = 0.0
	var t: float = t_from
	while t <= t_to:
		var now_in: bool = rect.has_point(position_at(npc, t))
		if now_in and not inside:
			start = t
		elif not now_in and inside:
			out.append([start, t])
		inside = now_in
		t += step_min
	if inside:
		out.append([start, t_to])
	return out
