extends GameScreen
## Задания и события: ежедневные, еженедельные и сезонное событие.

var _content: VBoxContainer


func build(_args: Dictionary) -> void:
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(1000, 0)
	var col := Ui.vbox(12)
	col.add_child(Ui.header("Задания и события", "quest", close))
	_content = Ui.vbox(10)
	col.add_child(Ui.scroll(_content))
	p.add_child(col)
	safe_margin(p, 60, 24)
	refresh()


func refresh() -> void:
	Ui.clear(_content)
	for key: Array in [["daily", "Ежедневные задания"], ["weekly", "Еженедельные задания"]]:
		_content.add_child(Ui.label(key[1], "SubHeaderLabel", 24))
		for q: Dictionary in ProgressionManager.quest_entries(key[0]):
			var h := Ui.hbox(12)
			h.add_child(Ui.icon("quest", 36))
			var v := Ui.vbox(2)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(Ui.label("%s  (%d/%d)" % [q["text"], int(q["progress"]), int(q["goal"])], "", 19))
			v.add_child(Ui.progress(int(q["progress"]), int(q["goal"]), "CyanBar", 12))
			h.add_child(v)
			if q["claimed"]:
				h.add_child(Ui.chip("Получено", UiTheme.SUCCESS, "check"))
			else:
				var reward: String = "+%d" % int(q.get("coins", 0))
				var b := Ui.button(reward, "coin", "PrimaryButton", func() -> void:
					ProgressionManager.claim_quest(key[0], q["id"])
					AudioManager.play_sfx("quest")
					refresh(), 50)
				b.disabled = int(q["progress"]) < int(q["goal"])
				h.add_child(b)
			_content.add_child(h)
	_content.add_child(Ui.label("События", "SubHeaderLabel", 24))
	var events: Array = ProgressionManager.active_events()
	if events.is_empty():
		_content.add_child(Ui.label("Сейчас событий нет.", "DimLabel", 19))
	for ev: Dictionary in events:
		var card := Ui.panel("HighlightPanel")
		var v := Ui.vbox(6)
		v.add_child(Ui.label("%s · до %s" % [ev["name"], ev["to"]], "GoldLabel", 22))
		v.add_child(Ui.label(str(ev["description"]), "", 18, true))
		var prog: int = mini(ProgressionManager.event_progress(ev["id"]), int(ev["task"]["goal"]))
		v.add_child(Ui.label("%s: %d/%d" % [ev["task"]["text"], prog, int(ev["task"]["goal"])], "", 18))
		v.add_child(Ui.progress(prog, int(ev["task"]["goal"]), "PurpleBar", 12))
		if ProgressionManager.event_claimed(ev["id"]):
			v.add_child(Ui.chip("Награда получена", UiTheme.SUCCESS, "check"))
		else:
			var b := Ui.button("Забрать награду", "event", "PrimaryButton", func() -> void:
				ProgressionManager.claim_event(ev["id"])
				refresh(), 50)
			b.disabled = prog < int(ev["task"]["goal"])
			v.add_child(b)
		card.add_child(v)
		_content.add_child(card)
