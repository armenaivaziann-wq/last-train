class_name Hunter
extends Node2D
## Охотник: истинная форма злодея бродит по тёмному поезду и ищет героя.
## Бродит между точками коридора; заметив героя — идёт к нему по сетке проходимости
## (обходит мебель); потеряв — проверяет последнее место и снова бродит.
## Видит дальше, если у героя горит фонарь, и если герой бежит. Спрятавшегося не видит.

signal caught

const CATCH_DIST: float = 15.0
const SEARCH_TIME: float = 3.0

var nav: HuntNav
var player: PlayerController
var speed_wander: float = 38.0
var speed_chase: float = 66.0
var sight: float = 110.0
## Состояние: wander / chase / search.
var mode: String = "wander"
var _goal: Vector2
var _last_seen: Vector2
var _search_left: float = 0.0
var _field_timer: float = 0.0
var _field_target: Vector2 = Vector2.INF
var _rng := RandomNumberGenerator.new()
var _sprite: AnimatedSprite2D
var _shadow: Sprite2D
var _t: float = 0.0
var active: bool = true


func setup(hunt_nav: HuntNav, hero: PlayerController, monster: String, start: Vector2, def: Dictionary, seed_value: int) -> void:
	nav = hunt_nav
	player = hero
	position = start
	_rng.seed = seed_value
	speed_wander = float(def.get("speed_wander", speed_wander))
	speed_chase = float(def.get("speed", speed_chase)) * float(def.get("speed_mult", 1.0))
	sight = float(def.get("sight", sight))
	name = "Hunter"
	_shadow = Sprite2D.new()
	_shadow.texture = CharacterSprite.shadow_texture()
	_shadow.scale = Vector2(1.6, 1.4)
	_shadow.modulate = Color(0, 0, 0, 0.6)
	add_child(_shadow)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = Db.villain_frames(monster)
	_sprite.offset = Vector2(0, CharacterSprite.FOOT_OFFSET)
	_sprite.scale = Vector2(1.25, 1.25)
	_sprite.play("idle")
	add_child(_sprite)
	_pick_wander_goal()


## Видит ли охотник героя прямо сейчас.
func sees_player() -> bool:
	if player.in_hiding:
		return false
	var r: float = sight
	if player.flashlight.on:
		r += 70.0
	if player.velocity.length() > 40.0:
		r += 30.0
	return global_position.distance_to(player.global_position) <= r


func _physics_process(delta: float) -> void:
	if not active:
		return
	_t += delta
	_sprite.position.y = sin(_t * 3.0) * 1.5
	_sprite.modulate.a = 0.82 + 0.12 * sin(_t * 5.0)
	if sees_player():
		mode = "chase"
		_last_seen = player.global_position
	elif mode == "chase":
		mode = "search"
		_search_left = SEARCH_TIME
	var anim: StringName = &"menace" if mode == "chase" else &"idle"
	if _sprite.animation != anim:
		_sprite.play(anim)
	var target: Vector2
	var spd: float = speed_wander
	match mode:
		"chase":
			target = player.global_position
			spd = speed_chase
		"search":
			target = _last_seen
			spd = speed_chase * 0.8
			_search_left -= delta
			if _search_left <= 0.0 or global_position.distance_to(_last_seen) < 10.0:
				mode = "wander"
				_pick_wander_goal()
				target = _goal
		_:
			target = _goal
			if global_position.distance_to(_goal) < 12.0:
				_pick_wander_goal()
				target = _goal
	_field_timer -= delta
	if _field_timer <= 0.0 or target.distance_to(_field_target) > 24.0:
		_field_timer = 0.4
		_field_target = target
		nav.build_field(target)
	var step_to: Vector2 = nav.next_point(global_position, target)
	var dv: Vector2 = step_to - global_position
	if dv.length() > 0.5:
		global_position += dv.normalized() * minf(spd * delta, dv.length())
		_sprite.flip_h = dv.x > 0.0
	if mode == "chase" and not player.in_hiding and global_position.distance_to(player.global_position) <= CATCH_DIST:
		active = false
		caught.emit()


## Случайная точка коридора в пределах ±1,5 вагона (охотник обходит поезд).
func _pick_wander_goal() -> void:
	var w: float = nav.layout.width
	for _i in 12:
		var x: float = clampf(global_position.x + _rng.randf_range(-700.0, 700.0), 30.0, w - 30.0)
		var y: float = nav.layout.corridor_y + _rng.randf_range(-12.0, 16.0)
		var p := Vector2(x, y)
		if nav.is_free(p):
			_goal = p
			return
	_goal = Vector2(clampf(global_position.x, 30.0, w - 30.0), nav.layout.corridor_y)
