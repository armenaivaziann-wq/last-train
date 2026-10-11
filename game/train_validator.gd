class_name TrainValidator
extends RefCounted
## Проверка геометрии состава поезда (для тестов и отладки): сетка проходимости с учётом
## коллизий вагонов и размера героя, обход в ширину от точки старта. Отвечает на вопросы:
##   • соединены ли вагоны (через двери торцов можно пройти во все вагоны);
##   • можно ли подойти к каждому предмету, багажу и объекту на расстояние взаимодействия.

const CELL: float = 2.0
const H: float = 208.0
const HALF := Vector2(5.0, 3.0)   # половина коллайдера героя (10×6)
const REACH_SLACK: float = 8.0    # герой должен подойти ближе, чем радиус + 10 (запас)

var layout: TrainLayout
var cols: int
var rows: int
var blocked: PackedByteArray
var seen: PackedByteArray


func _init(train_layout: TrainLayout) -> void:
	layout = train_layout
	cols = int(ceil(layout.width / CELL))
	rows = int(ceil(H / CELL))
	blocked = PackedByteArray()
	blocked.resize(cols * rows)
	for cid in layout.carriage_ids:
		var x0: float = layout.offsets[cid]
		for r: Array in Db.layout(cid).get("colliders", []):
			_block(Rect2(x0 + float(r[0]), float(r[1]), float(r[2]), float(r[3])).grow_individual(HALF.x, HALF.y, HALF.x, HALF.y))
	# Внешние торцы состава закрыты (первая дверь слева, последняя справа).
	_block(Rect2(-20, 0, 24, H))
	_block(Rect2(layout.width - 4, 0, 24, H))


func _block(r: Rect2) -> void:
	var cx0: int = clampi(int(floor(r.position.x / CELL)), 0, cols - 1)
	var cx1: int = clampi(int(ceil(r.end.x / CELL)), 0, cols)
	var cy0: int = clampi(int(floor(r.position.y / CELL)), 0, rows - 1)
	var cy1: int = clampi(int(ceil(r.end.y / CELL)), 0, rows)
	for y in range(cy0, cy1):
		for x in range(cx0, cx1):
			blocked[y * cols + x] = 1


## Обход от точки (в координатах поезда). Возвращает число достижимых клеток.
func flood(from: Vector2) -> int:
	seen = PackedByteArray()
	seen.resize(cols * rows)
	var sx: int = int(from.x / CELL)
	var sy: int = int(from.y / CELL)
	if sx < 0 or sy < 0 or sx >= cols or sy >= rows or blocked[sy * cols + sx]:
		return 0
	var queue: PackedInt32Array = [sy * cols + sx]
	seen[sy * cols + sx] = 1
	var head: int = 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var x: int = i % cols
		var y: int = i / cols
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
				continue
			var j: int = ny * cols + nx
			if seen[j] or blocked[j]:
				continue
			seen[j] = 1
			queue.append(j)
	return queue.size()


## Можно ли подойти к точке на расстояние reach (после flood).
func can_reach(p: Vector2, reach: float) -> bool:
	var r: int = int(ceil(reach / CELL))
	var cx: int = int(p.x / CELL)
	var cy: int = int(p.y / CELL)
	for y in range(maxi(0, cy - r), mini(rows, cy + r + 1)):
		for x in range(maxi(0, cx - r), mini(cols, cx + r + 1)):
			if seen[y * cols + x] and Vector2((x + 0.5) * CELL, (y + 0.5) * CELL).distance_to(p) <= reach:
				return true
	return false


## Есть ли достижимая клетка внутри вагона.
func carriage_reached(cid: String) -> bool:
	var x0: int = int(layout.offsets[cid] / CELL)
	var x1: int = int((layout.offsets[cid] + layout.widths[cid]) / CELL)
	for y in rows:
		for x in range(x0, mini(x1, cols)):
			if seen[y * cols + x]:
				return true
	return false


## Полная проверка дела: список проблем (пусто — всё в порядке).
static func problems(case_data: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var ids := PackedStringArray(case_data["carriages"])
	var tl := TrainLayout.build(ids)
	var v := TrainValidator.new(tl)
	var ps: Dictionary = case_data["player_start"]
	var start := Vector2(tl.offsets[ps["carriage"]] + float(ps["pos"][0]), float(ps["pos"][1]))
	if v.flood(start) == 0:
		out.append("точка старта героя в стене")
		return out
	for cid in ids:
		if not v.carriage_reached(cid):
			out.append("вагон %s недостижим" % cid)
	for cid in ids:
		for it: Dictionary in Db.layout(cid).get("interactables", []):
			var p := Vector2(tl.offsets[cid] + float(it["pos"][0]), float(it["pos"][1]))
			if not v.can_reach(p, float(it.get("radius", 26)) + 10.0 - REACH_SLACK):
				out.append("объект вагона %s недоступен" % it["id"])
	for it: Dictionary in case_data.get("extra_items", []):
		var p2 := Vector2(tl.offsets[it["carriage"]] + float(it["pos"][0]), float(it["pos"][1]) - (6.0 if it.get("tall", false) else 0.0))
		if not v.can_reach(p2, float(it.get("radius", 24)) + 10.0 - REACH_SLACK):
			out.append("предмет %s недоступен" % it["id"])
	for ev: Dictionary in case_data.get("story_events", []):
		for fx: Dictionary in ev.get("effects", []):
			if fx.get("type") == "item":
				var p3 := Vector2(tl.offsets[fx["carriage"]] + float(fx["pos"][0]), float(fx["pos"][1]))
				if not v.can_reach(p3, float(fx.get("radius", 24)) + 10.0 - REACH_SLACK):
					out.append("предмет события %s недоступен" % fx["id"])
	for l: Dictionary in case_data.get("shadow_ghost", {}).get("linger", []):
		var p4 := Vector2(tl.offsets[l["carriage"]] + float(l["pos"][0]), float(l["pos"][1]))
		if not v.can_reach(p4, 26.0 + 10.0 - REACH_SLACK):
			out.append("тень %s недоступна" % l["object"])
	for lw: Dictionary in case_data.get("luggage_world", []):
		if not tl.slots.has(lw["slot"]):
			out.append("нет места для багажа %s" % lw["slot"])
		elif not v.can_reach(tl.slots[lw["slot"]], 24.0 + 10.0 - REACH_SLACK):
			out.append("багаж %s недоступен" % lw["owner"])
	for npc: String in case_data.get("schedules", {}):
		for e: Array in case_data["schedules"][npc]:
			if not tl.spots.has(str(e[1])):
				out.append("точка %s (%s) не существует в составе" % [e[1], npc])
	var cam_ids: Dictionary = {}
	for cam in tl.cameras:
		if cam_ids.has(cam["id"]):
			out.append("повтор камеры %s" % cam["id"])
		cam_ids[cam["id"]] = true
	for cc: Dictionary in case_data.get("camera_clues", []):
		if not cam_ids.has(cc["camera"]):
			out.append("запись %s на камере %s, которой нет в составе" % [cc["id"], cc["camera"]])
	return out


## NPC не ходят сквозь стены и мебель: маршруты по хронологии дела проверяются по исходным
## коллизиям вагонов (без запаса на героя). Рядом с точками расписания (сиденья внутри
## скамей) пересечение допустимо.
static func npc_path_problems(case_data: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var tl := TrainLayout.build(PackedStringArray(case_data["carriages"]))
	var timeline := CaseTimeline.new(case_data, tl)
	var rects: Array[Rect2] = []
	for cid in tl.carriage_ids:
		for r: Array in Db.layout(cid).get("colliders", []):
			rects.append(Rect2(tl.offsets[cid] + float(r[0]) + 1.0, float(r[1]) + 1.0, float(r[2]) - 2.0, float(r[3]) - 2.0))
	var t0: float = Db.parse_time(str(case_data.get("history_start", "01:25")))
	var t1: float = Db.parse_time(str(case_data["arrival"]))
	for npc in timeline.npc_ids():
		var spots: Array[Vector2] = []
		for e: Array in case_data["schedules"].get(npc, []):
			if tl.spots.has(str(e[1])):
				spots.append(tl.spots[str(e[1])]["pos"])
		var t: float = t0
		var reported: bool = false
		while t <= t1 and not reported:
			var p: Vector2 = timeline.position_at(npc, t)
			var near: bool = spots.any(func(s: Vector2) -> bool: return s.distance_to(p) < 30.0)
			if not near:
				for r in rects:
					if r.has_point(p):
						out.append("%s проходит сквозь препятствие около %s (%s)" % [npc, Db.format_time(t), tl.carriage_at(p.x)])
						reported = true
						break
			t += 0.02
	return out
