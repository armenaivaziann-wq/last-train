extends GameScreen
## Вводная к делу: проводница рассказывает о происшествии, затем — цель расследования.

var _brief: Dictionary
var _page: int = 0
var _text: Label
var _next: Button
var _goal_box: Control
var _tween: Tween


func build(args: Dictionary) -> void:
	closable = false
	_brief = args.get("brief", {})
	var speaker: String = str(_brief.get("speaker", "agata"))
	var root := Ui.hbox(24)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(980, 0)
	var row := Ui.hbox(26)
	var left := Ui.vbox(10)
	left.add_child(Ui.portrait(Db.portrait(speaker), 200))
	var name_l := Ui.label(Db.char_name(speaker), "SubHeaderLabel")
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(name_l)
	var role := Ui.label(str(Db.character(speaker).get("role", "")), "SmallLabel")
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(role)
	row.add_child(left)
	var right := Ui.vbox(16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Ui.label("Новое дело: «%s»" % (game.case_data["title"] if game else ""), "TitleLabel", 36)
	right.add_child(title)
	var route := Ui.label("%s → %s · прибытие в %s" % [game.case_data["station_from"], game.case_data["station_to"], game.case_data["arrival"]] if game else "", "GoldLabel", 20)
	right.add_child(route)
	_text = Ui.label("", "", 24, true)
	_text.custom_minimum_size = Vector2(620, 150)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	right.add_child(_text)
	_goal_box = Ui.panel("HighlightPanel")
	var gh := Ui.hbox(12)
	gh.add_child(Ui.icon("flag", 40))
	var gl := Ui.label(str(_brief.get("goal", "")), "", 20, true)
	gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gh.add_child(gl)
	_goal_box.add_child(gh)
	_goal_box.visible = false
	right.add_child(_goal_box)
	var btns := Ui.hbox(12)
	btns.add_child(Ui.spacer())
	_next = Ui.button("Далее", "arrow_right", "PrimaryButton", _on_next, 64)
	_next.custom_minimum_size.x = 260
	btns.add_child(_next)
	right.add_child(btns)
	row.add_child(right)
	p.add_child(row)
	root.add_child(p)
	add_child(Ui.center(root))
	_show_page()


func _show_page() -> void:
	var lines: Array = _brief.get("lines", [])
	if _page < lines.size():
		_text.text = str(lines[_page])
		_text.visible_ratio = 0.0
		if _tween:
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(_text, "visible_ratio", 1.0, 0.02 * _text.text.length())
		AudioManager.play_sfx("talk", -8.0)
	else:
		_text.text = "Пассажиры не покинут поезд до станции. Монстр — тоже."
		_text.visible_ratio = 1.0
		_goal_box.visible = true
		_next.text = "Начать расследование"
		_next.icon = Db.icon("magnifier")


func _on_next() -> void:
	if _text.visible_ratio < 1.0:
		if _tween:
			_tween.kill()
		_text.visible_ratio = 1.0
		return
	var lines: Array = _brief.get("lines", [])
	_page += 1
	if _page > lines.size():
		if game:
			game.investigation.give_all(_brief.get("gives", []))
		close()
		return
	_show_page()
