extends GameScreen
## Проверка документов (билет и удостоверение) или осмотр объекта (журнал вагона, чек
## автомата, корзина). Мелкие детали видны только через лупу — она раскрывает факт,
## но не говорит, кто монстр.

var _owner: String = ""
var _object: String = ""
var _data: Dictionary
var _lens_on: bool = false
var _lens_btn: Button
var _details: VBoxContainer
var _hint: Label


func build(args: Dictionary) -> void:
	var inv: InvestigationManager = game.investigation
	_owner = str(args.get("id", ""))
	_object = str(args.get("object", ""))
	if _object != "":
		_data = game.case_data["objects"].get(_object, {})
	else:
		_data = game.case_data["documents"].get(_owner, {})
		if inv.suspects.set_flag(_owner, "docs"):
			Events.add_stat("docs")
	var title: String = str(_data.get("title", "Документы: " + Db.char_name(_owner)))
	if _owner != "" and not _data.has("title"):
		title = "Документы: " + Db.char_name(_owner)
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(1120, 0)
	var col := Ui.vbox(16)
	col.add_child(Ui.header(title, "idcard" if _owner != "" else "magnifier", close))
	var cards := Ui.hbox(22)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	if _object != "":
		cards.add_child(_object_card())
	elif _data.has("ticket"):
		cards.add_child(_ticket_card())
		cards.add_child(_id_card(str(_data.get("id_title", "Удостоверение личности")), _data.get("id", [])))
	else:
		cards.add_child(_id_card(str(_data.get("title", "Документы")), _data.get("fields", [])))
	col.add_child(cards)
	var hotspots: Array = _data.get("hotspots", [])
	_details = Ui.vbox(8)
	if not hotspots.is_empty():
		var dh := Ui.hbox(12)
		dh.add_child(Ui.label("Мелкие детали:", "SubHeaderLabel", 22))
		dh.add_child(Ui.spacer())
		_lens_btn = Ui.button("Лупа (Q)", "magnifier", "CyanButton", _toggle_lens, 54)
		_lens_btn.toggle_mode = true
		dh.add_child(_lens_btn)
		col.add_child(dh)
		col.add_child(_details)
		_hint = Ui.label("Включите лупу и нажмите на деталь, чтобы рассмотреть её.", "SmallLabel", 17)
		col.add_child(_hint)
		if ProgressionManager.equipment_level("magnifier") >= 3:
			_lens_on = true
			_lens_btn.set_pressed_no_signal(true)
	p.add_child(col)
	add_child(Ui.center(p))
	_rebuild_details()
	if _data.has("on_open"):
		inv.give(str(_data["on_open"]))
	for id in _data.get("gives", []):
		inv.give(str(id))
	AudioManager.play_sfx("page", -4.0)


func _field_rows(fields: Array, dark: bool) -> GridContainer:
	var g := Ui.grid(2, 8)
	for f: Array in fields:
		var k := Ui.label(str(f[0]) + ":", "DarkLabel" if dark else "DimLabel", 18)
		k.modulate = Color(1, 1, 1, 0.75)
		g.add_child(k)
		var v := Ui.label(str(f[1]), "DarkHeaderLabel" if dark else "", 21, true)
		v.custom_minimum_size.x = 260
		g.add_child(v)
	return g


func _ticket_card() -> Control:
	var p := Ui.panel("PaperPanel")
	p.custom_minimum_size = Vector2(470, 300)
	var v := Ui.vbox(10)
	var top := Ui.hbox(10)
	top.add_child(Ui.icon("ticket", 40))
	top.add_child(Ui.label("БИЛЕТ · LAST TRAIN", "DarkHeaderLabel", 24))
	v.add_child(top)
	var stripe := ColorRect.new()
	stripe.color = Color("#c0394b")
	stripe.custom_minimum_size = Vector2(0, 6)
	v.add_child(stripe)
	v.add_child(_field_rows(_data.get("ticket", []), true))
	p.add_child(v)
	return p


func _id_card(title: String, fields: Array) -> Control:
	var p := Ui.panel("IdPanel")
	p.custom_minimum_size = Vector2(500, 300)
	var v := Ui.vbox(10)
	var top := Ui.hbox(10)
	top.add_child(Ui.icon("idcard", 40))
	top.add_child(Ui.label(title, "DarkHeaderLabel", 22))
	v.add_child(top)
	var row := Ui.hbox(14)
	if _owner != "":
		row.add_child(Ui.portrait(Db.portrait(_owner), 110, Color("#2f4377"), Color("#9aa8c8")))
	row.add_child(_field_rows(fields, true))
	v.add_child(row)
	p.add_child(v)
	return p


func _object_card() -> Control:
	var kind: String = str(_data.get("kind", "item"))
	var p := Ui.panel("PaperPanel" if kind == "document" else "CardPanel")
	p.custom_minimum_size = Vector2(760, 220)
	var v := Ui.vbox(12)
	if _data.has("fields"):
		v.add_child(_field_rows(_data["fields"], kind == "document"))
	if _data.has("text"):
		var t := Ui.label(str(_data["text"]), "DarkLabel" if kind == "document" else "", 22, true)
		v.add_child(t)
	p.add_child(v)
	return p


func _rebuild_details() -> void:
	if _details == null:
		return
	Ui.clear(_details)
	var inv: InvestigationManager = game.investigation
	for h: Dictionary in _data.get("hotspots", []):
		var found: bool = inv.evidence.has(str(h["clue"]))
		if found:
			var box := Ui.panel("HighlightPanel")
			var hb := Ui.hbox(12)
			hb.add_child(Ui.icon("magnifier", 36))
			var vb := Ui.vbox(2)
			vb.add_child(Ui.label(str(h["label"]), "GoldLabel", 19))
			var t := Ui.label(str(h["text"]), "", 20, true)
			t.custom_minimum_size.x = 900
			vb.add_child(t)
			hb.add_child(vb)
			box.add_child(hb)
			_details.add_child(box)
		elif h.get("hidden", false) and not _lens_on:
			continue  # волос, царапина, капля воска — без лупы деталь просто не видна
		else:
			var b := Ui.button(str(h["label"]) + ("  — рассмотреть" if _lens_on else "  — слишком мелко"), "magnifier", "GhostButton", func() -> void: _inspect(h), 56)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			if _lens_on:
				b.theme_type_variation = "CyanButton"
			_details.add_child(b)


func _toggle_lens() -> void:
	_lens_on = not _lens_on
	_lens_btn.set_pressed_no_signal(_lens_on)
	if _lens_on:
		AudioManager.play_sfx("magnifier")
	_rebuild_details()


func _inspect(h: Dictionary) -> void:
	if not _lens_on:
		_hint.text = "Слишком мелко. Включите лупу (Q)."
		_hint.add_theme_color_override("font_color", UiTheme.PINK)
		AudioManager.play_sfx("wrong", -10.0)
		return
	game.investigation.give(str(h["clue"]))
	game.player.play_action("inspect", 0.6)
	_rebuild_details()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"magnifier") and _lens_btn:
		get_viewport().set_input_as_handled()
		_toggle_lens()
