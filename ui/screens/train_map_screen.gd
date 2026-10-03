extends GameScreen
## Карта поезда: схема вагонов (открытые, закрытые, будущие), где сейчас детектив и
## пассажиры, и прогресс поездки до станции.


func build(_args: Dictionary) -> void:
	var inv: InvestigationManager = game.investigation
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(1180, 0)
	var col := Ui.vbox(16)
	col.add_child(Ui.header("Карта поезда", "map", close))
	# прогресс поездки
	var trip := Ui.hbox(12)
	trip.add_child(Ui.label(str(game.case_data["station_from"]), "GoldLabel"))
	var bar := Ui.progress(inv.clock - inv.history_start, inv.arrival_time - inv.history_start, "CyanBar", 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trip.add_child(bar)
	trip.add_child(Ui.label("%s · %s" % [game.case_data["station_to"], game.case_data["arrival"]], "GoldLabel"))
	col.add_child(trip)
	# вагоны: сначала вагоны дела по порядку, затем остальные из прогрессии
	var cars := Ui.hbox(10)
	var current: String = game.layout.carriage_at(game.player.global_position.x)
	var shown: Array[String] = []
	for cid in game.layout.carriage_ids:
		cars.add_child(_car_card(cid, true, cid == current))
		shown.append(cid)
	for c: Dictionary in Db.prog_list("carriages"):
		if not str(c["id"]) in shown:
			cars.add_child(_car_card(str(c["id"]), false, false))
	col.add_child(Ui.scroll(cars, true))
	col.get_child(col.get_child_count() - 1).custom_minimum_size.y = 330
	col.add_child(Ui.label("Пассажиры перемещаются по поезду. Нажмите J, чтобы открыть журнал, C — камеры.", "SmallLabel", 17))
	p.add_child(col)
	add_child(Ui.center(p))


func _car_card(cid: String, in_case: bool, here: bool) -> Control:
	var prog: Dictionary = Db.prog_item("carriages", cid)
	var name: String = game.layout.carriage_name(cid) if in_case else str(prog.get("name", cid))
	var card := PanelContainer.new()
	var border: Color = UiTheme.PINK if here else (UiTheme.BORDER if in_case else UiTheme.BORDER_DIM)
	card.add_theme_stylebox_override("panel", UiTheme.sb(UiTheme.CARD if in_case else Color(UiTheme.INSET, 0.8), border, 3 if here else 2, 14, Color.TRANSPARENT, 0, Vector4(10, 8, 10, 8)))
	card.custom_minimum_size = Vector2(150 if cid != "vestibule" else 110, 300)
	var v := Ui.vbox(6)
	v.add_child(Ui.icon(str(prog.get("icon", "train")) if not prog.is_empty() else "train", 40))
	var nl := Ui.label(name, "", 17, true)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nl)
	if here:
		v.add_child(Ui.chip("Вы здесь", UiTheme.PINK, "passenger"))
	if in_case:
		var g := Ui.grid(2, 4)
		for id: String in game.npcs:
			var npc: NPCController = game.npcs[id]
			if game.layout.carriage_at(npc.global_position.x) == cid:
				var t := Ui.tex(Db.portrait(id), 48)
				t.tooltip_text = Db.char_name(id)
				t.mouse_filter = Control.MOUSE_FILTER_PASS
				g.add_child(t)
		v.add_child(g)
	elif ProgressionManager.has_carriage(cid):
		v.add_child(Ui.chip("Открыт", UiTheme.SUCCESS))
		v.add_child(Ui.label(str(prog.get("mechanic", "")), "SmallLabel", 14, true))
	else:
		v.add_child(Ui.icon("lock", 32))
		v.add_child(Ui.label("Откройте в «Развитии поезда»", "SmallLabel", 14, true))
	card.add_child(v)
	return card
