class_name TimelineBar
extends Control
## Шкала времени записей камер: метки движения (кто вошёл в кадр), отмеченные события,
## бегунок. Нажатие и перетаскивание перематывают запись.

signal scrubbed(t: float)

var t_from: float = 0.0
var t_to: float = 1.0
var value: float = 0.0
## [{t, color}] — метки движения; показываются, если есть улучшение камер.
var markers: Array = []
## Минуты найденных «камерных» улик.
var bookmarks: Array = []
## Провалы записи [{from, to, kind}] — заштрихованы красным (туннель, повреждение).
var bands: Array = []
var _dragging: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(400, 56)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _x_for(t: float) -> float:
	return 12.0 + (t - t_from) / maxf(t_to - t_from, 0.001) * (size.x - 24.0)


func _t_for(x: float) -> float:
	return clampf(t_from + (x - 12.0) / maxf(size.x - 24.0, 1.0) * (t_to - t_from), t_from, t_to)


func _draw() -> void:
	var r := Rect2(Vector2(0, 14), Vector2(size.x, size.y - 22))
	draw_style_box(UiTheme.sb(UiTheme.INSET, UiTheme.BORDER_DIM, 2, 10), r)
	# деления по минутам
	var m: float = ceil(t_from)
	while m <= t_to:
		var x: float = _x_for(m)
		var major: bool = int(m) % 5 == 0
		draw_line(Vector2(x, r.position.y + 4), Vector2(x, r.position.y + (14.0 if major else 8.0)), Color(UiTheme.TEXT_DIM, 0.6 if major else 0.3), 2.0)
		if major:
			draw_string(UiTheme.font, Vector2(x - 20, size.y - 1), Db.format_time(m), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiTheme.TEXT_DIM)
		m += 1.0
	for bd: Dictionary in bands:
		var bx0: float = _x_for(float(bd["from"]))
		var bx1: float = _x_for(float(bd["to"]))
		var br := Rect2(bx0, r.position.y + 2, maxf(2.0, bx1 - bx0), r.size.y - 4)
		draw_rect(br, Color(UiTheme.DANGER, 0.35))
		var hx: float = bx0
		while hx < bx1:
			draw_line(Vector2(hx, br.end.y), Vector2(minf(hx + 6.0, bx1), br.position.y), Color(UiTheme.DANGER, 0.7), 1.5)
			hx += 6.0
	for mk: Dictionary in markers:
		var x2: float = _x_for(float(mk["t"]))
		draw_rect(Rect2(x2 - 1.5, r.position.y + 16, 3, r.size.y - 22), Color(mk["color"], 0.9))
	for b in bookmarks:
		var x3: float = _x_for(float(b))
		draw_colored_polygon(PackedVector2Array([Vector2(x3 - 7, 0), Vector2(x3 + 7, 0), Vector2(x3, 12)]), UiTheme.GOLD)
	# прогресс и бегунок
	var px: float = _x_for(value)
	draw_rect(Rect2(r.position + Vector2(4, r.size.y - 8), Vector2(maxf(0.0, px - 4.0), 5)), Color(UiTheme.CYAN, 0.8))
	draw_line(Vector2(px, 8), Vector2(px, size.y - 6), UiTheme.PINK, 4.0)
	draw_circle(Vector2(px, 10), 7.0, UiTheme.PINK)


func set_value(t: float) -> void:
	value = clampf(t, t_from, t_to)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_emit((event as InputEventMouseButton).position.x)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_emit((event as InputEventMouseMotion).position.x)
		accept_event()
	elif event is InputEventScreenTouch:
		_dragging = (event as InputEventScreenTouch).pressed
		if _dragging:
			_emit((event as InputEventScreenTouch).position.x)
		accept_event()
	elif event is InputEventScreenDrag:
		_emit((event as InputEventScreenDrag).position.x)
		accept_event()


func _emit(x: float) -> void:
	set_value(_t_for(x))
	scrubbed.emit(value)
