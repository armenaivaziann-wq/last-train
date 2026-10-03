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
	if s.is_empty() or detained:
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
	if moving:
		state = "walking"
		sprite.play_state("walk", facing)
	elif s["pose"] == "sit":
		state = ACT_STATE.get(act, "sitting")
		sprite.play_state("sit", facing)
	else:
		state = ACT_STATE.get(act, "idle")
		sprite.play_state("talk" if act == "talk" and facing == "down" else "idle", facing)


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
	var show_bubble: bool = state != "walking" and talking_to == null and not detained \
		and fmod(_time + _bubble_phase, 7.0) < 2.6 and ACT_ICON.has(act)
	_bubble.visible = show_bubble
	if show_bubble:
		_bubble_icon.texture = Db.texture("acts/%s.png" % ACT_ICON[act])
		_bubble.position.y = -46 + (3 if state == "sitting" else 0) + round(sin(_time * 3.0))
	_update_glitch(delta)


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
