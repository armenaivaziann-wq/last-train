class_name TouchJoystick
extends Control
## Плавающий виртуальный джойстик: касание в левой нижней зоне ставит основание под палец,
## перетаскивание даёт вектор движения. Мышь эмулирует касание — можно проверить на ПК.

signal vector_changed(v: Vector2)

const RADIUS: float = 70.0
const DEAD_ZONE: float = 0.12
## Прилипание к осям: если палец ведёт почти горизонтально (или почти вертикально),
## малая поперечная составляющая отбрасывается — герой идёт ровно по коридору, а не
## «сползает» вниз или вверх от неточного движения пальца.
const AXIS_SNAP: float = 0.4

var vector: Vector2 = Vector2.ZERO
var _touch_index: int = -1
var _center: Vector2
var _home: Vector2
var _base: TextureRect
var _knob: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_base = TextureRect.new()
	_base.texture = Db.texture("ui/joystick_base.png")
	_base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_base.size = Vector2(RADIUS * 2, RADIUS * 2)
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.modulate.a = 0.75
	add_child(_base)
	_knob = TextureRect.new()
	_knob.texture = Db.texture("ui/joystick_knob.png")
	_knob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_knob.size = Vector2(64, 64)
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_knob)
	resized.connect(_reset)
	_reset.call_deferred()


func _reset() -> void:
	_home = Vector2(RADIUS + 20.0, size.y - RADIUS - 20.0)
	_center = _home
	_place()


func _place() -> void:
	_base.position = _center - _base.size / 2.0
	_knob.position = _center + vector * RADIUS - _knob.size / 2.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch_index == -1:
			_touch_index = t.index
			_center = t.position
			_update(t.position)
			accept_event()
		elif not t.pressed and t.index == _touch_index:
			_release()
			accept_event()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch_index:
			_update(d.position)
			accept_event()


func _update(pos: Vector2) -> void:
	var v: Vector2 = (pos - _center) / RADIUS
	if v.length() > 1.0:
		v = v.normalized()
	vector = snap_axes(v) if v.length() > DEAD_ZONE else Vector2.ZERO
	_place()
	vector_changed.emit(vector)


static func snap_axes(v: Vector2) -> Vector2:
	var len: float = v.length()
	if absf(v.y) < absf(v.x) * AXIS_SNAP:
		v.y = 0.0
	elif absf(v.x) < absf(v.y) * AXIS_SNAP:
		v.x = 0.0
	return v.normalized() * len if v != Vector2.ZERO else v


## Сбросить касание (окно открылось поверх джойстика).
func release() -> void:
	_release()


func _release() -> void:
	_touch_index = -1
	vector = Vector2.ZERO
	_center = _home
	_place()
	vector_changed.emit(vector)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_release()
