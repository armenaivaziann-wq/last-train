extends Node
## Визуальная проверка дела 2: выбор «выпить/отказаться», отравленный экран, бокалы.

const OUT: String = "/tmp/lt_poison/"


func _ready() -> void:
	SaveManager.enabled = false
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.profile["campaign"]["unlocked"] = 14
	SaveManager.prepare_level("level_02")
	SaveManager.pending_seed = 7
	var game: Node = load("res://game/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.6).timeout
	game.ui.close_all()
	var inv: InvestigationManager = game.investigation
	DirAccess.make_dir_recursive_absolute(OUT)
	inv.advance(1.3)
	await get_tree().create_timer(0.6).timeout
	await _shot("offer")
	game.ui.top()._pick(true)
	await get_tree().create_timer(5.0).timeout
	await _shot("poisoned")
	inv.give("d_l2_cart_log")
	game.open_object("obj_l2_tray")
	await get_tree().create_timer(0.5).timeout
	game.ui.top()._cycle(0)
	await _shot("glasses")
	print("shot poison")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
