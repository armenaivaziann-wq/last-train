extends Node
## Визуальная проверка правила дела 3: отражение в окне запаздывает на минуту.

var out: String = "/tmp/lt_levels"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	SaveManager.enabled = false
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.profile["campaign"]["unlocked"] = 10
	SaveManager.prepare_level("level_03")
	SaveManager.pending_seed = 9
	var game: Node = load("res://game/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(1.0).timeout
	game.ui.close_all()
	var inv: InvestigationManager = game.investigation
	var win := Vector2(game.layout.offsets["passenger"] + 275.0, 130.0)
	game.player.global_position = win
	for i in 12:
		inv.advance(0.1)
		await get_tree().create_timer(0.3).timeout
	await _shot("level_03_r1_standing")
	game.player.global_position = win + Vector2(120, 40)
	await get_tree().process_frame
	inv.advance(0.3)
	await get_tree().create_timer(0.3).timeout
	await _shot("level_03_r2_walked_away")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)
