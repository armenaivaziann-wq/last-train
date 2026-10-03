class_name TargetHighlight
extends Node2D
## Подсветка объекта, с которым можно взаимодействовать: мягкое золотое свечение,
## кольцо под предметом и облачко с лупой над ним (как на референсе). Для пассажиров —
## только кольцо, облачко у них своё. Эффект один и неяркий — экран не перегружен.

var _target: Interactable
var _ring: Sprite2D
var _glow: Sprite2D
var _bubble: Sprite2D
var _icon: Sprite2D
var _t: float = 0.0


func _ready() -> void:
	_glow = Sprite2D.new()
	_glow.texture = Db.texture("ui/glow_gold.png")
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.scale = Vector2(0.75, 0.75)
	add_child(_glow)
	_ring = Sprite2D.new()
	_ring.texture = Db.texture("ui/target_ring.png")
	add_child(_ring)
	_bubble = Sprite2D.new()
	_bubble.texture = Db.texture("ui/bubble.png")
	_bubble.z_index = 20  # облачко поверх персонажей, кольцо — под ними (слой свечения пола)
	add_child(_bubble)
	_icon = Sprite2D.new()
	_icon.position = Vector2(0, -1)
	_bubble.add_child(_icon)
	visible = false


func set_target(t: Interactable) -> void:
	_target = t
	visible = t != null
	if t == null:
		return
	var npc: bool = t.kind == Interactable.Kind.NPC
	_bubble.visible = not npc
	_glow.visible = not npc
	_icon.texture = Db.texture("acts/%s.png" % ("suitcase" if t.kind == Interactable.Kind.LUGGAGE else ("ticket" if t.kind == Interactable.Kind.DOOR else "look")))


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target) or not _target.is_visible_in_tree():
		visible = false
		return
	_t += delta
	var p: Vector2 = _target.interact_position()
	var base: Vector2 = p if _target.kind != Interactable.Kind.NPC else _target.get_parent().global_position
	global_position = base.round()
	_ring.position = Vector2(0, 6 if _target.kind != Interactable.Kind.NPC else 0)
	_ring.modulate.a = 0.65 + 0.35 * sin(_t * 5.0)
	_glow.modulate.a = 0.35 + 0.15 * sin(_t * 5.0)
	_bubble.position = Vector2(0, -22 + round(sin(_t * 4.0) * 1.5))
