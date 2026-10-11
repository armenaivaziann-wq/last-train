extends Node
## Визуальная проверка ночи: свет выбило, фонарь включился сам, луч в сторону взгляда.

func _ready() -> void:
	SaveManager.enabled = false
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.profile["campaign"]["unlocked"] = 14
	SaveManager.prepare_level("level_03")
	SaveManager.pending_seed = 5
	var game: Node = load("res://game/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.6).timeout
	game.ui.close_all()
	var inv: InvestigationManager = game.investigation
	inv.advance(float(inv.nights[0][0]) - inv.clock + 0.05)
	game.player.global_position = Vector2(230, 166)
	game.player.facing = "right"
	await get_tree().create_timer(2.0).timeout
	DirAccess.make_dir_recursive_absolute("/tmp/lt_night")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/lt_night/night_right.png")
	game.player.facing = "up"
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/lt_night/night_up.png")
	print("shot night")
	get_tree().quit()
