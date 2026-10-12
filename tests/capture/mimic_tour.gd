extends Node
## Визуальная проверка дела 4: головоломка «весы» и запись К1 в 01:52 с двумя Луи.

const OUT: String = "/tmp/lt_mimic/"


func _ready() -> void:
	SaveManager.enabled = false
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.profile["campaign"]["unlocked"] = 14
	SaveManager.prepare_level("level_04")
	SaveManager.pending_seed = 7
	var game: Node = load("res://game/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.6).timeout
	game.ui.close_all()
	var inv: InvestigationManager = game.investigation
	DirAccess.make_dir_recursive_absolute(OUT)
	inv.give("d_l4_tags")
	game.open_object("obj_v_scale")
	await get_tree().create_timer(0.5).timeout
	var scr: GameScreen = game.ui.top()
	scr._cycle(0)
	scr._cycle(1)
	scr._cycle(1)
	await _shot("scale")
	game.ui.close_all()
	scr = game.ui.open("camera_screen")
	await get_tree().create_timer(0.3).timeout
	scr._select("cam1")
	scr._t = Db.parse_time("01:52:40")
	scr._apply_time()
	await get_tree().create_timer(0.5).timeout
	await _shot("camera_two_louis")
	print("shot mimic")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
