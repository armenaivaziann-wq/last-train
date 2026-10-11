class_name InspectMarkers
extends Node2D
## Подсказки в мире «что можно исследовать»: над объектами и багажом, которые ещё не открыты,
## мерцает золотая искра; если объект открыт, но в нём остались ненайденные детали — бледная
## искра поменьше; когда всё найдено — маркер исчезает. Ответ не раскрывается: искра есть и у
## объектов без улик, пока их не осмотрели.

const BOB: float = 1.5

var game: Game
var _marks: Dictionary = {}   # Interactable → Sprite2D
var _t: float = 0.0
var _scan: float = 0.0
var _tex: Texture2D


func setup(g: Game) -> void:
	game = g
	z_index = 30
	var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	for p: Vector2i in [Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 5), Vector2i(3, 6), Vector2i(0, 3), Vector2i(1, 3), Vector2i(5, 3), Vector2i(6, 3)]:
		img.set_pixelv(p, Color(1, 1, 1, 0.75))
	for p: Vector2i in [Vector2i(2, 2), Vector2i(4, 2), Vector2i(2, 4), Vector2i(4, 4), Vector2i(3, 2), Vector2i(2, 3), Vector2i(4, 3), Vector2i(3, 4)]:
		img.set_pixelv(p, Color(1, 1, 1, 0.95))
	img.set_pixel(3, 3, Color.WHITE)
	_tex = ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	_t += delta
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.25
		_refresh()
	for it: Interactable in _marks:
		var s: Sprite2D = _marks[it]
		if s.visible and is_instance_valid(it):
			s.position = it.global_position + Vector2(0, -16 + sin(_t * 3.0 + it.global_position.x * 0.05) * BOB)
			s.modulate.a = (0.55 + 0.45 * sin(_t * 4.0 + it.global_position.x)) * float(s.get_meta("alpha", 1.0))


func _refresh() -> void:
	var inv: InvestigationManager = game.investigation
	for node in get_tree().get_nodes_in_group(&"interactables"):
		var it := node as Interactable
		if it == null or not (it.kind == Interactable.Kind.OBJECT or it.kind == Interactable.Kind.LUGGAGE):
			continue
		var s: Sprite2D = _marks.get(it)
		if s == null:
			s = Sprite2D.new()
			s.texture = _tex
			add_child(s)
			_marks[it] = s
		var state: String = inv.inspect_state(it.interact_id)
		var shown: bool = it.enabled and it.is_visible_in_tree() and state != "done" and not game.camera_system.playback
		s.visible = shown
		if state == "new":
			s.self_modulate = Color("#ffd86b")
			s.scale = Vector2.ONE
			s.set_meta("alpha", 1.0)
		else:
			s.self_modulate = Color("#cfe0ff")
			s.scale = Vector2(0.7, 0.7)
			s.set_meta("alpha", 0.6)
	for it: Interactable in _marks.keys():
		if not is_instance_valid(it):
			_marks[it].queue_free()
			_marks.erase(it)
