extends Node
## Визуальная проверка дела 14: головоломки «узел» и «замок», ведьма на записи камеры.
## Запуск: Godot --path . --resolution 1280x720 res://tests/capture/puzzle_tour.tscn [-- --wide]

const OUT: String = "/tmp/lt_puzzle/"


func _ready() -> void:
	var wide: bool = "--wide" in OS.get_cmdline_user_args()
	if wide:
		get_window().size = Vector2i(1560, 720)
	var tag: String = "_wide" if wide else ""
	SaveManager.enabled = false
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.profile["campaign"]["unlocked"] = 14
	SaveManager.prepare_level("level_14")
	SaveManager.pending_seed = 7
	var game: Node = load("res://game/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.6).timeout
	game.ui.close_all()
	var inv: InvestigationManager = game.investigation
	DirAccess.make_dir_recursive_absolute(OUT)
	inv.give("s_l14_prof_knots")
	game.open_object("obj_l14_kitel")
	await get_tree().create_timer(0.5).timeout
	var scr: GameScreen = game.ui.top()
	scr._pull(str(inv.puzzle("puz_l14_knot")["order"][0]))
	await _shot("knot" + tag)
	game.ui.close_all()
	inv.give_all(["s_l14_lidia_alibi", "d_l14_log", "s_l14_agata_remembers"])
	inv.advance(Db.parse_time("02:09") - inv.clock)
	game.open_luggage("lidia")
	await get_tree().create_timer(0.5).timeout
	scr = game.ui.top()
	scr._turn(1, 1)
	scr._try_code()
	await _shot("lock" + tag)
	game.ui.close_all()
	scr = game.ui.open("camera_screen")
	await get_tree().create_timer(0.3).timeout
	scr._select("cam2")
	scr._t = Db.parse_time("01:44:05")
	scr._apply_time()
	await get_tree().create_timer(0.5).timeout
	await _shot("camera_witch" + tag)
	print("shot puzzles")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
