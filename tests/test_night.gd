extends TestSuite
## Ночь: свет во всём поезде выбивает по плану дела; фонарь включается сам и гаснет при свете;
## в темноте осмотреть можно только то, что в луче; на записях камер ночью — силуэты.


func _start(level_id: String) -> void:
	SaveManager.prepare_level(level_id)
	SaveManager.pending_seed = 5
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await wait_frames(2)
	game.ui.close_all()
	await wait_frames(1)


func test_night_auto_flashlight() -> void:
	await _start("level_03")
	var inv: InvestigationManager = game.investigation
	check(not inv.night_at(inv.clock) and not game.player.flashlight.on, "в начале светло, фонарь выключен")
	var n0: float = float(inv.nights[0][0])
	inv.advance(n0 - inv.clock + 0.05)
	await wait_seconds(1.2)
	check(game.is_dark(), "ночь: в поезде темно")
	check(game.player.flashlight.on, "фонарь включился сам")
	check(game.hud.find_children("*", "Button", true, false).all(func(b: Button) -> bool: return not b.text.begins_with("Фонарь")), "лишней кнопки на экране нет")
	# Цель позади героя — в темноте не осмотреть; перед героем — можно.
	var p: Vector2 = game.player.global_position
	game.player.facing = "right"
	game.player.flashlight.aim("right")
	await wait_frames(2)
	check(game.player.flashlight.lights(p + Vector2(80, -16)), "луч освещает то, что впереди")
	check(not game.player.flashlight.lights(p + Vector2(-90, -16)), "позади — темно")
	inv.advance(float(inv.nights[0][1]) - inv.clock + 0.05)
	await wait_seconds(1.2)
	check(not game.is_dark() and not game.player.flashlight.on, "свет вернулся — фонарь погас сам")
	game.queue_free()
	game = null
	await wait_frames(2)


func test_night_silhouettes_on_camera() -> void:
	await _start("level_03")
	var inv: InvestigationManager = game.investigation
	var n0: float = float(inv.nights[0][0])
	inv.advance(n0 - inv.clock + 0.6)
	await wait_frames(2)
	game.open_cameras()
	await wait_frames(3)
	var scr: Node = game.ui.top()
	scr._select("cam1")
	scr._on_scrub(n0 + 0.3)
	await wait_frames(1)
	check(not scr._status.text.contains("Нина") and not scr._status.text.contains("Граф"), "ночью на записи лиц не видно (%s)" % scr._status.text)
	scr.close()
	game.queue_free()
	game = null
	await wait_frames(2)
