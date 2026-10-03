class_name WorldOverlay
extends Control
## Подсказки поверх мира: подпись выбранного объекта, реплики пассажиров и значки
## «новая тема для разговора». Рисуются в слое интерфейса (чёткий текст), позиция
## пересчитывается из мира в экран каждый кадр.

var _prompt: PanelContainer
var _prompt_label: Label
var _prompt_target: Interactable
var _barks: Array = []   # [{node, panel, time}]
var _markers: Dictionary = {}  # NPC → TextureRect


func _ready() -> void:
	Ui.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt = Ui.panel("PillPanel")
	var h := Ui.hbox(6)
	_prompt_label = Ui.label("", "", 18)
	h.add_child(_prompt_label)
	_prompt.add_child(h)
	_prompt.visible = false
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)


func _to_screen(world: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world


func set_prompt(target: Interactable, text: String) -> void:
	_prompt_target = target
	_prompt_label.text = text
	_prompt.visible = target != null
	_prompt.reset_size()


func show_bark(node: Node2D, text: String) -> void:
	for b in _barks:
		if b["node"] == node:
			return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.sb(Color("#f4f0ff"), Color("#2a2266"), 2, 12, Color(0, 0, 0, 0.3), 3, Vector4(10, 4, 10, 4)))
	var l := Ui.label(text, "", 17)
	l.add_theme_color_override("font_color", Color("#1e1846"))
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	_barks.append({"node": node, "panel": p, "time": 2.8})


func set_marker(npc: Node2D, on: bool) -> void:
	if on and not _markers.has(npc):
		var t := Ui.tex(Db.texture("ui/exclaim.png"), 28, 40)
		t.modulate = Color(0.75, 0.95, 1.0)
		add_child(t)
		_markers[npc] = t
	elif not on and _markers.has(npc):
		_markers[npc].queue_free()
		_markers.erase(npc)


func clear_world() -> void:
	set_prompt(null, "")
	for b in _barks:
		b["panel"].queue_free()
	_barks.clear()
	for n in _markers.keys():
		set_marker(n, false)


func _process(delta: float) -> void:
	if _prompt.visible and is_instance_valid(_prompt_target):
		var p: Vector2 = _to_screen(_prompt_target.interact_position() + Vector2(0, -30))
		_prompt.position = (p - Vector2(_prompt.size.x / 2.0, _prompt.size.y)).round()
	elif _prompt.visible:
		_prompt.visible = false
	for b in _barks.duplicate():
		b["time"] -= delta
		var node: Node2D = b["node"]
		var panel: PanelContainer = b["panel"]
		if b["time"] <= 0.0 or not is_instance_valid(node):
			panel.queue_free()
			_barks.erase(b)
			continue
		var sp: Vector2 = _to_screen(node.global_position + Vector2(0, -52))
		panel.position = (sp - Vector2(panel.size.x / 2.0, panel.size.y)).round()
		panel.modulate.a = clampf(b["time"] * 2.0, 0.0, 1.0)
	var t: float = Time.get_ticks_msec() / 1000.0
	for npc: Node2D in _markers:
		if not is_instance_valid(npc):
			continue
		var m: TextureRect = _markers[npc]
		var sp2: Vector2 = _to_screen(npc.global_position + Vector2(-9, -58))
		m.position = (sp2 - m.size / 2.0 + Vector2(0, sin(t * 4.0) * 4.0)).round()
		m.visible = npc.visible
