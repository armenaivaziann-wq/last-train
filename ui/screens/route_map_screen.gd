extends GameScreen
## Карта кампании: 10 сюжетных дел вдоль маршрута поезда. Состояния: пройдено (с лучшими
## звёздами), открыто, ещё не открыто. Доступ открывается только прохождением предыдущего
## дела — монеты и репутация на него не влияют. Здесь же — «Дело дня».

var _info: VBoxContainer
var _map: Control
var _nodes: Array = []
var _path: Control


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
		var id: String = l["id"]
		var unlocked: bool = ProgressionManager.level_unlocked(id)
		var done: bool = ProgressionManager.level_completed(id)
		if unlocked and not done and current.is_empty():
			current = l
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
	var head := Ui.panel("GlassPanel")
	var hh := Ui.header("Кампания", "map", close)
	var st: Array = Ui.pill("star", "%d / %d" % [ProgressionManager.total_stars(), Db.levels().size() * 3], 28)
	hh.add_child(st[0])
	hh.move_child(st[0], 2)
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
	_select(current if not current.is_empty() else Db.levels()[0])


func _layout() -> void:
	var vs: Vector2 = size
	var k: float = maxf(vs.x / 640.0, vs.y / 360.0)
	var off: Vector2 = (vs - Vector2(640, 360) * k) / 2.0
	for n: Dictionary in _nodes:
		var pos := Vector2(float(n["level"]["pos"][0]), float(n["level"]["pos"][1])) * k + off
		pos.x = minf(pos.x, vs.x - 500.0)
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
	vv.add_child(Ui.label(str(villain.get("name", "")) if caught else "Неизвестный злодей", "", 19, true))
	vv.add_child(Ui.label(str(villain.get("short", "")), "SmallLabel", 16, true))
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
