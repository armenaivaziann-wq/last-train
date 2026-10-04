class_name NPCController
extends CharacterBody2D
## Пассажир. Положение и занятие берутся из хронологии дела (CaseTimeline) — NPC ходят,
## садятся, разговаривают, смотрят в окна и меняют вагоны по расписанию.
## Состояния: idle, walking, sitting, talking, suspicious, investigating, hiding_evidence, detained.

const ACT_STATE: Dictionary = {
	"talk": "talking", "check": "investigating", "investigate": "investigating", "shocked": "investigating",
	"hide": "suspicious", "nervous": "suspicious", "hide_evidence": "hiding_evidence",
}
const ACT_ICON: Dictionary = {
	"read": "read", "eat": "eat", "coffee": "eat", "violin": "music", "piano": "music", "cards": "cards",
	"photo": "photo", "repair": "repair", "sleep": "sleep", "talk": "talk", "write": "write", "wash": "wash",
	"window": "window", "nervous": "sweat", "shocked": "exclaim", "check": "ticket", "investigate": "look",
	"luggage": "suitcase", "hide": "dots", "hide_evidence": "dots", "wait": "dots",
}

var npc_id: String = ""
var state: String = "idle"
var act: String = "idle"
var facing: String = "down"
var talking_to: Node2D = null
var detained: bool = false
var dead: bool = false
## Чей облик сейчас у персонажа (перевёртыш носит чужие лица).
var look_id: String = ""
## Тень теневика: падает к лампе и дёргается при мигании.
var shadow_wrong: bool = false
## Состояние по ходу дела: calm / scared / sick / asleep / missing / rescued / hiding / suspicious.
var condition: String = "calm"
var _react_left: float = 0.0
var _react_pos: Vector2
## Сбой копирования (признак двойника): [мин, макс] секунд между вспышками, пусто — нет.
var glitch_every: Array = []

var sprite: CharacterSprite
var interactable: Interactable
var _shadow: Sprite2D
var _bubble: Sprite2D
var _bubble_icon: Sprite2D
var _bubble_phase: float
var _time: float = 0.0
var _glitch_timer: float = 0.0
var _glitch_left: float = 0.0
var _last_pos: Vector2


func setup(id: String) -> void:
	npc_id = id
	name = id.capitalize()
	add_to_group(&"npcs")
	add_to_group(&"door_users")
	collision_layer = 4
	collision_mask = 0
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
	sprite.setup(str(Db.character(id).get("sprite", id)))
	look_id = id
	add_child(sprite)
	interactable = Interactable.new()
	interactable.interact_id = id
	interactable.owner_id = id
	interactable.kind = Interactable.Kind.NPC
	interactable.label = "Поговорить"
	interactable.radius = 24.0
	interactable.needs_light = false
	interactable.position = Vector2(0, -8)
	add_child(interactable)
	_bubble = Sprite2D.new()
	_bubble.texture = Db.texture("ui/bubble.png")
	_bubble.position = Vector2(9, -46)
	_bubble.z_index = 5
	add_child(_bubble)
	_bubble_icon = Sprite2D.new()
	_bubble_icon.position = Vector2(0, -1)
	_bubble.add_child(_bubble_icon)
	_bubble.visible = false
	_bubble_phase = float(hash(id) % 600) / 100.0
	_glitch_timer = 8.0


## Применить состояние хронологии {pos, facing, moving, pose, act}.
func apply(s: Dictionary) -> void:
	if s.is_empty() or detained or dead:
		return
	global_position = s["pos"]
	act = str(s["act"])
	var moving: bool = bool(s["moving"])
	if talking_to and is_instance_valid(talking_to):
		facing = CaseTimeline.facing_for(talking_to.global_position - global_position)
		state = "talking"
		sprite.play_state("idle" if s["pose"] != "sit" else "sit", facing)
		return
	facing = str(s["facing"])
	if _react_left > 0.0 and not moving:
		facing = CaseTimeline.facing_for(_react_pos - global_position)
	if moving:
		state = "walking"
		sprite.play_state("walk", facing)
	elif s["pose"] == "sit":
		state = ACT_STATE.get(act, "sitting")
		sprite.play_state("sit", facing)
	else:
		state = ACT_STATE.get(act, "idle")
		sprite.play_state("talk" if act == "talk" and facing == "down" else "idle", facing)


## Погиб: персонаж исчезает из мира (его заменяет тело на месте преступления).
## Видимое состояние пассажира (болен — бледный и кашляет, спит, испуган, пропал).
func set_condition(state: String) -> void:
	condition = state
	var missing: bool = state == "missing"
	if not dead:
		visible = not missing
		interactable.enabled = not missing
	sprite.modulate = Color(0.82, 1.0, 0.78) if state == "sick" else Color.WHITE
	if state in ["scared", "asleep", "sick"]:
		_react_left = 0.0


## Силуэт в темноте: видны рост, шляпа и очертания, но не лицо.
func set_silhouette(on: bool) -> void:
	sprite.self_modulate = Color(0.06, 0.05, 0.12) if on else Color.WHITE
	_bubble.modulate.a = 0.0 if on else 1.0


func set_look(char_id: String) -> void:
	if char_id == look_id:
		return
	look_id = char_id
	sprite.setup(str(Db.character(char_id).get("sprite", char_id)))


func set_dead(on: bool) -> void:
	dead = on
	visible = not on
	interactable.enabled = not on
	_shadow.visible = not on


## Испуганная реакция на крик: смотрит в сторону звука, над головой «!».
func react(pos: Vector2, duration: float = 4.0) -> void:
	_react_pos = pos
	_react_left = duration


func set_detained(on: bool) -> void:
	detained = on
	if on:
		state = "detained"
		sprite.play_state("idle", "down")
		sprite.modulate = Color(0.75, 0.75, 1.0)
	else:
		sprite.modulate = Color.WHITE


func _process(delta: float) -> void:
	_time += delta
	# Облачко занятия появляется периодически (не у идущих и не во время разговора)
	_react_left = maxf(0.0, _react_left - delta)
	var reacting: bool = _react_left > 0.0 and not detained
	var cond_icon: String = {"sick": "sick", "asleep": "sleep", "scared": "sweat", "hiding": "dots"}.get(condition, "")
	var show_bubble: bool = reacting or (state != "walking" and talking_to == null and not detained \
		and (cond_icon != "" or (fmod(_time + _bubble_phase, 7.0) < 2.6 and ACT_ICON.has(act))))
	if cond_icon != "" and not reacting:
		show_bubble = show_bubble and fmod(_time + _bubble_phase, 3.0) < 2.2
	_bubble.visible = show_bubble
	if show_bubble:
		var icon_name: String = "exclaim" if reacting else (cond_icon if cond_icon != "" else ACT_ICON[act])
		_bubble_icon.texture = Db.texture("acts/%s.png" % icon_name)
		_bubble.position.y = -46 + (3 if state == "sitting" else 0) + round(sin(_time * 3.0))
	_update_glitch(delta)
	if shadow_wrong:
		var j: float = sin(_time * 23.0) * 1.5 if fmod(_time, 3.0) < 0.6 else 0.0
		_shadow.position = Vector2(7.0 + j, -5.0)
		_shadow.scale = Vector2(1.3, 0.8)


func _update_glitch(delta: float) -> void:
	if glitch_every.is_empty() or detained:
		return
	if _glitch_left > 0.0:
		_glitch_left -= delta
		if _glitch_left <= 0.0:
			sprite.modulate = Color.WHITE
			sprite.position = Vector2.ZERO
		return
	_glitch_timer -= delta
	if _glitch_timer <= 0.0:
		_glitch_timer = randf_range(float(glitch_every[0]), float(glitch_every[1]))
		_glitch_left = 0.14
		sprite.modulate = Color(0.85, 0.6, 1.4)
		sprite.position = Vector2(1, 0)


func display_name() -> String:
	return Db.char_name(npc_id)
