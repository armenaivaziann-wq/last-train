extends GameScreen
## Карточка пассажира: портрет, сведения и действия — поговорить, проверить документы,
## осмотреть багаж, задержать. Подозрительность не равна вине: пометки — только догадки игрока.

var _id: String
var _chips: HBoxContainer
var _mark_suspect: Button
var _mark_trust: Button


func build(args: Dictionary) -> void:
	_id = str(args.get("id", ""))
	var inv: InvestigationManager = game.investigation
	var npc: NPCController = game.npcs.get(_id)
	if npc:
		npc.talking_to = game.player
	ProgressionManager.meet(_id)
	var ch: Dictionary = Db.character(_id)
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(1060, 0)
	var col := Ui.vbox(14)
	col.add_child(Ui.header("Пассажир", "passenger", close))
	var row := Ui.hbox(26)

	var left := Ui.vbox(10)
	left.add_child(Ui.portrait(Db.portrait(_id), 188, Color(str(ch.get("color", "#4fd0ff"))).lightened(0.3)))
	_chips = Ui.hbox(6)
	left.add_child(_chips)
	row.add_child(left)

	var mid := Ui.vbox(10)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(Ui.label(Db.char_name(_id), "HeaderLabel", 34))
	mid.add_child(Ui.label(str(ch.get("role", "")), "GoldLabel"))
	var desc := Ui.label(str(ch.get("description", "")), "", 20, true)
	desc.custom_minimum_size.x = 440
	mid.add_child(desc)
	var pers := Ui.label("Характер: " + str(ch.get("personality", "")), "DimLabel", 18, true)
	mid.add_child(pers)
	var n: int = inv.evidence.concerning(_id).size()
	mid.add_child(Ui.label("Улик, связанных с пассажиром: %d" % n, "SmallLabel"))
	var marks := Ui.hbox(10)
	marks.add_child(Ui.label("Моя пометка:", "SmallLabel"))
	_mark_suspect = Ui.button("Подозреваю", "eye", "ChipButton", func() -> void: _set_mark("suspect"), 44)
	_mark_trust = Ui.button("Доверяю", "check", "ChipButton", func() -> void: _set_mark("trust"), 44)
	_mark_suspect.toggle_mode = true
	_mark_trust.toggle_mode = true
	marks.add_child(_mark_suspect)
	marks.add_child(_mark_trust)
	mid.add_child(marks)
	row.add_child(mid)

	var right := Ui.vbox(12)
	right.custom_minimum_size.x = 330
	var talk := Ui.button("Поговорить", "talk", "CyanButton", func() -> void: _action("talk"), 66)
	if inv.dialogue.has_new_topics(_id, inv.evidence):
		talk.text = "Поговорить  •  новое"
	right.add_child(talk)
	var docs := Ui.button("Проверить документы", "idcard", "", func() -> void: _action("docs"), 66)
	right.add_child(docs)
	var lug := Ui.button("Осмотреть багаж", "suitcase", "", func() -> void: _action("luggage"), 66)
	var lug_data: Dictionary = game.case_data["luggage"].get(_id, {})
	if lug_data.get("staff", false):
		lug.disabled = true
		lug.text = "Служебные вещи"
	right.add_child(lug)
	right.add_child(Ui.spacer(false, true))
	var arrest := Ui.button("Задержать...", "siren", "DangerButton", func() -> void: _action("accuse"), 66)
	right.add_child(arrest)
	row.add_child(right)
	col.add_child(row)
	p.add_child(col)
	add_child(Ui.center(p))
	refresh()


func refresh() -> void:
	var inv: InvestigationManager = game.investigation
	Ui.clear(_chips)
	var flags := {"met": ["Знакомы", "talk"], "docs": ["Документы", "idcard"], "luggage": ["Багаж", "suitcase"]}
	for key: String in flags:
		var on: bool = inv.suspects.flag(_id, key)
		_chips.add_child(Ui.chip(flags[key][0], UiTheme.SUCCESS if on else UiTheme.TEXT_DIM, flags[key][1]))
	var m: String = inv.suspects.mark(_id)
	_mark_suspect.set_pressed_no_signal(m == "suspect")
	_mark_trust.set_pressed_no_signal(m == "trust")


func _set_mark(m: String) -> void:
	var inv: InvestigationManager = game.investigation
	inv.suspects.set_mark(_id, "" if inv.suspects.mark(_id) == m else m)
	refresh()


func _action(kind: String) -> void:
	match kind:
		"talk":
			game.open_dialogue(_id)
		"docs":
			game.open_documents(_id)
		"luggage":
			game.open_luggage(_id)
		"accuse":
			game.open_journal("verdict:" + _id)


func close() -> void:
	var npc: NPCController = game.npcs.get(_id)
	if npc:
		npc.talking_to = null
	super.close()
