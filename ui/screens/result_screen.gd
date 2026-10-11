extends GameScreen
## Итог дела: анимация звёзд (0–3), затраченное время, найденные ключевые улики, ошибки,
## награда и кнопка «Следующее дело» (сразу запускает следующий уровень кампании).
## При поражении — «Маньяк скрылся» / «<злодей> скрылся», звёзд нет, дело можно повторить.

var _result: Dictionary
var _stars: Array[TextureRect] = []


func build(args: Dictionary) -> void:
	closable = false
	_result = args.get("result", {})
	var solved: bool = bool(_result.get("solved", false))
	var data: Dictionary = game.case_data
	var villain_id: String = str(_result.get("monster", data["monster"]))
	var villain: Dictionary = Db.monster(villain_id)
	var lvl: Dictionary = Db.level(str(_result.get("level", "")))
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(1080, 0)
	var col := Ui.vbox(12)
	var title_text: String = "Дело раскрыто!"
	if not solved:
		title_text = ("Маньяк скрылся" if villain.get("kind", "") == "maniac" else "%s скрылся" % villain.get("name", "Злодей")) \
			if _result.get("outcome") == "timeout" else "Расследование провалено"
	var title := Ui.label(title_text, "TitleLabel", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not solved:
		title.add_theme_color_override("font_color", Color("#ff8a9a"))
	col.add_child(title)
	var sub: String = "«%s»" % data["title"]
	if not lvl.is_empty():
		sub = "Дело %d · %s" % [int(lvl["number"]), sub]
	elif _result.get("level") == "daily":
		sub = "Дело дня · " + sub
	var sl := Ui.label(sub, "DimLabel", 20)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sl)
	# звёзды
	var stars_row := Ui.hbox(18)
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 3:
		var s := Ui.icon("star", 72)
		s.modulate = Color(0.25, 0.22, 0.4, 1.0)
		s.pivot_offset = Vector2(36, 36)
		stars_row.add_child(s)
		_stars.append(s)
	col.add_child(stars_row)

	var row := Ui.hbox(26)
	var left := Ui.vbox(8)
	# При поражении виновника не раскрываем — только знак вопроса.
	left.add_child(Ui.portrait(Db.villain_portrait(villain_id) if solved else Db.icon("question"), 190,
		Color(str(villain.get("color", "#4fd0ff"))).lightened(0.5), Color("#1a1440")))
	var vn := Ui.label(str(villain.get("name", "")) if solved else "Кто-то из пассажиров...", "SubHeaderLabel", 22, true)
	vn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vn.custom_minimum_size.x = 200
	left.add_child(vn)
	if solved and _result.get("first_catch", false):
		left.add_child(Ui.chip("Новая запись в бестиарии!", UiTheme.PINK, "bestiary"))
	row.add_child(left)

	var right := Ui.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stats := Ui.grid(2, 10)
	var secs: int = int(round(float(_result.get("elapsed", 0.0)) * 60.0))
	for item: Array in [
			["hourglass", "Время расследования", "%d:%02d из %d:00" % [secs / 60, secs % 60, int(Db.deadline_minutes())]],
			["magnifier", "Ключевые улики", "найдено: %d" % int(_result.get("key_found", 0))],
			["guard", "Ошибочные обвинения", str(int(_result.get("mistakes", 0)))],
			["question", "Подсказки", str(int(_result.get("hints_used", 0)))]]:
		var h := Ui.hbox(8)
		h.add_child(Ui.icon(item[0], 30))
		h.add_child(Ui.label(item[1], "DimLabel", 19))
		stats.add_child(h)
		stats.add_child(Ui.label(item[2], "NumberLabel", 22))
	right.add_child(stats)
	var rw: Dictionary = _result.get("rewards", {})
	var pills := Ui.hbox(10)
	for cur: Array in [["coins", "coin"], ["crystals", "crystal"], ["reputation", "reputation"]]:
		var v: int = int(rw.get(cur[0], 0))
		if v != 0:
			pills.add_child(Ui.pill(cur[1], ("+%d" % v) if v > 0 else str(v), 32)[0])
	right.add_child(pills)
	if solved:
		var ns: int = int(_result.get("new_stars", 0))
		var note: String = "Новых звёзд: %d — награда начислена." % ns if ns > 0 else "Рекорд не побит — за прежние звёзды награда уже получена."
		if _result.get("level", "") == "":
			note = ""
		if note != "":
			right.add_child(Ui.label(note, "SmallLabel", 17, true))
		if _result.has("court"):
			right.add_child(Ui.label(str(_result["court"]), "GoldLabel", 18, true))
		elif not _result.get("verdict_ok", true):
			right.add_child(Ui.label("Способ назван неверно — суд не получил полной картины.", "GoldLabel", 17, true))
		if int(_result.get("hints_used", 0)) > 0:
			right.add_child(Ui.label("Подсказки снизили рейтинг.", "SmallLabel", 16, true))
		right.add_child(_star_rules())
		var truth := Ui.panel("CardPanel")
		var tv := Ui.vbox(6)
		tv.add_child(Ui.label("Как всё было · способность: " + str(villain.get("ability", "")), "GoldLabel", 19, true))
		for line in data.get("truth", []):
			var l := Ui.label(str(line), "", 17, true)
			l.custom_minimum_size.x = 640
			tv.add_child(l)
		var sc := Ui.scroll(tv)
		sc.custom_minimum_size = Vector2(0, 170)
		truth.add_child(sc)
		right.add_child(truth)
	else:
		right.add_child(Ui.label(str(villain.get("escape_text", "Злодей скрылся.")) if _result.get("outcome") == "timeout"
			else "Вторая ошибка обвинения — монстр понял, что его ищут, и сбежал.", "", 20, true))
		if _result.get("ticket_spent", false):
			right.add_child(Ui.label("−1 билет. Осталось: %d из %d. Новый билет — через 30 минут." % [int(_result.get("tickets_left", 0)), Tickets.MAX], "GoldLabel", 18, true))
		right.add_child(Ui.label("Звёзды за эту попытку не начисляются. Дело можно повторить — улики и события будут другими.", "DimLabel", 18, true))
		right.add_child(Ui.label("Подсказка: " + str(villain.get("counter", "")), "GoldLabel", 18, true))
	row.add_child(right)
	col.add_child(row)

	var btns := Ui.hbox(14)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_child(Ui.button("В меню", "home", "GhostButton", func() -> void: game.exit_to_menu(false), 62))
	btns.add_child(Ui.button("Повторить дело", "rewind", "CyanButton", _retry, 62))
	var next: Dictionary = Db.next_level(str(_result.get("level", "")))
	if solved and not next.is_empty() and ProgressionManager.level_unlocked(str(next["id"])):
		var nb := Ui.button("Следующее дело", "arrow_right", "PrimaryButton", func() -> void: _start_level(str(next["id"])), 66)
		nb.custom_minimum_size.x = 320
		btns.add_child(nb)
	col.add_child(btns)
	p.add_child(col)
	add_child(Ui.center(p))
	if solved:
		AudioManager.play_music("music_menu")
	_animate_stars(int(_result.get("stars", 0)))


func _star_rules() -> Control:
	var l := Ui.label("★★★ — верно КТО, КАК, КАКОЙ МОНСТР и три доказанные улики · ★★ — верно КТО и КАКОЙ МОНСТР · ★ — верно только КТО. Подсказки: −1★ (1–2), −2★ (3+), кроме лёгкой сложности", "SmallLabel", 15, true)
	return l


func _animate_stars(n: int) -> void:
	for i in n:
		var s: TextureRect = _stars[i]
		var tw := s.create_tween()
		tw.tween_interval(0.35 + i * 0.35)
		tw.tween_callback(func() -> void:
			s.modulate = Color.WHITE
			AudioManager.play_sfx("coin", -2.0 + i * 2.0, 1.0 + i * 0.12))
		tw.tween_property(s, "scale", Vector2(1.35, 1.35), 0.12)
		tw.tween_property(s, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


func _retry() -> void:
	var lvl: String = str(_result.get("level", ""))
	if not Tickets.can_start(lvl):
		ui.open("tickets_screen", {"on_ready": _retry})
		return
	if lvl == "daily":
		SaveManager.prepare_daily()
	elif lvl != "":
		SaveManager.prepare_level(lvl)
	else:
		SaveManager.pending_case = game.case_id
		SaveManager.pending_seed = -1
		SaveManager.pending_resume = false
	get_tree().change_scene_to_file("res://game/game.tscn")


func _start_level(level_id: String) -> void:
	if not Tickets.can_start(level_id):
		ui.open("tickets_screen", {"on_ready": func() -> void: _start_level(level_id)})
		return
	SaveManager.prepare_level(level_id)
	get_tree().change_scene_to_file("res://game/game.tscn")
