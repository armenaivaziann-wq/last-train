extends Node
## Визуальная проверка новых окон: колесо шифра (дело 9), последовательность (дело 7),
## выбор с чаем (дело 7), узел в своём пальто (дело 14). Запуск: --resolution 1280x720 [-- --wide]

const OUT: String = "/tmp/lt_v2/"
var game: Node


func _ready() -> void:
	var wide: bool = "--wide" in OS.get_cmdline_user_args()
	if wide:
		get_window().size = Vector2i(1560, 720)
	var tag: String = "_wide" if wide else ""
	SaveManager.enabled = false
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.profile["campaign"]["unlocked"] = 14
	DirAccess.make_dir_recursive_absolute(OUT)
	await _level("level_09")
	game.investigation.give_all(["i_l9_note_john", "s_l9_klara_cipher"])
	game.open_object("obj_l9_wheel")
	await get_tree().create_timer(0.4).timeout
	game.ui.top()._rotate(1)
	await _shot("cipher" + tag)
	await _level("level_07")
	game.investigation.give("s_l7_prof_cups")
	game.open_object("obj_l7_tray")
	await get_tree().create_timer(0.4).timeout
	await _shot("cups" + tag)
	game.ui.close_all()
	game.investigation.advance(4.1)
	await get_tree().create_timer(0.5).timeout
	await _shot("tea_offer" + tag)
	print("shot v2")
	get_tree().quit()


func _level(id: String) -> void:
	if game:
		game.queue_free()
		await get_tree().process_frame
	SaveManager.prepare_level(id)
	SaveManager.pending_seed = 7
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.6).timeout
	game.ui.close_all()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
