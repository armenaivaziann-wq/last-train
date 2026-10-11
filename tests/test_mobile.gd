extends TestSuite
## Мобильный интерфейс: на минимальном логическом экране (1280×720) и на вытянутых экранах
## телефонов цель не наезжает на таймер и кнопки, сенсорные кнопки достаточно крупные,
## джойстик не двигает героя, когда открыто окно.


func _start_level(level_id: String) -> void:
	SaveManager.prepare_level(level_id)
	SaveManager.pending_seed = 7
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await wait_frames(2)
	game.ui.close_all()
	await wait_frames(1)


func _rect(c: Control) -> Rect2:
	return Rect2(c.global_position, c.get_combined_minimum_size())


func test_goal_never_overlaps_hud() -> void:
	await _start_level("level_10")
	var hud: Node = game.hud
	var texts: Array = ["Цель: найдите улики (0/8)"]
	for l: Dictionary in Db.levels():
		var d: Dictionary = Db.resolve_case(Db.level_case_ref(l), 7)
		for g: Dictionary in d.get("goals", []):
			texts.append("Цель: " + str(g["text"]))
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1560, 720), Vector2i(1280, 960)]:
		get_tree().root.size = size
		for t: String in texts:
			hud.set_goal(t)
			await wait_frames(2)
			var g: Rect2 = _rect(hud._goal_panel)
			check(not g.intersects(_rect(hud._top_left)) and not g.intersects(_rect(hud._top_right)),
				"%s: цель «%s» не перекрывает панели" % [size, t.left(40)])
			check(g.position.x >= 0 and g.end.x <= hud.get_viewport_rect().size.x + 1, "%s: цель в пределах экрана" % size)
	get_tree().root.size = Vector2i(1280, 720)


func test_touch_buttons_are_large() -> void:
	await _start_level("level_02")
	for b: Button in game.hud.find_children("*", "Button", true, false):
		if b.is_visible_in_tree():
			var s: Vector2 = b.get_combined_minimum_size().max(b.size)
			check(s.x >= 56 and s.y >= 56, "кнопка «%s» не меньше 56 px (%s)" % [b.text if b.text != "" else b.tooltip_text, s])


func test_joystick_released_when_window_opens() -> void:
	await _start_level("level_02")
	var j: TouchJoystick = game.hud.joystick
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = Vector2(100, 200)
	j._gui_input(press)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(170, 200)
	j._gui_input(drag)
	check(j.vector.length() > 0.5, "джойстик даёт движение")
	game.open_journal()
	await wait_frames(3)
	check(j.vector == Vector2.ZERO, "при открытии окна движение сбрасывается")
	var p0: Vector2 = game.player.global_position
	await wait_frames(10)
	check(game.player.global_position.distance_to(p0) < 1.0, "герой стоит, пока открыт журнал")


func test_viewport_resize_applies() -> void:
	# Проверка, что смена размера окна в тестах действительно меняет логический экран.
	get_tree().root.size = Vector2i(1560, 720)
	await wait_frames(2)
	var w: float = get_viewport().get_visible_rect().size.x
	get_tree().root.size = Vector2i(1280, 720)
	await wait_frames(2)
	check(w > 1300.0, "логическая ширина меняется (%.0f)" % w)
