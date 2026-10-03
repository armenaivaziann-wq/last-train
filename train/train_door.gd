class_name TrainDoor
extends Node2D
## Раздвижная дверь в торце вагона: открывается сама, когда рядом игрок или NPC.
## Запертая дверь не открывается и горит красным индикатором.

const OPEN_DISTANCE_X: float = 40.0
const OPEN_DISTANCE_Y: float = 34.0
const FRAME_TIME: float = 0.06

@export var locked: bool = false
@export var locked_message: String = "Дверь заперта."

var _frames: Array[Texture2D] = []
var _open_amount: float = 0.0   # 0 — закрыта, 3 — открыта (номер кадра)
var _sprite: Sprite2D
var _shape: CollisionShape2D
var _led: Sprite2D
var _was_open: bool = false


func _ready() -> void:
	for i in 4:
		_frames.append(Db.texture("props/door_%d.png" % i))
	_sprite = Sprite2D.new()
	_sprite.texture = _frames[0]
	add_child(_sprite)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 48)
	_shape.shape = rect
	body.add_child(_shape)
	add_child(body)
	if locked:
		_led = Sprite2D.new()
		_led.texture = Db.texture("props/lock_led.png")
		_led.position = Vector2(0, -30)
		add_child(_led)
		var it := Interactable.new()
		it.interact_id = "door_locked"
		it.kind = Interactable.Kind.DOOR
		it.label = "Дверь"
		it.radius = 30.0
		it.needs_light = false
		it.set_meta("message", locked_message)
		add_child(it)


func is_open() -> bool:
	return _open_amount >= 2.5


func _physics_process(delta: float) -> void:
	var want_open: bool = false
	if not locked:
		for node in get_tree().get_nodes_in_group(&"door_users"):
			var n2d := node as Node2D
			if n2d == null or not n2d.visible:
				continue
			var d: Vector2 = n2d.global_position - global_position
			if absf(d.x) < OPEN_DISTANCE_X and absf(d.y) < OPEN_DISTANCE_Y:
				want_open = true
				break
	var target: float = 3.0 if want_open else 0.0
	_open_amount = move_toward(_open_amount, target, delta / FRAME_TIME)
	_sprite.texture = _frames[int(round(_open_amount))]
	_shape.disabled = _open_amount >= 1.5
	if is_open() and not _was_open:
		AudioManager.play_sfx("door_open", -10.0)
	_was_open = is_open()
	if _led:
		_led.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 300.0)
