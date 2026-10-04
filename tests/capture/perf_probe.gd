extends Node
## Замер времени кадра: игрок в разных вагонах.

func _ready() -> void:
	var level: String = "level_09"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			level = a.substr(8)
	SaveManager.enabled = false
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.profile["campaign"]["unlocked"] = 10
	SaveManager.prepare_level(level)
	SaveManager.pending_seed = 9
	var game: Node = load("res://game/game.tscn").instantiate()
	add_child(game)
	for i in 5:
		await get_tree().process_frame
	game.ui.close_all()
	for spot in [["passenger", 300.0], ["vestibule", 18.0], ["vestibule", 44.0], ["restaurant", 300.0]]:
		game.player.global_position = Vector2(game.layout.offsets[spot[0]] + spot[1], 118.0)
		var t0: int = Time.get_ticks_msec()
		var worst: int = 0
		for i in 20:
			var f0: int = Time.get_ticks_msec()
			await get_tree().process_frame
			worst = maxi(worst, Time.get_ticks_msec() - f0)
		print("worst ", worst, " ", spot[0], ": ", (Time.get_ticks_msec() - t0) / 20.0, " мс/кадр")
	get_tree().quit()
