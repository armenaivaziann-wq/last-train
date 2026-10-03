class_name CrimeScene
extends Node2D
## Место преступления: неподвижное тело, неровный меловой контур по форме тела, небольшие
## стилизованные пятна и улики на полу. Всё это — постоянные объекты мира: остаются на месте,
## даже когда игрок далеко, и восстанавливаются после загрузки сохранения.
## Действия: осмотреть тело, осмотреть улики (Interactable), поговорить со свидетелем (NPC).

var murder: Dictionary
var kill_time: float = 0.0


func build(m: Dictionary, layout: TrainLayout) -> void:
	murder = m
	kill_time = float(m["t"]["kill"])
	var sc: Dictionary = m["scenario"]
	var ox: float = layout.offsets[sc["carriage"]]
	name = "CrimeScene_%s" % m["id"]
	global_position = m["scene_pos"]
	for b: Array in sc.get("blood", []):
		var s := Sprite2D.new()
		s.texture = Db.texture("crime/blood_%d.png" % int(b[2]))
		s.global_position = Vector2(ox + float(b[0]), float(b[1]))
		s.top_level = true
		add_child(s)
		s.global_position = Vector2(ox + float(b[0]), float(b[1]))
	var outline := Sprite2D.new()
	outline.texture = Db.texture("bodies/%s_outline.png" % m["victim"])
	add_child(outline)
	var body := Sprite2D.new()
	body.texture = Db.texture("bodies/%s.png" % m["victim"])
	add_child(body)
	var it := Interactable.new()
	it.interact_id = MurderDirector.body_object_id(m)
	it.label = "Осмотреть тело: " + Db.char_name(m["victim"])
	it.kind = Interactable.Kind.OBJECT
	it.radius = 34.0
	it.needs_light = false
	add_child(it)
	for item: Dictionary in sc.get("items", []):
		var p := Vector2(ox + float(item["pos"][0]), float(item["pos"][1]))
		var s2 := Sprite2D.new()
		s2.texture = Db.texture("crime/%s.png" % item["sprite"])
		s2.top_level = true
		add_child(s2)
		s2.global_position = p
		var it2 := Interactable.new()
		it2.interact_id = str(item["id"])
		it2.label = str(item["label"])
		it2.kind = Interactable.Kind.OBJECT
		it2.radius = 24.0
		it2.needs_light = false
		it2.top_level = true
		add_child(it2)
		it2.global_position = p


## Для записей камер: до момента убийства места преступления ещё нет.
func show_at(t: float) -> void:
	visible = t >= kill_time
	for c in get_children():
		if c is CanvasItem and (c as CanvasItem).top_level:
			(c as CanvasItem).visible = visible
