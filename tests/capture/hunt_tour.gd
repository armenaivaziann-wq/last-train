extends Node
## Визуальная проверка охоты (дело 5): охотник рядом — красная виньетка; герой в укрытии.

const OUT: String = "/tmp/lt_hunt/"


func _ready() -> void:
	SaveManager.enabled = false
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.profile["campaign"]["unlocked"] = 14
	SaveManager.prepare_level("level_05")
	SaveManager.pending_seed = 7
	var game: Node = load("res://game/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.6).timeout
	game.ui.close_all()
	var inv: InvestigationManager = game.investigation
	DirAccess.make_dir_recursive_absolute(OUT)
	game.player.global_position = Vector2(300, 166)
	inv.advance(float(inv.hunts[0]["from"]) - inv.clock + 0.02)
	await get_tree().create_timer(2.5).timeout
	var hunter: Hunter = game.hunt.hunter
	hunter.global_position = game.player.global_position + Vector2(120, -10)
	hunter.set_physics_process(false)
	await get_tree().create_timer(0.6).timeout
	await _shot("hunt_near")
	var near: Dictionary = HideSpots.nearest(game.hunt.spots, game.player.global_position)
	game.player.global_position = near["pos"] + Vector2(0, 10)
	await get_tree().create_timer(0.3).timeout
	for n in get_tree().get_nodes_in_group(&"interactables"):
		if n is Interactable and (n as Interactable).interact_id == near["id"]:
			game.enter_hide(n)
	hunter.global_position = game.player.global_position + Vector2(60, 40)
	await get_tree().create_timer(0.8).timeout
	await _shot("hunt_hidden")
	print("shot hunt")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
