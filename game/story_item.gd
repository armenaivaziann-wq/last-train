class_name StoryItem
extends Node2D
## Предмет мира из данных дела: спрайт + точка взаимодействия. Может «дышать»
## (чемодан с кем-то внутри: покачивается и слышно дыхание, когда герой рядом).

var data: Dictionary
var _sprite: Sprite2D
var _t: float = 0.0
var _breath_cd: float = 0.0


func setup(it: Dictionary, pos: Vector2) -> void:
	data = it
	name = "Item_" + str(it["id"])
	position = pos
	var path: String = str(it["sprite"])
	_sprite = Sprite2D.new()
	_sprite.texture = Db.texture((path if path.contains("/") else "crime/" + path) + ".png")
	if it.get("tall", false):
		_sprite.offset = Vector2(0, -_sprite.texture.get_height() / 2.0)
	add_child(_sprite)
	var node := Interactable.new()
	node.interact_id = str(it["id"])
	node.label = str(it.get("label", "Осмотреть"))
	node.kind = Interactable.Kind.OBJECT
	node.radius = float(it.get("radius", 24.0))
	node.position = Vector2(0, -6 if it.get("tall", false) else 0)
	add_child(node)


func _process(delta: float) -> void:
	if not data.get("breathing", false):
		return
	_t += delta
	_sprite.scale = Vector2(1.0 + 0.04 * sin(_t * 2.4), 1.0 - 0.03 * sin(_t * 2.4))
	_breath_cd -= delta
	var player: Node2D = get_tree().get_first_node_in_group(&"player")
	if player and _breath_cd <= 0.0 and player.global_position.distance_to(global_position) < 90.0:
		_breath_cd = 2.6
		AudioManager.play_sfx("breath", -10.0)
