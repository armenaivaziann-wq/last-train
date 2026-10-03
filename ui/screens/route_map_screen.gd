extends GameScreen
## Карта маршрутов и станций: иллюстрированная долина, маршруты открываются репутацией.
## Выбор маршрута запускает его дело (или повтор раскрытого дела с меньшей наградой).

const MAP_SCALE: float = 2.0

var _info: VBoxContainer
var _selected: Dictionary = {}
var _map: Control
var _nodes: Array = []


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
	var path := RoutePath.new()
	Ui.full_rect(path)
	_map.add_child(path)
	var routes: Array = Db.prog_list("routes")
	for r: Dictionary in routes:
		var unlocked: bool = ProgressionManager.route_unlocked(r)
		var playable: bool = unlocked and Db.has_case(str(r.get("case", "")))
		var b := Ui.icon_button("train" if playable else ("lock" if not unlocked else "hourglass"), 76,
			"PrimaryButton" if playable else "GhostButton", func() -> void: _select(r))
		_map.add_child(b)
		var lbl := Ui.label(str(r["name"]), "", 18)
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.add_theme_color_override("font_outline_color", UiTheme.OUTLINE)
		_map.add_child(lbl)
		_nodes.append({"route": r, "button": b, "label": lbl})
	path.nodes = _nodes
	var head := Ui.panel("GlassPanel")
	var hh := Ui.header("Карта маршрутов", "map", close)
	var rp: Array = Ui.pill("reputation", "Репутация: %d" % EconomyManager.reputation(), 28)
	hh.add_child(rp[0])
	hh.move_child(rp[0], 2)
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
	_info = Ui.vbox(12)
	side.add_child(_info)
	add_child(side)
	resized.connect(_layout)
	_layout.call_deferred()
	_select(routes[0])


func _layout() -> void:
	# Карта масштабируется «с обрезкой» — пересчитываем позиции узлов маршрутов
	var vs: Vector2 = size
	var k: float = maxf(vs.x / 640.0, vs.y / 360.0)
	var off: Vector2 = (vs - Vector2(640, 360) * k) / 2.0
	for n: Dictionary in _nodes:
		var pos := Vector2(float(n["route"]["pos"][0]), float(n["route"]["pos"][1])) * k + off
		n["button"].position = pos - Vector2(38, 38)
		n["label"].position = pos + Vector2(-n["label"].size.x / 2.0, 42)
		n["screen_pos"] = pos
	_map.get_child(1).queue_redraw()


func _select(r: Dictionary) -> void:
	_selected = r
	Ui.clear(_info)
	var unlocked: bool = ProgressionManager.route_unlocked(r)
	var case_id: String = str(r.get("case", ""))
	_info.add_child(Ui.label(str(r["name"]), "HeaderLabel", 28, true))
	_info.add_child(Ui.label(str(r["description"]), "", 20, true))
	if not unlocked:
		_info.add_child(Ui.chip("Нужна репутация %d" % int(r["reputation"]), UiTheme.GOLD, "lock"))
		_info.add_child(Ui.label("Раскрывайте дела, чтобы зарабатывать репутацию.", "SmallLabel", 17, true))
		return
	if not Db.has_case(case_id):
		_info.add_child(Ui.chip("Маршрут готовится к запуску", UiTheme.CYAN, "hourglass"))
		_info.add_child(Ui.label("Новые дела появятся в следующих обновлениях.", "SmallLabel", 17, true))
		return
	var c: Dictionary = Db.case_data(case_id)
	var m: Dictionary = Db.monster(str(c["monster"]))
	var solved: bool = ProgressionManager.case_solved_before(case_id)
	_info.add_child(Ui.label("Дело: «%s»" % c["title"], "GoldLabel", 22, true))
	var cv := Ui.hbox(10)
	cv.add_child(Ui.icon("clock", 30))
	cv.add_child(Ui.label("%s → %s, %d мин" % [c["start"], c["arrival"], int(Db.parse_time(c["arrival"]) - Db.parse_time(c["start"]))], "", 19))
	_info.add_child(cv)
	var mv := Ui.hbox(10)
	mv.add_child(Ui.icon("bestiary", 30))
	var caught: bool = ProgressionManager.monster_caught(str(c["monster"])) > 0
	mv.add_child(Ui.label("Слухи: в поезде " + (str(m["name"]).to_lower() if caught else "неизвестный монстр"), "", 19, true))
	_info.add_child(mv)
	var rw: Dictionary = c.get("rewards", {})
	var rh := Ui.hbox(8)
	for cur: Array in [["coins", "coin"], ["crystals", "crystal"], ["reputation", "reputation"]]:
		var pl: Array = Ui.pill(cur[1], "до %d" % (int(rw.get(cur[0], 0)) + (int(rw.get("per_key_clue", 0)) * 3 + 50 if cur[0] == "coins" else 0)), 26)
		rh.add_child(pl[0])
	_info.add_child(rh)
	if solved:
		_info.add_child(Ui.chip("Дело раскрыто · повтор даёт меньше наград", UiTheme.SUCCESS, "check"))
	_info.add_child(Ui.spacer(false, true))
	var go := Ui.button("Повторить расследование" if solved else "Отправиться в рейс", "arrow_right", "PrimaryButton", func() -> void: _start(case_id), 68)
	_info.add_child(go)


func _start(case_id: String) -> void:
	SaveManager.clear_case_progress()
	SaveManager.pending_case = case_id
	SaveManager.pending_resume = false
	AudioManager.play_sfx("announce", -6.0)
	get_tree().change_scene_to_file("res://game/game.tscn")


class RoutePath extends Control:
	## Пунктир маршрута между станциями.
	var nodes: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in range(nodes.size() - 1):
			if not nodes[i].has("screen_pos") or not nodes[i + 1].has("screen_pos"):
				continue
			var a: Vector2 = nodes[i]["screen_pos"]
			var b: Vector2 = nodes[i + 1]["screen_pos"]
			var unlocked: bool = ProgressionManager.route_unlocked(nodes[i + 1]["route"])
			var col: Color = Color("#ff8ad8") if unlocked else Color(0.85, 0.8, 1.0, 0.5)
			var steps: int = int(a.distance_to(b) / 18.0)
			for s in steps:
				var t0: float = float(s) / steps
				if s % 2 == 0:
					draw_line(a.lerp(b, t0), a.lerp(b, t0 + 0.5 / steps), Color("#2a1660"), 12.0)
					draw_line(a.lerp(b, t0), a.lerp(b, t0 + 0.5 / steps), col, 7.0)
