class_name Carriage
extends Node2D
## Вагон, собранный из разметки data/layout/<id>.json (её пишет tools/gen_train.py):
## фон, коллизии стен и мебели, предметы с сортировкой по Y, свечение ламп и окон,
## интерактивные объекты и двери. Сцена вагона задаёт только carriage_id и особые узлы.

## Предметы на стене: рисуются за персонажами и центрируются.
const WALL_PROPS: PackedStringArray = ["mirror", "cctv", "extinguisher"]

@export var carriage_id: String = "passenger"
## Сообщения для запертых дверей (слева/справа).
@export var left_door_message: String = "Дверь в локомотив заперта."
@export var right_door_message: String = "Дальше багажный вагон. Он закрыт."

var data: Dictionary
var interactables: Dictionary = {}  # id → Interactable
var doors: Array[TrainDoor] = []
var lamp_glows: Array[Sprite2D] = []
var window_glows: Array[Sprite2D] = []


## entities — общий узел с сортировкой по Y (персонажи и предметы всех вагонов).
func build(entities: Node2D, glow_layer: Node2D) -> void:
	data = Db.layout(carriage_id)
	var bg := Sprite2D.new()
	bg.name = "Background"
	bg.centered = false
	bg.texture = Db.texture("train/%s_bg.png" % carriage_id)
	add_child(bg)
	move_child(bg, 0)

	var body := StaticBody2D.new()
	body.name = "Walls"
	body.collision_layer = 1
	body.collision_mask = 0
	for r: Array in data.get("colliders", []):
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(float(r[2]), float(r[3]))
		shape.shape = rect
		shape.position = Vector2(float(r[0]) + float(r[2]) / 2.0, float(r[1]) + float(r[3]) / 2.0)
		body.add_child(shape)
	add_child(body)

	var decor := Node2D.new()
	decor.name = "Decor"
	add_child(decor)
	for p: Dictionary in data.get("props", []):
		var tex: Texture2D = Db.texture("props/%s.png" % p["sprite"])
		var s := Sprite2D.new()
		s.texture = tex
		var pos := Vector2(float(p["pos"][0]), float(p["pos"][1]))
		if p["sprite"] in WALL_PROPS:
			s.position = pos
			decor.add_child(s)
		else:
			s.offset = Vector2(0, -tex.get_height() / 2.0)
			s.position = position + pos
			s.name = "%s_%s" % [carriage_id, p["sprite"]]
			entities.add_child(s)

	for it: Dictionary in data.get("interactables", []):
		var node := Interactable.new()
		node.interact_id = it["id"]
		node.label = it["label"]
		node.radius = float(it.get("radius", 26))
		node.kind = Interactable.Kind.MONITOR if it["id"] == "obj_monitor" else Interactable.Kind.OBJECT
		node.needs_light = node.kind != Interactable.Kind.MONITOR
		node.position = Vector2(float(it["pos"][0]), float(it["pos"][1]))
		if it.get("sprite") != null and str(it.get("sprite")) != "":
			var s := Sprite2D.new()
			s.texture = Db.texture("props/%s.png" % it["sprite"])
			node.add_child(s)
		add_child(node)
		interactables[it["id"]] = node

	for d: Dictionary in data.get("doors", []):
		var door := TrainDoor.new()
		door.locked = bool(d.get("locked", false))
		door.locked_message = left_door_message if d["id"] == "left" else right_door_message
		door.position = Vector2(float(d["pos"][0]), float(d["pos"][1]))
		add_child(door)
		doors.append(door)

	var glow_tex: Texture2D = Db.texture("props/glow_lamp.png")
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for l: Array in data.get("lamps", []):
		var g := Sprite2D.new()
		g.texture = glow_tex
		g.material = add_mat
		g.position = position + Vector2(float(l[0]), float(l[1]) + 6.0)
		g.modulate = Color(1, 0.85, 0.6, 0.55)
		glow_layer.add_child(g)
		lamp_glows.append(g)
	var win_tex: Texture2D = Db.texture("props/window_light.png")
	for w: Array in data.get("window_lights", []):
		var g := Sprite2D.new()
		g.texture = win_tex
		g.material = add_mat
		g.centered = false
		g.position = position + Vector2(float(w[0]) - 32.0, float(w[1]))
		g.modulate = Color(0.7, 0.8, 1.0, 0.45)
		glow_layer.add_child(g)
		window_glows.append(g)


func width() -> float:
	return float(data["size"][0])
