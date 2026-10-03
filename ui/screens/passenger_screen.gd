extends GameScreen
## Карточка пассажира: портрет, имя, профессия, короткое описание, индикатор улик и две
## главные кнопки — «Поговорить» и «Проверить» (документы / багаж). Остальное
## (пометки, задержание) — под кнопкой «Ещё». Подозрительность не равна вине.

var _id: String
var _check_box: HBoxContainer
var _more_box: VBoxContainer
var _mark_suspect: Button
var _mark_trust: Button
var _chips: HBoxContainer


func build(args: Dictionary) -> void:
	_id = str(args.get("id", ""))
	var inv: InvestigationManager = game.investigation
	var npc: NPCController = game.npcs.get(_id)
	if npc:
		npc.talking_to = game.player
	ProgressionManager.meet(_id)
	var ch: Dictionary = Db.character(_id)
	var accent: Color = Color(str(ch.get("color", "#4fd0ff"))).lightened(0.35)

	var p := Ui.panel()
	p.custom_minimum_size = Vector2(760, 0)
	var col := Ui.vbox(14)
	var row := Ui.hbox(22)
	row.add_child(Ui.portrait(Db.portrait(_id), 168, accent))
	var info := Ui.vbox(6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := Ui.hbox(8)
	var name_l := Ui.label(Db.char_name(_id), "HeaderLabel", 32)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	top.add_child(Ui.icon_button("close", 52, "GhostButton", close, "Закрыть"))
	info.add_child(top)
	info.add_child(Ui.label(str(ch.get("role", "")), "GoldLabel", 21))
	var desc := Ui.label(_short(str(ch.get("description", ""))), "", 19, true)
	desc.custom_minimum_size.x = 480
	info.add_child(desc)
	var ind := Ui.hbox(10)
	var n: int = inv.evidence.concerning(_id).size()
	ind.add_child(Ui.chip("Улик: %d" % n, UiTheme.GOLD if n > 0 else UiTheme.TEXT_DIM, "magnifier"))
	_chips = Ui.hbox(6)
	ind.add_child(_chips)
	info.add_child(ind)
	row.add_child(info)
	col.add_child(row)

	var main := Ui.hbox(14)
	var talk := Ui.button("Поговорить", "talk", "CyanButton", func() -> void: game.open_dialogue(_id), 70)
	talk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if inv.dialogue.has_new_topics(_id, inv.evidence):
		talk.text = "Поговорить  •"
	main.add_child(talk)
	var check := Ui.button("Проверить", "idcard", "PrimaryButton", _toggle_check, 70)
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(check)
	col.add_child(main)
	# Второстепенный пассажир (не подозреваемый): только разговор.
	var is_suspect: bool = _id in game.investigation.suspects.suspects
	check.visible = is_suspect

	_check_box = Ui.hbox(12)
	_check_box.visible = false
	var docs := Ui.button("Документы", "idcard", "", func() -> void: game.open_documents(_id), 58)
	docs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_check_box.add_child(docs)
	var lug := Ui.button("Багаж", "suitcase", "", func() -> void: game.open_luggage(_id), 58)
	lug.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if game.case_data["luggage"].get(_id, {}).get("staff", false):
		lug.disabled = true
		lug.text = "Служебные вещи"
	_check_box.add_child(lug)
	col.add_child(_check_box)

	var more := Ui.button("Ещё…", "", "GhostButton", func() -> void: _more_box.visible = not _more_box.visible, 44)
	more.add_theme_font_size_override("font_size", 18)
	more.visible = is_suspect
	col.add_child(more)
	_more_box = Ui.vbox(10)
	_more_box.visible = false
	var marks := Ui.hbox(10)
	marks.add_child(Ui.label("Моя пометка:", "SmallLabel", 17))
	_mark_suspect = Ui.button("Подозреваю", "eye", "ChipButton", func() -> void: _set_mark("suspect"), 46)
	_mark_trust = Ui.button("Доверяю", "check", "ChipButton", func() -> void: _set_mark("trust"), 46)
	_mark_suspect.toggle_mode = true
	_mark_trust.toggle_mode = true
	marks.add_child(_mark_suspect)
	marks.add_child(_mark_trust)
	marks.add_child(Ui.spacer())
	marks.add_child(Ui.button("Задержать…", "siren", "DangerButton", func() -> void: game.open_journal("verdict:" + _id), 50))
	_more_box.add_child(marks)
	col.add_child(_more_box)
	p.add_child(col)
	add_child(Ui.center(p))
	refresh()


## Первое предложение описания — без перегруза текстом.
static func _short(text: String) -> String:
	var i: int = text.find(". ")
	return text if i < 0 else text.substr(0, i + 1)


func _toggle_check() -> void:
	_check_box.visible = not _check_box.visible


func refresh() -> void:
	var inv: InvestigationManager = game.investigation
	Ui.clear(_chips)
	for key: String in ["docs", "luggage"]:
		if inv.suspects.flag(_id, key):
			_chips.add_child(Ui.chip({"docs": "Документы", "luggage": "Багаж"}[key], UiTheme.SUCCESS, "check"))
	var m: String = inv.suspects.mark(_id)
	_mark_suspect.set_pressed_no_signal(m == "suspect")
	_mark_trust.set_pressed_no_signal(m == "trust")


func _set_mark(m: String) -> void:
	var inv: InvestigationManager = game.investigation
	inv.suspects.set_mark(_id, "" if inv.suspects.mark(_id) == m else m)
	refresh()


func close() -> void:
	var npc: NPCController = game.npcs.get(_id)
	if npc:
		npc.talking_to = null
	super.close()
