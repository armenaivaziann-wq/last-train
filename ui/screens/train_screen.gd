extends GameScreen
## Развитие поезда: открытие вагонов (каждый даёт новую механику) и улучшение
## оборудования детектива. Улучшения добавляют способы расследования, а не раскрывают ответ.

var _content: VBoxContainer
var _coins: Label


func build(_args: Dictionary) -> void:
	var p := Ui.panel()
	var col := Ui.vbox(14)
	var head := Ui.header("Развитие поезда", "train", close)
	var c: Array = Ui.pill("coin", "0", 28)
	_coins = c[1]
	head.add_child(c[0])
	head.move_child(c[0], 2)
	col.add_child(head)
	_content = Ui.vbox(14)
	col.add_child(Ui.scroll(_content))
	p.add_child(col)
	safe_margin(p, 30, 18)
	refresh()


func refresh() -> void:
	_coins.text = str(EconomyManager.coins())
	Ui.clear(_content)
	_content.add_child(Ui.label("Вагоны", "SubHeaderLabel", 26))
	var cars := Ui.hbox(12)
	for c: Dictionary in Db.prog_list("carriages"):
		cars.add_child(_car_card(c))
	_content.add_child(Ui.scroll(cars, true))
	_content.get_child(_content.get_child_count() - 1).custom_minimum_size.y = 330
	_content.add_child(Ui.label("Оборудование детектива", "SubHeaderLabel", 26))
	var g := Ui.grid(3, 12)
	for e: Dictionary in Db.prog_list("equipment"):
		g.add_child(_equip_card(e))
	_content.add_child(g)


func _car_card(c: Dictionary) -> Control:
	var id: String = str(c["id"])
	var owned: bool = ProgressionManager.has_carriage(id)
	var card := Ui.panel("CardPanel" if not owned else "HighlightPanel")
	card.custom_minimum_size = Vector2(230, 310)
	var v := Ui.vbox(8)
	var top := Ui.hbox(8)
	top.add_child(Ui.icon(str(c.get("icon", "train")), 44))
	var nl := Ui.label(str(c["name"]), "", 19, true)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nl)
	v.add_child(top)
	var d := Ui.label(str(c["description"]), "DimLabel", 16, true)
	v.add_child(d)
	var m := Ui.label(str(c["mechanic"]), "", 16, true)
	m.add_theme_color_override("font_color", UiTheme.CYAN)
	v.add_child(m)
	v.add_child(Ui.spacer(false, true))
	if owned:
		v.add_child(Ui.chip("Открыт" + (" · играбелен" if c.get("playable", false) else ""), UiTheme.SUCCESS, "check"))
	else:
		var reason: String = ProgressionManager.carriage_unlock_check(id)
		var rep: int = int(c.get("reputation", 0))
		if rep > 0:
			v.add_child(Ui.chip("Репутация %d" % rep, UiTheme.GOLD if EconomyManager.reputation() >= rep else UiTheme.DANGER, "reputation"))
		var b := Ui.button("Открыть · %d" % int(c.get("cost", 0)), "coin", "PrimaryButton", func() -> void: _unlock(id), 52)
		b.disabled = reason != ""
		b.tooltip_text = reason
		v.add_child(b)
	card.add_child(v)
	return card


func _equip_card(e: Dictionary) -> Control:
	var id: String = str(e["id"])
	var lvl: int = ProgressionManager.equipment_level(id)
	var mx: int = int(e["max"])
	var card := Ui.panel("CardPanel")
	card.custom_minimum_size = Vector2(380, 0)
	var v := Ui.vbox(6)
	var top := Ui.hbox(10)
	top.add_child(Ui.icon(str(e["icon"]), 44))
	var tv := Ui.vbox(2)
	tv.add_child(Ui.label(str(e["name"]), "", 21))
	var pips := Ui.hbox(4)
	for i in mx:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(26, 8)
		pip.color = UiTheme.GOLD if i < lvl else Color(UiTheme.BORDER_DIM, 0.8)
		pips.add_child(pip)
	tv.add_child(pips)
	top.add_child(tv)
	v.add_child(top)
	var levels: Array = e["levels"]
	if lvl > 0:
		v.add_child(Ui.label("Сейчас: " + str(levels[lvl - 1]), "", 16, true))
	var cost: int = ProgressionManager.equipment_cost(id)
	if cost >= 0:
		var next := Ui.label(("Купить: " if lvl == 0 else "Далее: ") + str(levels[lvl]), "", 16, true)
		next.add_theme_color_override("font_color", UiTheme.CYAN)
		v.add_child(next)
		var b := Ui.button(("Купить" if lvl == 0 else "Улучшить") + " · %d" % cost, "coin", "PrimaryButton", func() -> void: _upgrade(id), 50)
		b.disabled = not EconomyManager.can_afford("coins", cost)
		v.add_child(b)
	else:
		v.add_child(Ui.chip("Максимальный уровень", UiTheme.SUCCESS, "star"))
	card.add_child(v)
	return card


func _unlock(id: String) -> void:
	if ProgressionManager.unlock_carriage(id):
		AudioManager.play_sfx("quest")
		Events.notify("Открыт вагон: " + str(Db.prog_item("carriages", id)["name"]), "train")
	refresh()


func _upgrade(id: String) -> void:
	if ProgressionManager.upgrade_equipment(id):
		AudioManager.play_sfx("coin")
	refresh()
