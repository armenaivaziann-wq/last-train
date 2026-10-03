extends Node
## Визуальная проверка события-убийства: туннель, крик с указателем, место преступления.

var out: String = "/tmp/lt_murder"
var game: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	SaveManager.enabled = false
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.pending_case = "case_01"
	SaveManager.pending_resume = false
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await _wait(0.3)
	game.ui.close_all()
	var inv: InvestigationManager = game.investigation
	var m: Dictionary = inv.murders.murders[0]
	game.player.global_position = Vector2(560, 166)
	inv.advance(m["t"]["tunnel_in"] - inv.clock + 0.001)
	await _wait(1.0)
	await _shot("01_tunnel")
	inv.advance(m["t"]["kill"] - inv.clock + 0.001)
	await _wait(0.9)
	await _shot("02_scream")
	game.player.global_position = m["scene_pos"] + Vector2(-60, -10)
	await _wait(0.6)
	await _shot("03_discovered")
	game.player.global_position = m["scene_pos"] + Vector2(-26, -14)
	game.player.facing = "right"
	inv.advance(1.2)
	await _wait(1.2)
	await _shot("04_scene")
	game.open_object(MurderDirector.body_object_id(m))
	await _wait(0.4)
	await _shot("05_body")
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)
