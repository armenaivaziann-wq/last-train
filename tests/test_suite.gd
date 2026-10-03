class_name TestSuite
extends Node
## База для тестов: проверки, ожидание, запуск дела в game.tscn.

var failures: PackedStringArray = []
var game: Node = null


func before_each() -> void:
	pass


func after_each() -> void:
	if game and is_instance_valid(game):
		game.queue_free()
		game = null
	get_tree().paused = false
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
	await get_tree().process_frame
	await get_tree().process_frame


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (ожидалось %s, получено %s)" % [message, str(expected), str(actual)])


func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func wait_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## Запуск дела. skip_brief — сразу закрыть вводный брифинг.
func start_case(case_id: String = "case_01", skip_brief: bool = true) -> Node:
	SaveManager.pending_case = case_id
	SaveManager.pending_resume = false
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	if skip_brief:
		game.ui.close_all()
		await get_tree().process_frame
	return game
