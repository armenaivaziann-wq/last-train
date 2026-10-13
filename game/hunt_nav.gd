class_name HuntNav
extends RefCounted
## Грубая сетка проходимости поезда для охотника (клетка 8 px): мебель и стены из коллизий
## вагонов (с запасом на размер тела), внешние торцы закрыты, межвагонные двери проходимы.
## Поле расстояний строится обходом в ширину от цели; охотник идёт в соседнюю клетку
## с меньшим расстоянием — так он обходит мебель и не застревает в купе.

const CELL: float = 8.0
const H: float = 208.0
const HALF := Vector2(5.0, 3.0)

var layout: TrainLayout
var cols: int
var rows: int
var blocked: PackedByteArray
var dist: PackedInt32Array
var _target_cell: int = -1


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
	_block(Rect2(-20, 0, 24, H))
	_block(Rect2(layout.width - 4, 0, 24, H))


func _block(r: Rect2) -> void:
	# Клетка закрыта, только если её центр внутри препятствия (грубая сетка не должна
	# «заваривать» узкие проходы между полками).
	for y in rows:
		var cy: float = (y + 0.5) * CELL
		if cy < r.position.y or cy > r.end.y:
			continue
		for x in range(maxi(0, int(floor(r.position.x / CELL))), mini(cols, int(ceil(r.end.x / CELL)) + 1)):
			var cx: float = (x + 0.5) * CELL
			if cx >= r.position.x and cx <= r.end.x:
				blocked[y * cols + x] = 1


func cell_of(p: Vector2) -> int:
	var x: int = clampi(int(p.x / CELL), 0, cols - 1)
	var y: int = clampi(int(p.y / CELL), 0, rows - 1)
	return y * cols + x


func center(cell: int) -> Vector2:
	return Vector2((cell % cols + 0.5) * CELL, (cell / cols + 0.5) * CELL)


func is_free(p: Vector2) -> bool:
	return not blocked[cell_of(p)]


## Ближайшая свободная клетка к точке (точка могла попасть в «запас» у мебели).
func free_cell_near(p: Vector2) -> int:
	var c: int = cell_of(p)
	if not blocked[c]:
		return c
	var best: int = -1
	var bd: float = INF
	var cx: int = c % cols
	var cy: int = c / cols
	for y in range(maxi(0, cy - 4), mini(rows, cy + 5)):
		for x in range(maxi(0, cx - 4), mini(cols, cx + 5)):
			var j: int = y * cols + x
			if blocked[j]:
				continue
			var d: float = center(j).distance_squared_to(p)
			if d < bd:
				bd = d
				best = j
	return best


## Поле расстояний до цели (обход в ширину по 8 соседям).
func build_field(target: Vector2) -> void:
	var t: int = free_cell_near(target)
	_target_cell = t
	dist = PackedInt32Array()
	dist.resize(cols * rows)
	dist.fill(-1)
	if t < 0:
		return
	var queue: PackedInt32Array = [t]
	dist[t] = 0
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
			if dist[j] >= 0 or blocked[j]:
				continue
			dist[j] = dist[i] + 1
			queue.append(j)


## Следующая точка на пути к цели поля (или сама цель, если она рядом / недостижима).
func next_point(from: Vector2, target: Vector2) -> Vector2:
	var c: int = free_cell_near(from)
	if c < 0 or dist.is_empty() or dist[c] < 0:
		return target
	if dist[c] <= 1:
		return target
	var x: int = c % cols
	var y: int = c / cols
	var best: int = c
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
			continue
		var j: int = ny * cols + nx
		if dist[j] >= 0 and dist[j] < dist[best]:
			best = j
	return center(best)


## Достижима ли точка от цели поля (после build_field).
func reachable(p: Vector2) -> bool:
	var c: int = free_cell_near(p)
	return c >= 0 and not dist.is_empty() and dist[c] >= 0
