extends GameScreen
## Настройки: громкость музыки, эффектов и фона (стук колёс, дождь), вибрация, сброс прогресса.


func build(_args: Dictionary) -> void:
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(700, 0)
	var v := Ui.vbox(16)
	v.add_child(Ui.header("Настройки", "gear", close))
	for s: Array in [["music", "Музыка", "music"], ["sfx", "Звуковые эффекты", "sound"], ["ambient", "Поезд и дождь", "train"]]:
		var row := Ui.hbox(14)
		row.add_child(Ui.icon(s[2], 36))
		var l := Ui.label(s[1], "", 22)
		l.custom_minimum_size.x = 250
		row.add_child(l)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(SaveManager.setting(s[0]))
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.y = 40
		slider.focus_mode = Control.FOCUS_NONE
		var key: String = s[0]
		slider.value_changed.connect(func(val: float) -> void:
			SaveManager.profile["settings"][key] = val
			AudioManager.apply_volumes())
		slider.drag_ended.connect(func(_c: bool) -> void:
			SaveManager.save_game()
			AudioManager.play_sfx("click"))
		row.add_child(slider)
		v.add_child(row)
	var vib := CheckButton.new()
	vib.text = "Вибрация при находке улики"
	vib.button_pressed = bool(SaveManager.setting("vibration"))
	vib.focus_mode = Control.FOCUS_NONE
	vib.toggled.connect(func(on: bool) -> void: SaveManager.set_setting("vibration", on))
	var vr := Ui.hbox(14)
	vr.add_child(Ui.icon("vibration", 36))
	vr.add_child(vib)
	v.add_child(vr)
	# Сложность: меняется в меню (в начатом деле правила уже действуют).
	var dr := Ui.hbox(10)
	dr.add_child(Ui.icon("badge", 36))
	var dl := Ui.label("Сложность", "", 22)
	dl.custom_minimum_size.x = 170
	dr.add_child(dl)
	var cur: String = str(SaveManager.setting("difficulty"))
	for m: Array in [["easy", "Лёгкий"], ["normal", "Нормальный"], ["detective", "Детектив"]]:
		var mode: String = m[0]
		var b := Ui.button(m[1], "", "PurpleButton" if mode == cur else "ChipButton", func() -> void:
			SaveManager.set_setting("difficulty", mode)
			AudioManager.play_sfx("click")
			close(), 50)
		b.disabled = game != null
		dr.add_child(b)
	v.add_child(dr)
	v.add_child(Ui.label({"easy": "Подсветка ключевых улик, камеры без слепых зон, подсказки бесплатные, действия стоят вдвое меньше времени.",
		"normal": "Слепые зоны камер, повреждённые записи, ложные следы, время на допросы и записи.",
		"detective": "Без подсказок и подсветки, ошибка обвинения стоит вдвое больше времени."}.get(cur, ""), "SmallLabel", 16, true))
	if game != null:
		v.add_child(Ui.label("Сложность меняется в главном меню — для следующего дела.", "DimLabel", 15, true))
	if game == null:
		var reset := Ui.button("Сбросить весь прогресс", "close", "DangerButton", _reset, 54)
		v.add_child(reset)
	v.add_child(Ui.button("Готово", "check", "PrimaryButton", close, 60))
	p.add_child(v)
	add_child(Ui.center(p))


func _reset() -> void:
	var d := ConfirmDialog.create("Сбросить прогресс?", "Монеты, вагоны, коллекции и задания будут удалены без возможности восстановления.", "Сбросить", "Отмена")
	d.confirmed.connect(func() -> void:
		SaveManager.reset_profile()
		AudioManager.apply_volumes()
		close())
	add_child(d)
