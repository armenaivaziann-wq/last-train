extends GameScreen
## Карта кампании: 10 сюжетных дел вдоль маршрута поезда. Состояния: пройдено (с лучшими
## звёздами), открыто, ещё не открыто. Доступ открывается только прохождением предыдущего
## дела — монеты и репутация на него не влияют. Здесь же — «Дело дня».

var _info: VBoxContainer
var _map: Control
var _nodes: Array = []
var _path: Control
var _chapter: int = 1
var _tabs: HBoxContainer


func build(_args: Dictionary) -> void:
	dim_background = false
	var bg := ColorRect.new()
	bg.color = UiTheme.BG_DEEP
	Ui.full_rect(bg)
	add_child(bg)
	_map = Control.new()
	Ui.full_rect(_map)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map)
	var tex := TextureRect.new()
	tex.texture = Db.texture("menu/route_map.png")
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	Ui.full_rect(tex)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.add_child(tex)
	_path = RoutePath.new()
	Ui.full_rect(_path)
	_map.add_child(_path)
	var current: Dictionary = {}
	for l: Dictionary in Db.levels():
		if ProgressionManager.level_unlocked(l["id"]) and not ProgressionManager.level_completed(l["id"]) and current.is_empty():
			current = l
	if not current.is_empty():
		_chapter = int(current.get("chapter", 1))
	elif ProgressionManager.level_completed(str(Db.levels()[-1]["id"])):
		_chapter = int(Db.levels()[-1].get("chapter", 1))
	_build_nodes()
	var head := Ui.panel("GlassPanel")
	var hh := Ui.header("Кампания", "map", close)
	var st: Array = Ui.pill("star", "%d / %d" % [ProgressionManager.total_stars(), Db.levels().size() * 3], 28)
	hh.add_child(st[0])
	hh.move_child(st[0], 2)
	# Главы маршрута
	_tabs = Ui.hbox(8)
	for ch: Dictionary in Db.campaign.get("chapters", []):
		var n: int = int(ch["number"])
		var first: String = str(Db.levels().filter(func(l: Dictionary) -> bool: return int(l.get("chapter", 1)) == n)[0]["id"])
		var open: bool = ProgressionManager.level_unlocked(first)
		var b := Ui.button("Глава %d" % n, "map" if open else "lock", "PrimaryButton" if n == _chapter else "GhostButton", func() -> void: _set_chapter(n), 48)
		b.disabled = not open
		b.tooltip_text = str(ch["title"])
		_tabs.add_child(b)
	hh.add_child(_tabs)
	hh.move_child(_tabs, 2)
	head.add_child(hh)
	head.set_anchors_preset(Control.PRESET_TOP_WIDE)
	head.offset_left = 30
	head.offset_right = -30
	head.offset_top = 16
	add_child(head)
	var side := Ui.panel()
	side.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -440
	side.offset_right = -30
	side.offset_top = 120
	side.offset_bottom = -30
	_info = Ui.vbox(10)
	side.add_child(Ui.scroll(_info))
	add_child(side)
	resized.connect(_layout)
	_layout.call_deferred()
	var chapter_levels: Array = Db.levels().filter(func(l: Dictionary) -> bool: return int(l.get("chapter", 1)) == _chapter)
	_select(current if not current.is_empty() and int(current.get("chapter", 1)) == _chapter else chapter_levels[0])


## Узлы дел выбранной главы.
func _build_nodes() -> void:
	for n: Dictionary in _nodes:
		n["button"].queue_free()
		n["label"].queue_free()
	_nodes.clear()
	for l: Dictionary in Db.levels():
		if int(l.get("chapter", 1)) != _chapter:
			continue
		var id: String = l["id"]
		var unlocked: bool = ProgressionManager.level_unlocked(id)
		var done: bool = ProgressionManager.level_completed(id)
		var b := Ui.icon_button("check" if done else ("lock" if not unlocked else "train"), 70,
			"CyanButton" if done else ("PrimaryButton" if unlocked else "GhostButton"), func() -> void: _select(l))
		var num := Ui.label(str(int(l["number"])), "NumberLabel", 18)
		num.position = Vector2(4, -2)
		b.add_child(num)
		_map.add_child(b)
		var lbl := Ui.label(("%s" % l["title"]) + ("  " + "★".repeat(ProgressionManager.level_stars(id)) if done else ""), "", 17)
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.add_theme_color_override("font_outline_color", UiTheme.OUTLINE)
		if done:
			lbl.add_theme_color_override("font_color", UiTheme.GOLD)
		elif not unlocked:
			lbl.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
		_map.add_child(lbl)
		_nodes.append({"level": l, "button": b, "label": lbl})
	_path.nodes = _nodes


func _set_chapter(n: int) -> void:
	_chapter = n
	_build_nodes()
	for b: Button in _tabs.get_children():
		b.theme_type_variation = "PrimaryButton" if b.text == "Глава %d" % n else "GhostButton"
	_layout()
	_select(Db.levels().filter(func(l: Dictionary) -> bool: return int(l.get("chapter", 1)) == n)[0])


func _layout() -> void:
	# Узлы дел раскладываем в свободной части экрана левее панели (карта — фон).
	var vs: Vector2 = size
	var area := Rect2(Vector2(120, 150), Vector2(maxf(300.0, vs.x - 470.0 - 140.0), maxf(200.0, vs.y - 150.0 - 70.0)))
	for n: Dictionary in _nodes:
		var norm := Vector2((float(n["level"]["pos"][0]) - 60.0) / 520.0, (float(n["level"]["pos"][1]) - 70.0) / 240.0)
		var pos: Vector2 = area.position + norm * area.size
		n["button"].position = pos - Vector2(35, 35)
		n["label"].position = pos + Vector2(-n["label"].size.x / 2.0, 38)
		n["screen_pos"] = pos
	_path.queue_redraw()


func _select(l: Dictionary) -> void:
	Ui.clear(_info)
	var id: String = l["id"]
	var unlocked: bool = ProgressionManager.level_unlocked(id)
	var stars: int = ProgressionManager.level_stars(id)
	var villain: Dictionary = Db.monster(str(l["villain"]))
	var caught: bool = ProgressionManager.monster_caught(str(l["villain"])) > 0
	_info.add_child(Ui.label("Дело %d" % int(l["number"]), "GoldLabel", 20))
	_info.add_child(Ui.label(str(l["title"]), "HeaderLabel", 30, true))
	_info.add_child(Ui.label("%s → %s" % [l["from"], l["to"]], "DimLabel", 18))
	var sr := Ui.hbox(6)
	for i in 3:
		var s := Ui.icon("star", 40)
		s.modulate = Color.WHITE if i < stars else Color(0.3, 0.27, 0.45)
		sr.add_child(s)
	_info.add_child(sr)
	if stars > 0:
		var bt: float = ProgressionManager.level_best_time(id)
		var secs: int = int(round(bt * 60.0))
		_info.add_child(Ui.label("Лучшее время: %d:%02d" % [secs / 60, secs % 60], "SmallLabel", 17))
	if not unlocked:
		_info.add_child(Ui.chip("Откроется после дела %d" % (int(l["number"]) - 1), UiTheme.TEXT_DIM, "lock"))
		return
	var vrow := Ui.hbox(10)
	vrow.add_child(Ui.tex(Db.villain_portrait(str(l["villain"])) if caught else Db.icon("question"), 64))
	var vv := Ui.vbox(2)
	vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vn := Ui.label(str(villain.get("name", "")) if caught else "Неизвестный злодей", "", 19, true)
	vn.custom_minimum_size.x = 260
	vv.add_child(vn)
	var vs2 := Ui.label(str(villain.get("short", "")), "SmallLabel", 16, true)
	vs2.custom_minimum_size.x = 260
	vv.add_child(vs2)
	vrow.add_child(vv)
	_info.add_child(vrow)
	_info.add_child(Ui.label("Дедлайн: %d игровых минут. ★★★ — за 12 мин, 3+ ключевых улики, без ошибок." % int(Db.deadline_minutes()), "SmallLabel", 16, true))
	_info.add_child(Ui.button("Повторить дело" if stars > 0 else "Начать дело", "arrow_right", "PrimaryButton", func() -> void: _start(id), 64))
	_info.add_child(Ui.spacer(false, true))
	var daily := Ui.panel("HighlightPanel")
	var dv := Ui.vbox(6)
	dv.add_child(Ui.label("Дело дня", "GoldLabel", 21))
	var best: int = 0
	var dl: Dictionary = SaveManager.profile["campaign"]["daily"]
	if dl.get("day", "") == Time.get_date_string_from_system():
		best = int(dl.get("best_stars", 0))
	dv.add_child(Ui.label("Одно дело на всех сегодня: случайный злодей из открытых дел. Лучший результат: %s" % ("★".repeat(best) if best > 0 else "—"), "", 16, true))
	dv.add_child(Ui.button("Играть дело дня", "event", "CyanButton", _start_daily, 54))
	daily.add_child(dv)
	_info.add_child(daily)


func _start(level_id: String) -> void:
	SaveManager.prepare_level(level_id)
	AudioManager.play_sfx("announce", -6.0)
	get_tree().change_scene_to_file("res://game/game.tscn")


func _start_daily() -> void:
	SaveManager.prepare_daily()
	get_tree().change_scene_to_file("res://game/game.tscn")


class RoutePath extends Control:
	## Пунктир маршрута между делами: пройденная часть — розовая, закрытая — бледная.
	var nodes: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in range(nodes.size() - 1):
			if not nodes[i].has("screen_pos") or not nodes[i + 1].has("screen_pos"):
				continue
			var a: Vector2 = nodes[i]["screen_pos"]
			var b: Vector2 = nodes[i + 1]["screen_pos"]
			var open: bool = ProgressionManager.level_unlocked(str(nodes[i + 1]["level"]["id"]))
			var col: Color = Color("#ff8ad8") if open else Color(0.85, 0.8, 1.0, 0.45)
			var steps: int = maxi(1, int(a.distance_to(b) / 18.0))
			for s in steps:
				var t0: float = float(s) / steps
				if s % 2 == 0:
					draw_line(a.lerp(b, t0), a.lerp(b, t0 + 0.5 / steps), Color("#2a1660"), 12.0)
					draw_line(a.lerp(b, t0), a.lerp(b, t0 + 0.5 / steps), col, 7.0)
