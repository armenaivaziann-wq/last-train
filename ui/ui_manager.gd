class_name UIManager
extends Control
## Стек полноэкранных интерфейсов поверх игры или меню. Пока стек не пуст, часы дела
## остановлены и герой не управляется. Esc / «назад» закрывает верхний экран, а если
## экранов нет — открывает паузу.

signal stack_changed(has_modal: bool)

const SCREENS: String = "res://ui/screens/%s.gd"

## Игровая сессия (Game) или null в главном меню.
var game: Node = null
var _stack: Array[GameScreen] = []
var _layer: Control


func _ready() -> void:
	Ui.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = Control.new()
	_layer.name = "Screens"
	Ui.full_rect(_layer)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)


## Открыть экран по имени скрипта из res://ui/screens (например "journal_screen").
func open(screen_name: String, args: Dictionary = {}) -> GameScreen:
	var script: GDScript = load(SCREENS % screen_name)
	var screen: GameScreen = script.new()
	screen.name = screen_name
	screen.game = game
	screen.ui = self
	_layer.add_child(screen)
	_stack.append(screen)
	screen.open(args)
	AudioManager.play_sfx("panel_open", -8.0)
	stack_changed.emit(true)
	return screen


func close(screen: GameScreen) -> void:
	if not screen in _stack:
		return
	_stack.erase(screen)
	screen.closed.emit()
	screen.queue_free()
	AudioManager.play_sfx("panel_close", -10.0)
	if not _stack.is_empty():
		_stack[_stack.size() - 1].refresh()
	stack_changed.emit(not _stack.is_empty())


func close_top() -> void:
	if not _stack.is_empty():
		_stack[_stack.size() - 1].on_back()


func close_all() -> void:
	for s in _stack.duplicate():
		close(s)


func top() -> GameScreen:
	return null if _stack.is_empty() else _stack[_stack.size() - 1]


func find(screen_name: String) -> GameScreen:
	for s in _stack:
		if s.name == screen_name:
			return s
	return null


func has_modal() -> bool:
	return not _stack.is_empty()


func depth() -> int:
	return _stack.size()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if has_modal():
			close_top()
		elif game:
			open("pause_menu")
