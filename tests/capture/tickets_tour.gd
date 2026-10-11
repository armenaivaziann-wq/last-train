extends Node
## Визуальная проверка блока 3: билеты в главном меню и окно «Билеты закончились».

func _ready() -> void:
	SaveManager.enabled = false
	SaveManager.profile = SaveManager.default_profile()
	SaveManager.profile["campaign"]["unlocked"] = 5
	Tickets.clock_override = 1_800_000_000
	SaveManager.profile["tickets"] = {"count": 2, "ts": 1_800_000_000 - 6 * 60 - 47, "full": false}
	DirAccess.make_dir_recursive_absolute("/tmp/lt_tickets")
	var menu: Control = load("res://ui/screens/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().create_timer(0.8).timeout
	await _shot("1_menu_tickets")
	for i in 2:
		Tickets.spend_for_loss("level_04")
	menu.ui.open("route_map_screen")
	await get_tree().create_timer(0.4).timeout
	menu.ui.top()._start("level_04")
	await get_tree().create_timer(0.6).timeout
	await _shot("2_out_of_tickets")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/lt_tickets/%s.png" % name)
	print("shot ", name)
