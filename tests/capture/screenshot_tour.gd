extends Node
## Визуальная проверка: запускает дело и сохраняет скриншоты ключевых экранов в OUT.
## Запуск (с окном): Godot --path . --resolution 1280x720 res://tests/capture/screenshot_tour.tscn -- --out=/tmp/lt_shots

var out: String = "/tmp/lt_shots"
var game: Node


func _ready() -> void:
	var only_main: bool = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		if a == "--main-only":
			only_main = true
	DirAccess.make_dir_recursive_absolute(out)
	SaveManager.enabled = false
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.profile["equipment"]["cameras"] = 2
	SaveManager.pending_case = "case_01"
	SaveManager.pending_resume = false
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await _frames(10)
	await _shot("00_brief")
	game.ui.close_all()
	game.player.global_position = Vector2(290, 160)
	game.player.facing = "up"
	await _wait(1.2)
	await _shot("01_main")
	game.player.global_position = Vector2(372, 106)
	game.player.facing = "up"
	await _wait(0.6)
	await _shot("01b_target")
	if only_main:
		game.open_cameras()
		await _wait(0.5)
		await _shot("04_cameras")
		get_tree().quit()
		return
	game.investigation.give("p_torn_page")
	game.investigation.give("d_robert_stub")
	game.player.global_position = Vector2(1020, 150)
	await _wait(0.8)
	await _shot("02_restaurant")
	game.ui.open("passenger_screen", {"id": "robert"})
	await _wait(0.4)
	await _shot("03_passenger")
	game.ui.close_all()
	game.open_cameras()
	await _wait(0.5)
	await _shot("04_cameras_grid")
	var scr: Node = game.ui.top()
	scr._select("cam2")
	scr._on_scrub(Db.parse_time("01:40:20"))
	await _wait(0.5)
	await _shot("05_camera_single")
	game.ui.close_all()
	game.open_journal("clues")
	await _wait(0.4)
	await _shot("06_journal")
	game.ui.close_all()
	game.open_dialogue("klara")
	await _wait(0.6)
	await _shot("07_dialogue")
	game.ui.close_all()
	game.open_documents("robert")
	await _wait(0.4)
	await _shot("08_docs")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)
