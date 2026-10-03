extends GameScreen
## Осмотр багажа: открытый чемодан с вещами, справа — подробности выбранной вещи.
## Скрытые детали видны через лупу; потайные отделения находит сканер багажного вагона.

var _owner: String
var _items: Array = []
var _detail: VBoxContainer
var _grid: GridContainer
var _selected: int = -1
var _lens_on: bool = false


func build(args: Dictionary) -> void:
	_owner = str(args.get("id", ""))
	var inv: InvestigationManager = game.investigation
	var data: Dictionary = game.case_data["luggage"].get(_owner, {})
	for item: Dictionary in data.get("items", []):
		var req: String = str(item.get("requires_upgrade", ""))
		if req == "" or ProgressionManager.has_carriage(req):
			_items.append(item)
	if inv.suspects.set_flag(_owner, "luggage"):
		Events.add_stat("luggage")
	_lens_on = ProgressionManager.equipment_level("magnifier") >= 3
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(1140, 560)
	var col := Ui.vbox(14)
	col.add_child(Ui.header("Багаж: " + Db.char_name(_owner), "suitcase", close))
	var row := Ui.hbox(20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var case_panel := Ui.panel("SuitcasePanel")
	case_panel.custom_minimum_size = Vector2(560, 420)
	var cv := Ui.vbox(12)
	cv.add_child(Ui.label(str(data.get("title", "Багаж")), "GoldLabel", 22))
	_grid = Ui.grid(2, 12)
	cv.add_child(_grid)
	case_panel.add_child(cv)
	row.add_child(case_panel)
	var dp := Ui.panel("CardPanel")
	dp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail = Ui.vbox(12)
	dp.add_child(_detail)
	row.add_child(dp)
	col.add_child(row)
	p.add_child(col)
	add_child(Ui.center(p))
	AudioManager.play_sfx("door_open", -8.0, 1.4)
	_rebuild_grid()
	_show_detail()


func _rebuild_grid() -> void:
	Ui.clear(_grid)
	if _items.is_empty():
		_grid.add_child(Ui.label("Здесь только служебные вещи.", "DimLabel"))
		return
	for i in _items.size():
		var item: Dictionary = _items[i]
		var b := Ui.button(str(item["name"]), "item" if not item.has("hotspot") else "magnifier", "ListButton", func() -> void: _select(i), 74)
		b.custom_minimum_size.x = 260
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 19)
		if i == _selected:
			b.theme_type_variation = "PurpleButton"
		_grid.add_child(b)


func _select(i: int) -> void:
	_selected = i
	var item: Dictionary = _items[i]
	if item.has("on_open"):
		game.investigation.give(str(item["on_open"]))
	AudioManager.play_sfx("page", -8.0)
	_rebuild_grid()
	_show_detail()


func _show_detail() -> void:
	Ui.clear(_detail)
	if _selected < 0:
		_detail.add_child(Ui.label("Выберите вещь, чтобы рассмотреть её.", "DimLabel", 20, true))
		return
	var item: Dictionary = _items[_selected]
	_detail.add_child(Ui.label(str(item["name"]), "SubHeaderLabel"))
	var t := Ui.label(str(item.get("text", "")), "", 21, true)
	t.custom_minimum_size.x = 440
	_detail.add_child(t)
	if item.has("hotspot"):
		var h: Dictionary = item["hotspot"]
		if game.investigation.evidence.has(str(h["clue"])):
			var box := Ui.panel("HighlightPanel")
			var v := Ui.vbox(4)
			v.add_child(Ui.label(str(h["label"]), "GoldLabel", 19))
			var ht := Ui.label(str(h["text"]), "", 20, true)
			ht.custom_minimum_size.x = 420
			v.add_child(ht)
			box.add_child(v)
			_detail.add_child(box)
		else:
			var lens := Ui.button("Лупа (Q)", "magnifier", "CyanButton", _toggle_lens, 54)
			lens.toggle_mode = true
			lens.set_pressed_no_signal(_lens_on)
			_detail.add_child(lens)
			var b := Ui.button(str(h["label"]) + ("  — рассмотреть" if _lens_on else "  — слишком мелко"), "magnifier",
				"CyanButton" if _lens_on else "GhostButton", func() -> void: _inspect(h), 56)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_detail.add_child(b)


func _toggle_lens() -> void:
	_lens_on = not _lens_on
	if _lens_on:
		AudioManager.play_sfx("magnifier")
	_show_detail()


func _inspect(h: Dictionary) -> void:
	if not _lens_on:
		Events.notify("Слишком мелко. Включите лупу.", "magnifier")
		return
	game.investigation.give(str(h["clue"]))
	_show_detail()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"magnifier"):
		get_viewport().set_input_as_handled()
		_toggle_lens()
