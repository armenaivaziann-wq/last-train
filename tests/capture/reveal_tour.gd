extends Node
## Визуальная проверка: раскрытие злодея и экран результата / поражения.

var out: String = "/tmp/lt_reveal"
var game: Node


func _ready() -> void:
	var level: String = "level_01"
	var fail: bool = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			level = a.substr(8)
		if a == "--fail":
			fail = true
	DirAccess.make_dir_recursive_absolute(out)
	SaveManager.enabled = false
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.profile["campaign"]["unlocked"] = 10
	SaveManager.prepare_level(level)
	SaveManager.pending_seed = 5
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await _wait(0.3)
	game.ui.close_all()
	var inv: InvestigationManager = game.investigation
	var culprit: String = str(game.case_data["culprit"])
	if fail:
		inv.advance(25.0)
		await _wait(1.0)
		await _shot(level + "_escape")
		for i in 8:
			await _wait(0.5)
			print("t", i, " top=", game.ui.top().name if game.ui.top() else "-", " valid=", is_instance_valid(game))
		await _shot(level + "_fail_result")
		get_tree().quit()
		return
	for id in game.case_data["key_clues"].slice(0, 3):
		inv.give(id)
	inv.advance(9.0)
	game.accuse(culprit, game.case_data["key_clues"].slice(0, 3), "")
	await _wait(2.3)
	await _shot(level + "_reveal")
	await _wait(3.2)
	await _shot(level + "_result")
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)
