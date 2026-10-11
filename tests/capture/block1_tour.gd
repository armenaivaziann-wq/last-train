extends Node
## Визуальная проверка блока 1: помехи в туннеле, маскировка на записи, невидимый вампир,
## доска обвинения, доска передвижений, цены действий.

var out: String = "/tmp/lt_block1"
var game: Node


func _start(level: String) -> void:
	if game:
		game.queue_free()
		await get_tree().process_frame
	SaveManager.prepare_level(level)
	SaveManager.pending_seed = 13
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await _wait(0.6)
	game.ui.close_all()
	await _wait(0.2)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	SaveManager.enabled = false
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.profile["campaign"]["unlocked"] = 14
	SaveManager.profile["equipment"]["cameras"] = 2
	# 1. Туннель: помехи на камере вагона с убийством
	await _start("level_01")
	var inv: InvestigationManager = game.investigation
	var m: Dictionary = inv.murders.murders[0]
	inv.advance(m["t"]["kill"] + 0.6 - inv.clock)
	game.open_cameras()
	await _wait(0.5)
	var scr: Node = game.ui.top()
	scr._select(str(m["camera"]))
	scr._on_scrub(m["t"]["kill"])
	await _wait(0.4)
	await _shot("1_tunnel_no_signal")
	game.ui.close_all()
	# 2. Перевёртыш в облике Агаты у тележки
	await _start("level_02")
	game.open_cameras()
	await _wait(0.5)
	scr = game.ui.top()
	scr._select("cam3")
	scr._on_scrub(Db.parse_time("01:47:20"))
	await _wait(0.4)
	await _shot("2_shapeshifter_as_agata")
	game.ui.close_all()
	# 3. Вампир невидим, дверь открывается сама
	await _start("level_12")
	game.open_cameras()
	await _wait(0.5)
	scr = game.ui.top()
	scr._select("cam5")
	scr._on_scrub(Db.parse_time("01:45:40"))
	await _wait(0.4)
	await _shot("3_vampire_invisible")
	game.ui.close_all()
	# 4. Диалог с ценами, доска обвинения, доска передвижений
	await _start("level_02")
	inv = game.investigation
	for id: String in ["s_l2_louis_alibi", "s_l2_tikhon_hat", "i_l2_glove_photo", "c_l2_cart", "c_l2_agata_svc", "p_l2_handle_powder", "i_l2_stage_powder"]:
		inv.give(id)
	inv.deduce("c_l2_cart", "c_l2_agata_svc")
	inv.deduce("p_l2_handle_powder", "i_l2_stage_powder")
	game.open_dialogue("agata")
	await _wait(0.6)
	await _shot("4_dialogue_costs")
	game.ui.close_all()
	game.open_journal("verdict:louis")
	await _wait(0.5)
	await _shot("5_accusation_board")
	game.ui.close_all()
	inv.board_set("louis", 3, inv.layout.carriage_ids[1])
	game.open_journal("timeline")
	await _wait(0.3)
	var j: Node = game.ui.top()
	j._board_mode = true
	j._check_board()
	await _wait(0.4)
	await _shot("6_movement_board")
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)
