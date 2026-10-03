class_name PlayerController
extends CharacterBody2D
## Детектив: плавное движение в 4 направлениях (клавиатура или виртуальный джойстик),
## столкновения со стенами, мебелью и пассажирами, выбор объекта для взаимодействия,
## особые анимации (осмотр, запись, находка, задержание) и запись следа для камер.

signal target_changed(target: Interactable)

const SPEED: float = 84.0
const ACCEL: float = 900.0
const FRICTION: float = 1100.0
const STEP_INTERVAL: float = 0.32
const TRACK_INTERVAL: float = 0.5   # секунд между записями следа

## Вектор с джойстика HUD (длина до 1).
var touch_vector: Vector2 = Vector2.ZERO
var input_enabled: bool = true
var facing: String = "down"
var target: Interactable = null
## Минута дела — для записи следа (выставляет Game).
var clock_minute: float = 0.0
var track: Array = []  # [минута, Vector2, facing]

var sprite: CharacterSprite
var _shadow: Sprite2D
var _action_time: float = 0.0
var _step_timer: float = 0.0
var _step_flip: int = 0
var _track_timer: float = 0.0
var _lens: Sprite2D


func _ready() -> void:
	add_to_group(&"player")
	add_to_group(&"door_users")
	collision_layer = 2
	collision_mask = 1 | 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 6)
	shape.shape = rect
	shape.position = Vector2(0, -3)
	add_child(shape)
	_shadow = Sprite2D.new()
	_shadow.texture = CharacterSprite.shadow_texture()
	_shadow.position = Vector2(0, -1)
	add_child(_shadow)
	sprite = CharacterSprite.new()
	sprite.setup(ProgressionManager.outfit())
	add_child(sprite)
	sprite.animation_finished.connect(_on_action_finished)


func set_outfit(sheet: String) -> void:
	sprite.setup(sheet)


func is_busy() -> bool:
	return _action_time > 0.0


## Проиграть особую анимацию; на её время управление блокируется.
func play_action(anim: String, duration: float = 0.6) -> void:
	if sprite.play_action(anim):
		_action_time = duration
		velocity = Vector2.ZERO


func _on_action_finished() -> void:
	if _action_time > 0.0:
		_action_time = 0.0


func read_input() -> Vector2:
	var v := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if touch_vector.length() > 0.12:
		v = touch_vector
	return v.limit_length(1.0)


func _physics_process(delta: float) -> void:
	if _action_time > 0.0:
		_action_time -= delta
		if _action_time <= 0.0:
			sprite.play_state("idle", facing)
	var dir: Vector2 = read_input() if input_enabled and _action_time <= 0.0 else Vector2.ZERO
	if dir.length() > 0.05:
		velocity = velocity.move_toward(dir * SPEED, ACCEL * delta)
		facing = CaseTimeline.facing_for(dir)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move_and_slide()
	if _action_time <= 0.0:
		var moving: bool = velocity.length() > 8.0
		sprite.play_state("walk" if moving else "idle", facing)
		sprite.speed_scale = clampf(velocity.length() / SPEED, 0.6, 1.2) if moving else 1.0
		if moving:
			_step_timer -= delta
			if _step_timer <= 0.0:
				_step_timer = STEP_INTERVAL
				_step_flip = 1 - _step_flip
				AudioManager.play_sfx("step_%d" % _step_flip, -16.0, randf_range(0.9, 1.1))
	_update_target()
	_track_timer -= delta
	if _track_timer <= 0.0:
		_track_timer = TRACK_INTERVAL
		track.append([clock_minute, global_position, facing])


func _update_target() -> void:
	var best: Interactable = null
	var best_score: float = INF
	var fwd: Vector2 = {"down": Vector2.DOWN, "up": Vector2.UP, "left": Vector2.LEFT, "right": Vector2.RIGHT}[facing]
	var feet: Vector2 = global_position + Vector2(0, -6)
	for node in get_tree().get_nodes_in_group(&"interactables"):
		var it := node as Interactable
		if it == null or not it.enabled or not it.is_visible_in_tree():
			continue
		var d: Vector2 = it.interact_position() - feet
		var dist: float = d.length()
		if dist > it.radius + 10.0:
			continue
		var facing_bonus: float = d.normalized().dot(fwd) if dist > 1.0 else 1.0
		if facing_bonus < -0.35 and dist > 14.0:
			continue
		var score: float = dist - facing_bonus * 10.0
		if score < best_score:
			best_score = score
			best = it
	if best != target:
		target = best
		target_changed.emit(target)


## Где был игрок в момент t (для записей камер). Пусто — следа ещё нет.
func track_at(t: float) -> Array:
	if track.is_empty() or t < float(track[0][0]):
		return []
	var lo: int = 0
	var hi: int = track.size() - 1
	while lo < hi:
		var mid: int = (lo + hi + 1) / 2
		if float(track[mid][0]) <= t:
			lo = mid
		else:
			hi = mid - 1
	return track[lo]


## Показать/спрятать светящуюся лупу над героем (режим лупы).
func set_lens_glow(on: bool) -> void:
	if on and _lens == null:
		_lens = Sprite2D.new()
		_lens.texture = Db.texture("ui/glow_cyan.png")
		_lens.scale = Vector2(1.6, 1.6)
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_lens.material = mat
		_lens.position = Vector2(0, -16)
		_lens.modulate = Color(0.6, 0.9, 1.0, 0.35)
		add_child(_lens)
	if _lens:
		_lens.visible = on
