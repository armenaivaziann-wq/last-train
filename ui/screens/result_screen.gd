extends GameScreen
## Итог дела: «Дело раскрыто!» с истинной формой монстра и наградами или «Монстр скрылся»
## с утешительной наградой. Показывает объяснение — как всё было на самом деле.

var _result: Dictionary


func build(args: Dictionary) -> void:
	closable = false
	_result = args.get("result", {})
	var solved: bool = bool(_result.get("solved", false))
	var data: Dictionary = game.case_data
	var monster_id: String = str(_result.get("monster", data["monster"]))
	var monster: Dictionary = Db.monster(monster_id)
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(1100, 0)
	var col := Ui.vbox(14)
	var title := Ui.label("Дело раскрыто!" if solved else "Монстр скрылся...", "TitleLabel", 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not solved:
		title.add_theme_color_override("font_color", Color("#c8b8ff"))
	col.add_child(title)
	var sub := "«%s» · %s → %s" % [data["title"], data["station_from"], data["station_to"]]
	var sl := Ui.label(sub, "DimLabel", 20)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sl)
	var row := Ui.hbox(28)
	var left := Ui.vbox(10)
	var mp := Ui.portrait(Db.monster_portrait(monster_id) if solved else Db.portrait(str(data["culprit"])), 220, Color(str(monster.get("color", "#9b5cf6"))).lightened(0.4), Color("#2a1666"))
	left.add_child(mp)
	var mname := Ui.label(str(monster.get("name", "")) if solved else "Кто-то из пассажиров...", "SubHeaderLabel", 26)
	mname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(mname)
	if solved and _result.get("first_catch", false):
		left.add_child(Ui.chip("Новая запись в бестиарии!", UiTheme.PINK, "bestiary"))
	row.add_child(left)
	var right := Ui.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rw: Dictionary = _result.get("rewards", {})
	var pills := Ui.hbox(12)
	for cur: Array in [["coins", "coin"], ["crystals", "crystal"], ["reputation", "reputation"]]:
		var v: int = int(rw.get(cur[0], 0))
		var pl: Array = Ui.pill(cur[1], ("+%d" % v) if v >= 0 else str(v), 36)
		pills.add_child(pl[0])
	right.add_child(pills)
	var facts := Ui.vbox(4)
	if solved:
		var culprit_name: String = Db.char_name(str(data["culprit"]))
		facts.add_child(Ui.label("Под маской «%s» скрывался %s." % [culprit_name, str(monster.get("name", "")).to_lower()], "", 21, true))
		facts.add_child(Ui.label("Ключевых оснований в обвинении: %d%s" % [int(_result.get("key", 0)), "" if _result.get("strong", true) else " — маловато, награда снижена"], "DimLabel", 19, true))
		if _result.get("monster_guessed", false):
			facts.add_child(Ui.label("Тип монстра назван верно: +5 кристаллов.", "GoldLabel", 19))
		if _result.get("time_bonus", false):
			facts.add_child(Ui.label("Быстрое раскрытие: +50 монет.", "GoldLabel", 19))
		if _result.get("replay", false):
			facts.add_child(Ui.label("Повторное расследование: награда уменьшена.", "SmallLabel", 17))
	else:
		facts.add_child(Ui.label("Поезд прибыл на станцию, и монстр затерялся среди пассажиров." if _result.get("outcome") == "timeout" else "Слишком много ошибочных обвинений — охрана остановила расследование.", "", 21, true))
		facts.add_child(Ui.label("Найденные улики сохранены в архиве. Прогресс не потерян — попробуйте снова!", "DimLabel", 19, true))
	facts.add_child(Ui.label("Ошибок: %d · Улик найдено: %d" % [int(_result.get("mistakes", 0)), int(_result.get("clues", 0))], "SmallLabel", 18))
	right.add_child(facts)
	if solved:
		var truth := Ui.panel("CardPanel")
		var tv := Ui.vbox(6)
		tv.add_child(Ui.label("Как всё было", "GoldLabel", 22))
		for line in data.get("truth", []):
			var l := Ui.label(str(line), "", 18, true)
			l.custom_minimum_size.x = 660
			tv.add_child(l)
		if data.has("real_robert_note"):
			tv.add_child(Ui.label(str(data["real_robert_note"]), "DimLabel", 17, true))
		var sc := Ui.scroll(tv)
		sc.custom_minimum_size = Vector2(0, 230)
		truth.add_child(sc)
		right.add_child(truth)
	row.add_child(right)
	col.add_child(row)
	var btns := Ui.hbox(14)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	if not solved:
		btns.add_child(Ui.button("Повторить дело", "rewind", "CyanButton", _retry, 64))
	var cont := Ui.button("Продолжить", "arrow_right", "PrimaryButton", _continue, 64)
	cont.custom_minimum_size.x = 320
	btns.add_child(cont)
	col.add_child(btns)
	p.add_child(col)
	add_child(Ui.center(p))
	if solved:
		AudioManager.play_sfx("coin")
		AudioManager.play_music("music_menu")


func _continue() -> void:
	game.exit_to_menu(false)


func _retry() -> void:
	SaveManager.pending_case = game.case_id
	SaveManager.pending_resume = false
	get_tree().change_scene_to_file("res://game/game.tscn")
