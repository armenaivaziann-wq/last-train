extends Node
## Визуальная проверка: убийство в туннеле, контекстные цели и осмотр тела.

var out: String = "/tmp/lt_goal"
var game: Node


func _ready() -> void:
	var level: String = "level_01"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			level = a.substr(8)
	DirAccess.make_dir_recursive_absolute(out)
	SaveManager.enabled = false
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.profile["campaign"]["unlocked"] = 10
	SaveManager.prepare_level(level)
	SaveManager.pending_seed = 9
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await _wait(0.3)
	game.ui.close_all()
	var inv: InvestigationManager = game.investigation
	var m: Dictionary = inv.murders.murders[0]
	print("victim=", m["victim"], " carriage=", m["carriage"], " witnesses=", m["witnesses"], " escape=", m["escape_spot"])
	inv.advance(m["t"]["kill"] - inv.clock + 0.01)
	await _wait(1.0)
	game.update_goal()
	await _shot(level + "_1_scream")
	game.player.global_position = m["scene_pos"] + Vector2(-36, -6)
	await _wait(0.8)
	game.update_goal()
	await _shot(level + "_2_found")
	game.open_object(MurderDirector.body_object_id(m))
	await _wait(0.4)
	await _shot(level + "_3_body")
	game.ui.close_all()
	game.update_goal()
	await _wait(0.3)
	await _shot(level + "_4_next_goal")
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name, " goal=", game.hud._goal_label.text)
