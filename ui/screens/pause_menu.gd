extends GameScreen
## Пауза: продолжить, настройки, подсказка по управлению, сохранить и выйти в меню.


func build(_args: Dictionary) -> void:
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(560, 0)
	var v := Ui.vbox(14)
	var t := Ui.label("Пауза", "TitleLabel", 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if game:
		var info := Ui.label("«%s» · до станции %d мин" % [game.case_data["title"], int(ceil(game.investigation.minutes_left()))], "DimLabel", 19, true)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(info)
	v.add_child(Ui.button("Продолжить", "play", "PrimaryButton", close, 64))
	v.add_child(Ui.button("Настройки", "gear", "", func() -> void: ui.open("settings_screen"), 60))
	v.add_child(Ui.button("Как играть", "question", "", func() -> void: ui.open("help_screen"), 60))
	if game:
		v.add_child(Ui.button("Сохранить и выйти в меню", "home", "GhostButton", func() -> void: game.exit_to_menu(true), 60))
	p.add_child(v)
	add_child(Ui.center(p))
	if game:
		game.autosave()
