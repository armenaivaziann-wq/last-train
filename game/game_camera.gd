class_name GameCamera
extends Camera2D
## Камера строго сверху: мягко следует за детективом по длине поезда, по высоте держит
## вагон в кадре. Положение округляется до пикселя мира — пиксель-арт не «плывёт».

const ZOOM: float = 2.0
const FOLLOW_SPEED: float = 6.0
const TRAIN_CENTER_Y: float = 108.0

var target: Node2D
var left_limit: float = -60.0
var right_limit: float = 1400.0
## Временная точка фокуса (сцена задержания); null — следовать за target.
var focus_point: Variant = null
var _pos: Vector2


func _ready() -> void:
	zoom = Vector2(ZOOM, ZOOM)
	position_smoothing_enabled = false
	ignore_rotation = true


func snap_to_target() -> void:
	if target:
		_pos = _desired()
		global_position = _pos.round()


func _desired() -> Vector2:
	var p: Vector2 = focus_point if focus_point != null else target.global_position
	var half_w: float = get_viewport_rect().size.x / zoom.x / 2.0
	var x: float = p.x
	if right_limit - left_limit > half_w * 2.0:
		x = clampf(x, left_limit + half_w, right_limit - half_w)
	else:
		x = (left_limit + right_limit) / 2.0
	var y: float = TRAIN_CENTER_Y + clampf((p.y - TRAIN_CENTER_Y) * 0.25, -10.0, 10.0)
	return Vector2(x, y)


func _process(delta: float) -> void:
	if target == null:
		return
	_pos = _pos.lerp(_desired(), 1.0 - exp(-FOLLOW_SPEED * delta))
	global_position = _pos.round()
