extends Node
## Визуальная проверка: карта кампании с разными состояниями дел.

func _ready() -> void:
	SaveManager.enabled = false
	SaveManager.profile = SaveManager.default_profile()
	var c: Dictionary = SaveManager.profile["campaign"]
	var chapter2: bool = "--chapter2" in OS.get_cmdline_user_args()
	c["unlocked"] = 12 if chapter2 else 4
	c["stars"] = {"level_01": 3, "level_02": 2, "level_03": 1}
	if chapter2:
		for i in range(1, 12):
			c["stars"]["level_%02d" % i] = 2
	c["best_time"] = {"level_01": 9.5}
	var menu: Control = load("res://ui/screens/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().create_timer(0.4).timeout
	menu.ui.open("route_map_screen")
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("/tmp/lt_reveal")
	get_viewport().get_texture().get_image().save_png("/tmp/lt_reveal/campaign%s.png" % ("_ch2" if chapter2 else ""))
	print("shot campaign")
	get_tree().quit()
