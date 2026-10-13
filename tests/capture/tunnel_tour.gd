extends Node
## Скриншоты туннелей (дело 4): предупреждение, кто в опасности; герой рядом — убийца отступил.

const OUT: String = "/tmp/lt_tunnel/"


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
	var m: Dictionary = inv.murders.murders.filter(func(x: Dictionary) -> bool: return x["victim"] != "")[1]
	inv.advance(float(m["t"]["warn"]) - 0.3 - inv.clock)
	await get_tree().create_timer(0.3).timeout
	if game.ui.top() and game.ui.top().name == "choice_screen":
		game.ui.top()._pick(false)
	game.ui.close_all()
	await get_tree().create_timer(0.3).timeout
	inv.advance(float(m["t"]["warn"]) - inv.clock + 0.01)
	await get_tree().create_timer(1.0).timeout
	await _shot("tunnel_warn")
	inv.advance(float(m["t"]["kill"]) - 0.05 - inv.clock)
	await get_tree().create_timer(0.2).timeout
	game.player.global_position = game.npcs[m["victim"]].global_position + Vector2(24, 10)
	game.camera.snap_to_target()
	await get_tree().create_timer(0.2).timeout
	inv.advance(0.08)
	await get_tree().create_timer(1.0).timeout
	await _shot("tunnel_foiled")
	print("shot tunnel")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
