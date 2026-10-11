extends Node
## Визуальная проверка авторского дела: бриф, цель, предметы сюжета, туннель, запись камеры,
## диалог, журнал.
## Запуск (с окном): Godot --path . --resolution 1280x720 res://tests/capture/level_tour.tscn -- --level=level_04

var out: String = "/tmp/lt_levels"
var game: Node


func _ready() -> void:
	var level: String = "level_02"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			level = a.substr(8)
	DirAccess.make_dir_recursive_absolute(out)
	SaveManager.enabled = false
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.profile["campaign"]["unlocked"] = 10
	SaveManager.profile["equipment"]["cameras"] = 2
	SaveManager.prepare_level(level)
	SaveManager.pending_seed = 9
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await _wait(1.6)
	await _shot(level + "_0_brief")
	game.ui.close_all()
	await _wait(0.4)
	game.update_goal()
	await _shot(level + "_1_start")
	var inv: InvestigationManager = game.investigation
	var d: Dictionary = inv.data
	# Первый сюжетный предмет мира
	var items: Array = d.get("extra_items", [])
	if not items.is_empty():
		var it: Dictionary = items[0]
		game.player.global_position = Vector2(game.layout.offsets[it["carriage"]] + float(it["pos"][0]) - 26.0, float(it["pos"][1]) + 6.0)
		await _wait(0.8)
		await _shot(level + "_2_item")
		game.open_object(str(it["id"]))
		await _wait(0.5)
		await _shot(level + "_3_object")
		game.ui.close_all()
	# Туннель
	if not inv.murders.murders.is_empty():
		var m: Dictionary = inv.murders.murders[0]
		inv.advance(float(m["t"]["flicker"]) - inv.clock + 0.02)
		await _wait(0.7)
		await _shot(level + "_4_tunnel")
		inv.advance(float(m["t"]["tunnel_out"]) - inv.clock + 0.05)
		await _wait(0.5)
	# Ключевая запись камеры
	for cc: Dictionary in d.get("camera_clues", []):
		if cc["id"] in d["key_clues"]:
			game.open_cameras()
			await _wait(0.5)
			var scr: Node = game.ui.top()
			scr._select(cc["camera"])
			var w: Array = cc["windows"][0]
			scr._on_scrub((Db.parse_time(w[0]) + Db.parse_time(w[1])) / 2.0)
			await _wait(0.6)
			await _shot(level + "_5_camera")
			game.ui.close_all()
			break
	# Диалог с виновником (с несколькими найденными уликами — видно, почему открылись темы) и журнал
	for id: String in d["key_clues"].slice(0, 6):
		inv.give(id)
	game.open_dialogue(str(d["culprit"]))
	await _wait(0.6)
	await _shot(level + "_6_dialogue")
	game.ui.close_all()
	for id: String in d["key_clues"].slice(0, 6):
		inv.give(id)
	game.update_goal()
	game.open_journal("clues")
	await _wait(0.5)
	await _shot(level + "_7_journal")
	game.ui.close_all()
	game.open_journal("verdict:" + str(d["culprit"]))
	await _wait(0.5)
	await _shot(level + "_8_verdict")
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	print("before ", name, " clock=", game.investigation.clock if game else 0.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)
