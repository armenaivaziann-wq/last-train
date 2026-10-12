extends GameScreen
## Головоломки дела (данные — data["puzzles"] в файле дела). Одна задача на экране, крупные
## элементы под палец, 30–90 секунд. Решение выводится из найденных улик, а не угадывается:
## внизу — «Что вы знаете» (заголовки найденных улик-подсказок). Ошибка стоит игровых минут,
## головоломку можно повторять. На лёгкой сложности её можно пропустить (как подсказку).
##   code_lock — кодовый замок: колёсики с цифрами (code).
##   knot      — узел: развязывать петли в правильном порядке (order), ошибка — узел затянулся.
##   pairs     — сопоставление: каждой строке (left) выбрать вариант из options (касание
##               листает варианты); answer — индексы верных вариантов по строкам.

var _id: String
var _p: Dictionary
var _inv: InvestigationManager
var _after: Callable
var _body: VBoxContainer
var _msg: Label
# code_lock
var _digits: Array[int] = []
var _digit_labels: Array[Label] = []
# knot
var _knot_done: Array[String] = []
# pairs
var _picks: Array[int] = []
var _pick_buttons: Array[Button] = []


func build(args: Dictionary) -> void:
	_id = str(args["id"])
	_inv = game.investigation
	_p = _inv.puzzle(_id)
	_after = args.get("after", Callable())
	var panel := Ui.panel()
	panel.custom_minimum_size = Vector2(760, 0)
	var v := Ui.vbox(12)
	v.add_child(Ui.header(str(_p.get("title", "Головоломка")), "lock" if _p["type"] == "code_lock" else "magnifier", close))
	v.add_child(Ui.label(str(_p.get("intro", "")), "", 20, true))
	_body = Ui.vbox(10)
	v.add_child(_body)
	_msg = Ui.label("", "GoldLabel", 18, true)
	_msg.visible = false
	v.add_child(_msg)
	v.add_child(_known())
	var row := Ui.hbox(10)
	if _inv.profile.get("hints_free", false):
		row.add_child(Ui.button("Пропустить (как подсказка)", "question", "GhostButton", _skip, 54))
	row.add_child(Ui.spacer())
	row.add_child(Ui.button("Отложить", "back", "GhostButton", close, 54))
	v.add_child(row)
	panel.add_child(v)
	add_child(Ui.center(panel))
	match str(_p["type"]):
		"code_lock":
			_build_lock()
		"knot":
			_build_knot()
		"pairs":
			_build_pairs()


## Найденные улики, из которых выводится решение (без самого решения).
func _known() -> Control:
	var box := Ui.panel("CardPanel")
	var kv := Ui.vbox(4)
	kv.add_child(Ui.label("Что вы знаете:", "SubHeaderLabel", 18))
	var any: bool = false
	for id: String in _p.get("needs", []):
		if _inv.evidence.has(id):
			any = true
			kv.add_child(Ui.label("•  " + str(_inv.evidence.clue(id)["title"]) + " — " + str(_inv.evidence.clue(id)["text"]), "", 16, true))
	if not any:
		kv.add_child(Ui.label("Пока ничего, что помогло бы. Ищите подсказки в уликах — или пробуйте наугад (это стоит времени).", "DimLabel", 16, true))
	# Высота ограничена: на телефоне окно не должно вылезать за экран, длинное — прокрутка.
	var sc := Ui.scroll(kv)
	sc.custom_minimum_size.y = 96
	box.add_child(sc)
	return box


# --- кодовый замок ------------------------------------------------------------------------
func _build_lock() -> void:
	var code: String = str(_p["code"])
	var row := Ui.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in code.length():
		_digits.append(0)
		var col := Ui.vbox(6)
		var k: int = i
		col.add_child(Ui.button("▲", "", "ChipButton", func() -> void: _turn(k, 1), 64))
		var l := Ui.label("0", "NumberLabel", 46)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(76, 64)
		_digit_labels.append(l)
		col.add_child(l)
		col.add_child(Ui.button("▼", "", "ChipButton", func() -> void: _turn(k, -1), 64))
		row.add_child(col)
	_body.add_child(row)
	var cost: float = float(_p.get("wrong_cost", 0.5)) * float(_inv.profile.get("time_cost_mult", 1.0))
	_body.add_child(Ui.button("Открыть" + ("  · ошибка %s мин" % str(snappedf(cost, 0.05)) if cost > 0.0 else ""), "lock", "PrimaryButton", _try_code, 60))


func _turn(i: int, d: int) -> void:
	_digits[i] = (_digits[i] + d + 10) % 10
	_digit_labels[i].text = str(_digits[i])
	AudioManager.play_sfx("click", -10.0)


func _try_code() -> void:
	var entered: String = "".join(PackedStringArray(_digits.map(func(x: int) -> String: return str(x))))
	if entered == str(_p["code"]):
		_win()
	else:
		_inv.puzzle_wrong(_id)
		AudioManager.play_sfx("door_locked", -4.0)
		_msg.text = "Не подходит. Время уходит."
		_msg.visible = true


# --- узел ---------------------------------------------------------------------------------
func _build_knot() -> void:
	_knot_done.clear()
	Ui.clear(_body)
	var order: Array = _p["order"]
	var shown: Array = order.duplicate()
	# Петли перемешаны всегда одинаково для этой головоломки (не зависит от попытки).
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_id)
	for i in range(shown.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: Variant = shown[i]
		shown[i] = shown[j]
		shown[j] = t
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for strand in shown:
		var s: String = str(strand)
		var b := Ui.button(s, "magnifier", "CyanButton", func() -> void: _pull(s), 70)
		b.custom_minimum_size.x = 330
		grid.add_child(b)
	_body.add_child(grid)
	var prog := Ui.label("Распутано: 0 / %d" % order.size(), "SmallLabel", 18)
	prog.name = "Progress"
	_body.add_child(prog)


func _pull(strand: String) -> void:
	var order: Array = _p["order"]
	if str(order[_knot_done.size()]) == strand:
		_knot_done.append(strand)
		AudioManager.play_sfx("click", -6.0)
		for b: Button in _body.find_children("*", "Button", true, false):
			if b.text == strand:
				b.disabled = true
		(_body.find_child("Progress", true, false) as Label).text = "Распутано: %d / %d" % [_knot_done.size(), order.size()]
		if _knot_done.size() == order.size():
			_win()
	else:
		_inv.puzzle_wrong(_id)
		AudioManager.play_sfx("wrong", -6.0)
		_build_knot()
		_msg.text = "Узел затянулся сильнее. Начните заново — и подумайте, в каком порядке его вязали."
		_msg.visible = true


# --- сопоставление -----------------------------------------------------------------------
func _build_pairs() -> void:
	var opts: Array = _p["options"]
	for i in (_p["left"] as Array).size():
		_picks.append(-1)
		var row := Ui.hbox(12)
		var l := Ui.label(str(_p["left"][i]), "", 20)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var k: int = i
		var b := Ui.button("выбрать ▸", "", "ChipButton", func() -> void: _cycle(k), 56)
		b.custom_minimum_size.x = 220
		_pick_buttons.append(b)
		row.add_child(b)
		_body.add_child(row)
	var cost: float = float(_p.get("wrong_cost", 0.5)) * float(_inv.profile.get("time_cost_mult", 1.0))
	_body.add_child(Ui.button("Проверить" + ("  · ошибка %s мин" % str(snappedf(cost, 0.05)) if cost > 0.0 else ""), "check", "PrimaryButton", _try_pairs, 60))
	if opts.is_empty():
		push_error("pairs без вариантов: " + _id)


func _cycle(i: int) -> void:
	_picks[i] = (_picks[i] + 1) % (_p["options"] as Array).size()
	_pick_buttons[i].text = str(_p["options"][_picks[i]])


func _try_pairs() -> void:
	var answer: Array = _p["answer"]
	var ok: bool = true
	for i in answer.size():
		if _picks[i] != int(answer[i]):
			ok = false
	if ok:
		_win()
	else:
		_inv.puzzle_wrong(_id)
		AudioManager.play_sfx("wrong", -6.0)
		_msg.text = "Не сходится. Время уходит."
		_msg.visible = true


# --- итог ---------------------------------------------------------------------------------
func _win() -> void:
	_inv.solve_puzzle(_id)
	AudioManager.play_sfx("success", -4.0)
	Events.notify(str(_p.get("solved_text", "Получилось!")), "check")
	_finish()


func _skip() -> void:
	_inv.solve_puzzle(_id, true)
	_finish()


func _finish() -> void:
	var cb: Callable = _after
	close()
	if cb.is_valid():
		cb.call()
