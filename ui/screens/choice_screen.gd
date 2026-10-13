extends GameScreen
## Сюжетный выбор: герою что-то предлагают (напиток, сделку). Два крупных варианта,
## выбор необратим. Окно нельзя закрыть «назад» — только выбрать.

var _fx: Dictionary


func build(args: Dictionary) -> void:
	_fx = args["fx"]
	closable = false
	var panel := Ui.panel()
	panel.custom_minimum_size = Vector2(820, 0)
	var row := Ui.hbox(18)
	var who: String = str(_fx.get("npc", ""))
	if who != "":
		row.add_child(Ui.portrait(Db.portrait(who), 150))
	var v := Ui.vbox(12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Ui.label(str(_fx.get("title", "Предложение")), "SubHeaderLabel", 28))
	v.add_child(Ui.label(str(_fx.get("text", "")), "", 21, true))
	var hint: String = str(_fx.get("hint", ""))
	if hint != "":
		v.add_child(Ui.label(hint, "DimLabel", 17, true))
	var buttons := Ui.hbox(14)
	var yes := Ui.button(str(_fx.get("accept", "Согласиться")), "check", "PrimaryButton", func() -> void: _pick(true), 64)
	var no := Ui.button(str(_fx.get("refuse", "Отказаться")), "close", "GhostButton", func() -> void: _pick(false), 64)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(yes)
	buttons.add_child(no)
	v.add_child(buttons)
	row.add_child(v)
	panel.add_child(row)
	add_child(Ui.center(panel))


func _pick(accept: bool) -> void:
	game.investigation.choose(_fx, accept)
	var msg: String = str(_fx.get("accept_text" if accept else "refuse_text", ""))
	close()
	if msg != "":
		game.hud.show_banner(str(_fx.get("accept_title" if accept else "refuse_title", "")), msg, 4.0)
