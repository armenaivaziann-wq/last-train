extends GameScreen
## Журнал расследования. Вкладки: Подозреваемые, Улики, Хронология, Диалоги, Итог дела.
## Факты, неподтверждённые показания и догадки игрока разделены визуально. Выводы
## игрок делает сам, сопоставляя пары улик; ответ журнал не подсказывает.

const TABS: Array = [["suspects", "Подозреваемые", "passenger"], ["clues", "Улики", "magnifier"],
	["timeline", "Хронология", "clock"], ["dialogues", "Диалоги", "talk"], ["verdict", "Итог дела", "siren"]]
const STATUS: Dictionary = {
	"fact": ["Факт", Color("#4ae08a")], "deduction": ["Вывод", Color("#ffe14a")],
	"unconfirmed": ["Не подтверждено", Color("#aaa6dc")], "confirmed": ["Подтверждено", Color("#5ad6ff")],
	"refuted": ["Опровергнуто", Color("#ff4a6a")],
}
const FILTERS: Array = [["", "Все"], ["document", "Документы"], ["physical", "Следы"], ["item", "Предметы"],
	["camera", "Записи"], ["testimony", "Показания"], ["contradiction", "Выводы"]]

var inv: InvestigationManager
var _tab: String = "suspects"
var _tab_buttons: Dictionary = {}
var _content: MarginContainer
var _time_pill: Label
# состояние вкладок
var _suspect: String = ""
var _filter: String = ""
var _selected: Array[String] = []
var _verdict_suspect: String = ""
var _verdict_clues: Array[String] = []
var _monster_guess: String = ""
var _motive: int = -1
var _method: int = -1
var _hint_label: Label
var _hint_btn: Button
var _verify_result: Dictionary = {}


func build(args: Dictionary) -> void:
	inv = game.investigation
	var tab_arg: String = str(args.get("tab", ""))
	if tab_arg.begins_with("verdict:"):
		_tab = "verdict"
		_verdict_suspect = tab_arg.substr(8)
	elif tab_arg != "":
		_tab = tab_arg
	var root := Ui.panel()
	var col := Ui.vbox(12)
	var head := Ui.header("Журнал расследования", "journal", close)
	var tp: Array = Ui.pill("hourglass", "", 26)
	_time_pill = tp[1]
	head.add_child(tp[0])
	head.move_child(tp[0], 2)
	var hint_btn := Ui.button(_hint_caption(), "question", "PurpleButton", _show_hint, 52)
	hint_btn.disabled = inv.hints_left() <= 0
	_hint_btn = hint_btn
	hint_btn.tooltip_text = "Подсказки помогают думать, но снижают итоговый рейтинг"
	head.add_child(hint_btn)
	head.move_child(hint_btn, 3)
	# Камеры — отсюда (кнопки на главном экране нет, чтобы не перегружать его).
	if game and game.has_method("open_cameras"):
		var cam_btn := Ui.button("Камеры", "cctv", "CyanButton", func() -> void:
			close()
			game.open_cameras(), 52)
		head.add_child(cam_btn)
		head.move_child(cam_btn, 4)
	col.add_child(head)
	_hint_label = Ui.label("", "", 18, true)
	_hint_label.add_theme_color_override("font_color", Color("#e8d8ff"))
	_hint_label.visible = false
	col.add_child(_hint_label)
	var tabs := Ui.hbox(8)
	for t: Array in TABS:
		var b := Ui.button(t[1], t[2], "TabButton", func() -> void: _switch(t[0]), 54)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		_tab_buttons[t[0]] = b
	col.add_child(tabs)
	_content = Ui.margin(0, 4, 0, 0)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_content)
	root.add_child(col)
	safe_margin(root, 30, 18)
	_switch(_tab)


func refresh() -> void:
	_switch(_tab)


func _switch(tab: String) -> void:
	_tab = tab
	for k: String in _tab_buttons:
		_tab_buttons[k].set_pressed_no_signal(k == tab)
	_time_pill.text = "До станции: %d мин" % int(ceil(inv.minutes_left()))
	Ui.clear(_content)
	match tab:
		"suspects":
			_build_suspects()
		"clues":
			_build_clues()
		"timeline":
			_build_timeline()
		"dialogues":
			_build_dialogues()
		"verdict":
			_build_verdict()


# --- Подозреваемые ----------------------------------------------------------------------
func _build_suspects() -> void:
	var row := Ui.hbox(18)
	var g := Ui.grid(4, 10)
	for id: String in inv.suspects.suspects:
		g.add_child(_suspect_card(id))
	var left := Ui.vbox(8)
	left.add_child(g)
	left.add_child(Ui.label("Пометки «подозреваю/доверяю» — ваши догадки, а не факты.", "SmallLabel", 16))
	row.add_child(left)
	var right := Ui.panel("CardPanel")
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_suspect_detail())
	row.add_child(right)
	_content.add_child(row)


func _suspect_card(id: String) -> Control:
	var b := Button.new()
	b.theme_type_variation = "PurpleButton" if id == _suspect else "ListButton"
	b.custom_minimum_size = Vector2(150, 176)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		_suspect = id
		AudioManager.play_sfx("click", -6.0)
		_switch("suspects"))
	var v := Ui.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	Ui.full_rect(v)
	var met: bool = inv.suspects.flag(id, "met")
	var ptex := Ui.tex(Db.portrait(id), 76)
	if not met:
		ptex.modulate = Color(0.55, 0.55, 0.75)
	v.add_child(ptex)
	var n := Ui.label(Db.char_name(id), "", 17)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(n)
	var icons := Ui.hbox(4)
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key: String in ["met", "docs", "luggage"]:
		var ic := Ui.icon({"met": "talk", "docs": "idcard", "luggage": "suitcase"}[key], 22)
		ic.modulate = Color.WHITE if inv.suspects.flag(id, key) else Color(1, 1, 1, 0.22)
		icons.add_child(ic)
	var mark: String = inv.suspects.mark(id)
	if mark != "":
		icons.add_child(Ui.icon("eye" if mark == "suspect" else "check", 22))
	v.add_child(icons)
	if inv.suspects.flag(id, "wrongly_accused"):
		v.add_child(Ui.chip("Невиновен", UiTheme.SUCCESS))
	if inv.murders.dead_at(id, inv.clock):
		v.add_child(Ui.chip("Погиб" + ("ла" if str(Db.character(id).get("gender", "m")) == "f" else ""), UiTheme.DANGER))
	b.add_child(v)
	return b


func _suspect_detail() -> Control:
	var v := Ui.vbox(10)
	if _suspect == "":
		v.add_child(Ui.label("Выберите пассажира слева, чтобы увидеть всё, что о нём известно.", "DimLabel", 20, true))
		return v
	var h := Ui.hbox(14)
	h.add_child(Ui.portrait(Db.portrait(_suspect), 96))
	var hv := Ui.vbox(4)
	hv.add_child(Ui.label(Db.char_name(_suspect), "HeaderLabel", 28))
	hv.add_child(Ui.label(str(Db.character(_suspect).get("role", "")), "GoldLabel", 19))
	h.add_child(hv)
	h.add_child(Ui.spacer())
	h.add_child(Ui.button("Задержать...", "siren", "DangerButton", func() -> void:
		_verdict_suspect = _suspect
		_switch("verdict"), 52))
	v.add_child(h)
	var list := Ui.vbox(8)
	var facts: Array[String] = []
	var said: Array[String] = []
	for id in inv.evidence.concerning(_suspect):
		if inv.evidence.status(id) in ["fact", "deduction"]:
			facts.append(id)
		else:
			said.append(id)
	var mine: Array[String] = []
	for cid: String in inv.evidence.links:
		if inv.evidence.links[cid] == _suspect:
			mine.append(cid)
	_section(list, "Факты и выводы", facts, "Пока ничего не установлено.")
	_section(list, "Показания (могут быть ложью)", said, "Пассажир ещё ничего не рассказал.")
	_section(list, "Мои догадки (улики, которые я связал с пассажиром)", mine, "Свяжите улики с пассажиром во вкладке «Улики».")
	v.add_child(Ui.scroll(list))
	return v


func _section(parent: VBoxContainer, title: String, ids: Array[String], empty: String) -> void:
	parent.add_child(Ui.label(title, "SubHeaderLabel", 21))
	if ids.is_empty():
		parent.add_child(Ui.label(empty, "SmallLabel", 17, true))
	for id in ids:
		parent.add_child(_clue_line(id))


func _clue_line(id: String) -> Control:
	var c: Dictionary = inv.evidence.clue(id)
	var h := Ui.hbox(8)
	h.add_child(Ui.icon(Ui.clue_icon(str(c["type"])), 26))
	var l := Ui.label(str(c["title"]), "", 18, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var st: Array = STATUS[inv.evidence.status(id)]
	h.add_child(Ui.chip(st[0], st[1]))
	return h


# --- Улики -------------------------------------------------------------------------------
func _build_clues() -> void:
	var v := Ui.vbox(10)
	var filters := Ui.hbox(8)
	for f: Array in FILTERS:
		var b := Ui.button(f[1], "", "ChipButton", func() -> void:
			_filter = f[0]
			_switch("clues"), 44)
		b.toggle_mode = true
		b.set_pressed_no_signal(_filter == f[0])
		b.add_theme_font_size_override("font_size", 18)
		filters.add_child(b)
	v.add_child(filters)
	var list := Ui.vbox(10)
	var shown: int = 0
	for id in inv.evidence.found:
		var c: Dictionary = inv.evidence.clue(id)
		if _filter != "" and c["type"] != _filter:
			continue
		list.add_child(_clue_card(id))
		shown += 1
	if shown == 0:
		list.add_child(Ui.label("Улик этого типа пока нет. Осматривайте вагоны, говорите с пассажирами, смотрите записи камер.", "DimLabel", 20, true))
	v.add_child(Ui.scroll(list))
	var bar := Ui.panel("GlassPanel")
	var bh := Ui.hbox(12)
	bh.add_child(Ui.icon("link", 36))
	var hint_text: String = "Выберите две улики и нажмите «Сопоставить», чтобы сделать вывод."
	if _selected.size() == 1:
		hint_text = "Выбрана: «%s». Выберите вторую." % inv.evidence.clue(_selected[0])["title"]
	elif _selected.size() == 2:
		hint_text = "«%s» + «%s»" % [inv.evidence.clue(_selected[0])["title"], inv.evidence.clue(_selected[1])["title"]]
	var hl := Ui.label(hint_text, "", 18, true)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(hl)
	var cmp := Ui.button("Сопоставить", "contradiction", "PrimaryButton", _compare, 56)
	cmp.disabled = _selected.size() != 2
	bh.add_child(cmp)
	bar.add_child(bh)
	v.add_child(bar)
	_content.add_child(v)


func _clue_card(id: String) -> Control:
	var c: Dictionary = inv.evidence.clue(id)
	var type: String = str(c["type"])
	var col: Color = Ui.clue_color(type)
	var selected: bool = id in _selected
	var p := PanelContainer.new()
	var bg: Color = Color("#2a1e66") if selected else UiTheme.CARD
	p.add_theme_stylebox_override("panel", UiTheme.sb(bg, UiTheme.PINK if selected else Color(col, 0.7), 3 if selected else 2, 14, Color.TRANSPARENT, 0, Vector4(12, 8, 12, 8)))
	var h := Ui.hbox(12)
	var sel := Button.new()
	sel.toggle_mode = true
	sel.button_pressed = selected
	sel.theme_type_variation = "ChipButton"
	sel.icon = Db.icon(Ui.clue_icon(type))
	sel.expand_icon = true
	sel.custom_minimum_size = Vector2(64, 64)
	sel.focus_mode = Control.FOCUS_NONE
	sel.tooltip_text = "Выбрать для сопоставления"
	sel.pressed.connect(func() -> void: _toggle_select(id))
	h.add_child(sel)
	var v := Ui.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := Ui.hbox(8)
	var title := Ui.label(str(c["title"]), "", 21)
	title.add_theme_color_override("font_color", col.lightened(0.25))
	top.add_child(title)
	if c.has("time"):
		top.add_child(Ui.chip(str(c["time"]), UiTheme.CYAN, "clock"))
	top.add_child(Ui.chip(UiTheme.CLUE_TYPE_NAMES.get(type, type), col))
	var st: Array = STATUS[inv.evidence.status(id)]
	top.add_child(Ui.chip(st[0], st[1]))
	if ProgressionManager.equipment_level("notebook") >= 2 and _selected.size() == 1 and _selected[0] != id and c.has("time"):
		var other: Dictionary = inv.evidence.clue(_selected[0])
		if other.has("time") and absf(Db.parse_time(str(other["time"])) - Db.parse_time(str(c["time"]))) <= 2.0:
			top.add_child(Ui.chip("то же время", UiTheme.PINK, "hourglass"))
	v.add_child(top)
	var text := Ui.label(str(c["text"]), "", 18, true)
	text.custom_minimum_size.x = 700
	v.add_child(text)
	h.add_child(v)
	var link := OptionButton.new()
	link.add_item("Связать с: —")
	link.set_item_metadata(0, "")
	var cur: String = str(inv.evidence.links.get(id, ""))
	var i: int = 1
	for s: String in inv.suspects.suspects:
		link.add_item(Db.char_name(s))
		link.set_item_metadata(i, s)
		if s == cur:
			link.select(i)
		i += 1
	link.custom_minimum_size = Vector2(230, 52)
	link.focus_mode = Control.FOCUS_NONE
	link.item_selected.connect(func(idx: int) -> void: inv.evidence.link(id, str(link.get_item_metadata(idx))))
	h.add_child(link)
	p.add_child(h)
	return p


func _toggle_select(id: String) -> void:
	if id in _selected:
		_selected.erase(id)
	else:
		_selected.append(id)
		if _selected.size() > 2:
			_selected.pop_front()
	_switch("clues")


func _compare() -> void:
	if _selected.size() != 2:
		return
	var res: String = inv.deduce(_selected[0], _selected[1])
	if res == "":
		AudioManager.play_sfx("wrong", -8.0)
		var cost: float = float(inv.profile.get("wrong_link_cost", 0.0))
		if cost > 0.0:
			# Перебор пар наугад стоит времени — связь нужно найти логикой.
			inv.advance(cost)
			Events.notify("Эти улики никак не связаны. Ложный след отнял %s мин." % str(snappedf(cost, 0.01)), "question")
		else:
			Events.notify("Эти улики никак не связаны между собой.", "question")
	elif res == "known":
		Events.notify("Этот вывод уже есть в журнале.", "journal")
	else:
		game.player.play_action("note", 0.8)
	_selected.clear()
	_switch("clues")


# --- Хронология --------------------------------------------------------------------------
var _board_mode: bool = false
var _board_report: Dictionary = {}


func _build_timeline() -> void:
	var mode := Ui.hbox(8)
	var b1 := Ui.button("Хронология улик", "clock", "PurpleButton" if not _board_mode else "ChipButton", func() -> void:
		_board_mode = false
		_switch("timeline"), 48)
	var b2 := Ui.button("Доска передвижений", "map", "PurpleButton" if _board_mode else "ChipButton", func() -> void:
		_board_mode = true
		_switch("timeline"), 48)
	mode.add_child(b1)
	# Доска передвижений — с дел посложнее (Инспектор и выше), в первых делах только хронология.
	if int(inv.profile.get("level", 1)) >= 3:
		mode.add_child(b2)
	else:
		_board_mode = false
	var wrap := Ui.vbox(8)
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(mode)
	if _board_mode:
		wrap.add_child(_build_board())
		_content.add_child(wrap)
		return
	var items: Array = []
	for id in inv.evidence.found:
		var c: Dictionary = inv.evidence.clue(id)
		if c.has("time"):
			items.append([Db.parse_time(str(c["time"])), id])
	items.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var list := Ui.vbox(6)
	if items.is_empty():
		list.add_child(Ui.label("Улик со временем пока нет. Записи камер, чеки и показания помогут восстановить события.", "DimLabel", 20, true))
	for it: Array in items:
		var row := Ui.hbox(14)
		var tl := Ui.label(Db.format_time(it[0]), "NumberLabel", 22)
		tl.custom_minimum_size.x = 80
		row.add_child(tl)
		var dot := ColorRect.new()
		dot.color = Ui.clue_color(str(inv.evidence.clue(it[1])["type"]))
		dot.custom_minimum_size = Vector2(6, 40)
		row.add_child(dot)
		var line := _clue_line(it[1])
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(line)
		list.add_child(row)
	var now := Ui.panel("HighlightPanel")
	now.add_child(Ui.label("Сейчас %s · прибытие в %s в %s" % [Db.format_time(inv.clock), game.case_data["station_to"], game.case_data["arrival"]], "GoldLabel", 20))
	list.add_child(now)
	var sc := Ui.scroll(list)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(sc)
	_content.add_child(wrap)


## Доска передвижений: строки — подозреваемые, столбцы — пятиминутки 01:30–02:00, в клетке —
## вагон, где, по мнению игрока, был человек. «Проверить» сверяет доску с алиби из показаний.
func _build_board() -> Control:
	var v := Ui.vbox(6)
	v.add_child(Ui.label("Расставьте подозреваемых по вагонам по показаниям, записям и уликам. Проверка найдёт, чьё алиби не сходится.", "DimLabel", 16, true))
	var grid := GridContainer.new()
	grid.columns = InvestigationManager.BOARD_SLOTS + 1
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	grid.add_child(Ui.label("", "", 14))
	for k in InvestigationManager.BOARD_SLOTS:
		grid.add_child(Ui.label(Db.format_time(InvestigationManager.BOARD_FROM + k * InvestigationManager.BOARD_SLOT), "NumberLabel", 16))
	var cars: Array = inv.layout.carriage_ids
	for npc: String in inv.suspects.suspects:
		if inv.state_of(npc) == "dead":
			continue
		var nl := Ui.label(Db.char_name(npc), "GoldLabel" if _board_report.get("conflicts", {}).has(npc) else "", 16)
		nl.custom_minimum_size.x = 170
		if _board_report.get("conflicts", {}).has(npc):
			nl.add_theme_color_override("font_color", UiTheme.DANGER)
		elif npc in _board_report.get("empty", []):
			nl.add_theme_color_override("font_color", UiTheme.GOLD)
		grid.add_child(nl)
		for k in InvestigationManager.BOARD_SLOTS:
			var opt := OptionButton.new()
			opt.add_item("?")
			opt.set_item_metadata(0, "")
			var cur: String = str(inv.board.get(npc, {}).get(str(k), ""))
			for i in cars.size():
				opt.add_item(inv.layout.carriage_name(cars[i]).left(9))
				opt.set_item_metadata(i + 1, cars[i])
				if cars[i] == cur:
					opt.select(i + 1)
			opt.custom_minimum_size = Vector2(118, 40)
			opt.focus_mode = Control.FOCUS_NONE
			opt.fit_to_longest_item = false
			var slot: int = k
			opt.item_selected.connect(func(idx: int) -> void: inv.board_set(npc, slot, str(opt.get_item_metadata(idx))))
			grid.add_child(opt)
	var sc := Ui.scroll(grid)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size.y = 300
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var cost: float = Db.action_cost(inv.profile, "timeline_check")
	var row := Ui.hbox(10)
	row.add_child(Ui.button("Проверить доску" + ("  · %s мин" % str(cost) if cost > 0.0 else ""), "verify", "PrimaryButton", _check_board, 52))
	v.add_child(row)
	for npc: String in _board_report.get("conflicts", {}):
		v.add_child(Ui.label("Противоречие! " + str(_board_report["conflicts"][npc]), "", 16, true))
	for npc: String in _board_report.get("unproven", {}):
		v.add_child(Ui.label(str(_board_report["unproven"][npc]), "DimLabel", 15, true))
	for npc in _board_report.get("empty", []):
		v.add_child(Ui.label("%s: есть показание об алиби, но промежуток на доске пуст." % Db.char_name(str(npc)), "SmallLabel", 15, true))
	for id in _board_report.get("gained", []):
		v.add_child(Ui.label("Новый вывод: «%s»" % inv.evidence.clue(str(id))["title"], "GoldLabel", 17, true))
	return v


func _check_board() -> void:
	inv.spend_time(Db.action_cost(inv.profile, "timeline_check"))
	_board_report = inv.check_board()
	AudioManager.play_sfx("wrong" if _board_report["conflicts"].is_empty() else "success", -8.0)
	_switch("timeline")


# --- Диалоги -----------------------------------------------------------------------------
func _build_dialogues() -> void:
	var list := Ui.vbox(10)
	var full: bool = ProgressionManager.equipment_level("recorder") > 0
	if not full:
		list.add_child(Ui.label("Без диктофона в блокноте только начало ответов. Диктофон сохраняет цитаты целиком.", "SmallLabel", 17, true))
	if inv.dialogue.log.is_empty():
		list.add_child(Ui.label("Вы ещё ни с кем не говорили.", "DimLabel", 20))
	for e: Dictionary in inv.dialogue.log:
		var p := Ui.panel("CardPanel")
		var h := Ui.hbox(12)
		h.add_child(Ui.tex(Db.portrait(str(e["who"])), 56))
		var v := Ui.vbox(4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(Ui.label("%s — «%s»" % [Db.char_name(str(e["who"])), e["q"]], "GoldLabel", 19))
		var answer: Array = e["a"]
		var text: String = " ".join(PackedStringArray(answer)) if full else str(answer[0]) + (" …" if answer.size() > 1 else "")
		var a := Ui.label(text, "", 18, true)
		a.custom_minimum_size.x = 900
		v.add_child(a)
		h.add_child(v)
		p.add_child(h)
		list.add_child(p)
	_content.add_child(Ui.scroll(list))


# --- Итог дела: доска обвинения ----------------------------------------------------------
## Игрок сам заполняет доску: 1) КТО, 2) КАК, 3) КАКОЙ МОНСТР, 4) три ключевые улики.
## Ключевой считается только улика, связанная выводом («Сопоставить»), — разрозненные
## улики без вывода в доказательство не идут. Оценка: всё верно — ★★★; «кто» и «монстр» —
## ★★; только «кто» — ★ («суд такое не примет»); неверный «кто» — ошибка, вторая — побег.
func _build_verdict() -> void:
	var v := Ui.vbox(8)
	v.add_child(Ui.label("1. КТО это сделал?", "SubHeaderLabel", 21))
	var who := Ui.hbox(8)
	for id: String in inv.suspects.suspects:
		var b := Button.new()
		b.theme_type_variation = "PurpleButton" if id == _verdict_suspect else "ListButton"
		b.icon = Db.portrait(id)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(84, 84)
		b.tooltip_text = Db.char_name(id)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = inv.suspects.flag(id, "wrongly_accused") or inv.murders.dead_at(id, inv.clock) or inv.state_of(id) == "dead"
		b.pressed.connect(func() -> void:
			_verdict_suspect = id
			_verify_result.clear()
			_switch("verdict"))
		who.add_child(b)
	v.add_child(who)
	if _verdict_suspect != "":
		v.add_child(Ui.label("Подозреваемый: " + Db.char_name(_verdict_suspect), "GoldLabel", 20))
	var row := Ui.hbox(18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := Ui.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var proven: int = inv.proven_against(_verdict_suspect, _verdict_clues).size() if _verdict_suspect != "" else 0
	left.add_child(Ui.label("4. ТРИ КЛЮЧЕВЫЕ УЛИКИ: %d/3 (доказано: %d)" % [_verdict_clues.size(), proven], "SubHeaderLabel", 21))
	left.add_child(Ui.label("Ключевой считается только улика, связанная выводом в журнале («Сопоставить»). Разрозненные улики суд не примет.", "DimLabel", 15, true))
	var list := Ui.vbox(6)
	var ordered: Array[String] = []
	for id in inv.evidence.found:
		if inv.is_proven(id):
			ordered.append(id)
	for id in inv.evidence.found:
		if not id in ordered:
			ordered.append(id)
	for id in ordered:
		var c: Dictionary = inv.evidence.clue(id)
		var cb := CheckBox.new()
		var linked: bool = inv.is_proven(id)
		cb.text = str(c["title"]) + ("" if linked else "   · не связана выводом")
		cb.icon = Db.icon("link" if linked else Ui.clue_icon(str(c["type"])))
		cb.expand_icon = false
		cb.add_theme_constant_override("icon_max_width", 26)
		cb.button_pressed = id in _verdict_clues
		cb.disabled = not linked
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(on: bool) -> void: _toggle_verdict_clue(id, on))
		if not linked:
			cb.modulate = Color(1, 1, 1, 0.55)
		if _verify_result.has(id):
			cb.text += "   — " + ("касается подозреваемого" if _verify_result[id] else "не связана с ним")
			cb.add_theme_color_override("font_color", UiTheme.SUCCESS if _verify_result[id] else UiTheme.DANGER)
		list.add_child(cb)
	if ordered.is_empty():
		list.add_child(Ui.label("Сначала найдите улики.", "DimLabel"))
	left.add_child(Ui.scroll(list))
	row.add_child(left)
	var right := Ui.vbox(8)
	right.custom_minimum_size.x = 400
	var vd: Dictionary = game.case_data.get("verdict", {})
	if not vd.is_empty():
		right.add_child(_choice("2. КАК он это сделал?", vd.get("methods", []), _method, func(i: int) -> void: _method = i))
	right.add_child(Ui.label("3. КАКОЙ ЭТО МОНСТР?", "SubHeaderLabel", 20))
	var opt := OptionButton.new()
	opt.add_item("Не знаю")
	opt.set_item_metadata(0, "")
	var i: int = 1
	for mid: String in Db.monsters:
		if Db.monster(mid).get("legacy", false):
			continue
		opt.add_item(str(Db.monster(mid)["name"]))
		opt.set_item_metadata(i, mid)
		if mid == _monster_guess:
			opt.select(i)
		i += 1
	opt.custom_minimum_size = Vector2(0, 52)
	opt.focus_mode = Control.FOCUS_NONE
	opt.item_selected.connect(func(idx: int) -> void: _monster_guess = str(opt.get_item_metadata(idx)))
	right.add_child(opt)
	right.add_child(Ui.label("★★★ — верно всё и три доказанные улики · ★★ — верны «кто» и «монстр» · ★ — верен только «кто».", "SmallLabel", 15, true))
	right.add_child(Ui.spacer(false, true))
	var arrest := Ui.button("Задержать", "siren", "DangerButton", _confirm_arrest, 62)
	arrest.disabled = _verdict_suspect == ""
	right.add_child(arrest)
	var vc: float = Db.action_cost(inv.profile, "verify")
	var verify := Ui.button("Проверить улики · %s мин (%d)" % [str(vc), inv.verifications_left], "verify", "CyanButton", _verify, 56)
	verify.disabled = _verdict_suspect == "" or _verdict_clues.is_empty() or inv.verifications_left <= 0
	verify.tooltip_text = "Проводница сверит, касаются ли выбранные улики подозреваемого."
	right.add_child(verify)
	right.add_child(Ui.button("Продолжить расследование", "back", "GhostButton", close, 52))
	var left_m: int = inv.max_mistakes() - inv.mistakes
	right.add_child(Ui.label("Права на ошибку: %d. Ошибка: −%d репутации, −%s мин. После второй ошибки монстр сбежит." % [left_m, InvestigationManager.WRONG_REPUTATION, str(snappedf(inv.wrong_penalty(), 0.1))], "SmallLabel", 15, true))
	row.add_child(right)
	v.add_child(row)
	_content.add_child(v)


## Выпадающий выбор (мотив / способ).
func _choice(title: String, options: Array, current: int, on_pick: Callable) -> Control:
	var v := Ui.vbox(4)
	v.add_child(Ui.label(title, "SubHeaderLabel", 20))
	var opt := OptionButton.new()
	opt.add_item("Не выбрано")
	for o in options:
		opt.add_item(str(o))
	opt.select(current + 1)
	opt.custom_minimum_size = Vector2(0, 50)
	opt.focus_mode = Control.FOCUS_NONE
	opt.fit_to_longest_item = false
	opt.item_selected.connect(func(idx: int) -> void: on_pick.call(idx - 1))
	v.add_child(opt)
	return v


func _hint_caption() -> String:
	return "Подсказка" if int(inv.profile.get("hints", 99)) >= 99 else "Подсказки: %d" % inv.hints_left()


func _show_hint() -> void:
	var h: Dictionary = inv.take_hint()
	_hint_btn.text = _hint_caption()
	_hint_btn.disabled = inv.hints_left() <= 0
	if h.is_empty():
		_hint_label.text = "Подсказки на это дело закончились. Дальше — только ваша логика."
		_hint_label.visible = true
		return
	_hint_label.text = "Подсказка %d/3 (взято: %d, рейтинг снижается): %s" % [int(h["level"]), inv.hints_used, h["text"]]
	_hint_label.visible = true
	AudioManager.play_sfx("magnifier", -6.0)


func _toggle_verdict_clue(id: String, on: bool) -> void:
	if on and not id in _verdict_clues:
		if _verdict_clues.size() >= 3:
			_verdict_clues.pop_front()
		_verdict_clues.append(id)
	elif not on:
		_verdict_clues.erase(id)
	_verify_result.clear()
	_switch("verdict")


func _verify() -> void:
	_verify_result = inv.verify(_verdict_suspect, _verdict_clues)
	AudioManager.play_sfx("camera_beep")
	_switch("verdict")


func _confirm_arrest() -> void:
	var dlg := ConfirmDialog.create("Задержать: %s?" % Db.char_name(_verdict_suspect),
		"Если пассажир невиновен, вы потеряете репутацию и время, а монстр насторожится.",
		"Задержать", "Подумать ещё")
	dlg.confirmed.connect(func() -> void:
		game.accuse(_verdict_suspect, _verdict_clues.duplicate(), _monster_guess, _motive, _method))
	add_child(dlg)
