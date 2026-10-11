class_name NoSignal
extends Control
## Помехи поверх записи камеры: снег, бегущие полосы и надпись («НЕТ СИГНАЛА», «Запись
## повреждена…»). Рисуется сама, без текстур, перерисовывается каждый кадр.

var text: String = "НЕТ СИГНАЛА"
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color("#ff6a7a"))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 8)
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_label)
	resized.connect(func() -> void: _label.add_theme_font_size_override("font_size", 28 if size.x > 300 else 13))


func show_text(t: String) -> void:
	text = t
	_label.text = t
	_label.add_theme_font_size_override("font_size", 28 if size.x > 300 else 13)


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.08, 0.92))
	var cell: float = 4.0 if size.x > 300 else 2.0
	_rng.seed = int(_t * 30.0)
	var cols: int = int(size.x / cell)
	var rows: int = int(size.y / cell)
	for i in mini(2600, cols * rows / 3):
		var x: int = _rng.randi_range(0, cols)
		var y: int = _rng.randi_range(0, rows)
		var g: float = _rng.randf_range(0.25, 0.9)
		draw_rect(Rect2(x * cell, y * cell, cell, cell), Color(g, g, g, 0.55))
	for k in 3:
		var yy: float = fmod(_t * 90.0 + k * size.y / 3.0, size.y)
		draw_rect(Rect2(0, yy, size.x, cell * 2.0), Color(1, 1, 1, 0.12))
