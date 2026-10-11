extends Control
## Главное меню: ночной пейзаж с параллаксом, проезжающий поезд с тёплыми окнами,
## логотип LAST TRAIN, продолжение дела, выбор нового расследования и разделы прогрессии.

const SCALE: float = 2.0

var ui: UIManager
var _layers: Array = []   # [{rects: [TextureRect, TextureRect], speed, width}]
var _train: Control
var _glow: TextureRect
var _smoke: Array[TextureRect] = []
var _time: float = 0.0
var _coins: Label
var _crystals: Label
var _rep: Label
var _tickets: Label
var _buttons: VBoxContainer


func _ready() -> void:
	theme = UiTheme.theme
	Ui.full_rect(self)
	_build_background()
	_build_logo()
	_build_menu()
	_build_top_bar()
	var foot := Ui.label("Один поезд. Много пассажиров. И один из них — не человек...", "SmallLabel", 17)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(36, -40)
	foot.offset_top = -44
	foot.offset_bottom = -16
	foot.offset_left = 36
	foot.offset_right = 900
	add_child(foot)
	ui = UIManager.new()
	add_child(ui)
	ui.stack_changed.connect(func(_m: bool) -> void: _refresh())
	Events.profile_changed.connect(_refresh)
	AudioManager.play_music("music_menu")
	AudioManager.set_train_ambience(false)
	_refresh()


func _build_background() -> void:
	var sky := TextureRect.new()
	sky.texture = Db.texture("menu/sky.png")
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	Ui.full_rect(sky)
	add_child(sky)
	_add_layer("menu/mountains.png", 0.35, 0.40)
	_add_layer("menu/hills.png", 0.62, 1.2)
	_add_layer("menu/ground.png", 0.80, 6.0)
	_train = Control.new()
	_train.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	add_child(_train)
	var tr := Ui.tex(Db.texture("menu/train_side.png"), int(606 * SCALE), int(72 * SCALE))
	_train.add_child(tr)
	_glow = Ui.tex(Db.texture("menu/train_glow.png"), int(606 * SCALE), int(72 * SCALE))
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_train.add_child(_glow)
	for i in 4:
		var s := Ui.tex(Db.texture("menu/smoke.png"), 64, 48)
		s.modulate.a = 0.0
		_train.add_child(s)
		_smoke.append(s)
	resized.connect(_layout_background)
	_layout_background.call_deferred()


func _add_layer(path: String, y_frac: float, speed: float) -> void:
	var tex: Texture2D = Db.texture(path)
	var rects: Array = []
	for i in 3:
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.size = Vector2(tex.get_width(), tex.get_height()) * SCALE
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(t)
		rects.append(t)
	_layers.append({"rects": rects, "speed": speed, "y_frac": y_frac, "offset": 0.0, "w": tex.get_width() * SCALE})


func _layout_background() -> void:
	var vs: Vector2 = size
	for l: Dictionary in _layers:
		for r: TextureRect in l["rects"]:
			r.position.y = round(vs.y * l["y_frac"] - (r.size.y * 0.15 if l["y_frac"] < 0.5 else 0.0))
	_train.position = Vector2(round(vs.x * 0.5 - 606.0 * SCALE * 0.42), vs.y * 0.80 - 72.0 * SCALE + 30.0)


func _build_logo() -> void:
	var v := Ui.vbox(-18)
	v.position = Vector2(56, 40)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://ui/logo_gradient.gdshader")
	for word: String in ["LAST", "TRAIN"]:
		var l := Ui.label(word, "TitleLabel", 104)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_color_override("font_outline_color", Color("#3a1670"))
		l.add_theme_constant_override("outline_size", 22)
		l.add_theme_color_override("font_shadow_color", Color(0.1, 0.0, 0.25, 0.8))
		l.add_theme_constant_override("shadow_offset_y", 8)
		l.material = mat
		mat.set_shader_parameter("height", 130.0)
		v.add_child(l)
	var ribbon := PanelContainer.new()
	ribbon.add_theme_stylebox_override("panel", UiTheme.sb(Color("#5a2fc8"), Color("#ff8ad8"), 3, 22, Color(UiTheme.PINK, 0.4), 8, Vector4(26, 6, 26, 8)))
	var sub := Ui.label("Кто здесь монстр?", "HeaderLabel", 30)
	ribbon.add_child(sub)
	ribbon.rotation_degrees = -3.0
	var rh := Ui.hbox(0)
	rh.add_child(Ui.margin(60, 18, 0, 0))
	rh.get_child(0).add_child(ribbon)
	v.add_child(rh)
	add_child(v)


func _build_top_bar() -> void:
	var h := Ui.hbox(10)
	h.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var c: Array = Ui.pill("coin", "0")
	_coins = c[1]
	var cr: Array = Ui.pill("crystal", "0")
	_crystals = cr[1]
	var rp: Array = Ui.pill("reputation", "0")
	_rep = rp[1]
	var tk: Array = Ui.pill("ticket", "5")
	_tickets = tk[1]
	tk[0].tooltip_text = "Билеты: тратятся, когда монстр уходит. +1 каждые 30 минут."
	h.add_child(tk[0])
	h.add_child(c[0])
	h.add_child(cr[0])
	h.add_child(rp[0])
	h.add_child(Ui.icon_button("gear", 58, "GhostButton", func() -> void: ui.open("settings_screen"), "Настройки"))
	add_child(h)
	h.offset_left = -600
	h.offset_right = -32
	h.offset_top = 22
	h.alignment = BoxContainer.ALIGNMENT_END


func _build_menu() -> void:
	var p := Ui.panel("GlassPanel")
	p.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	p.offset_left = -470
	p.offset_right = -40
	p.offset_top = -230
	p.offset_bottom = 150
	_buttons = Ui.vbox(12)
	p.add_child(_buttons)
	add_child(p)


func _update_tickets() -> void:
	if Tickets.full_version():
		_tickets.text = "∞"
		return
	var n: int = Tickets.count()
	_tickets.text = "%d/%d" % [n, Tickets.MAX] + ("" if n >= Tickets.MAX else "  " + Tickets.format_wait(Tickets.seconds_to_next()).substr(3))


func _refresh() -> void:
	_coins.text = str(EconomyManager.coins())
	_crystals.text = str(EconomyManager.crystals())
	_rep.text = str(EconomyManager.reputation())
	_update_tickets()
	Ui.clear(_buttons)
	if SaveManager.has_case_progress():
		var cp: Dictionary = SaveManager.profile["case_progress"]
		var title: String = case_title(cp)
		var cont := Ui.button("Продолжить дело", "play", "PrimaryButton", _continue_case, 70)
		cont.tooltip_text = "«%s», %s" % [title, Db.format_time(float(cp.get("clock", 0)))]
		_buttons.add_child(cont)
		_buttons.add_child(Ui.button("Кампания", "map", "CyanButton", func() -> void: ui.open("route_map_screen"), 64))
	else:
		_buttons.add_child(Ui.button("Кампания", "map", "PrimaryButton", func() -> void: ui.open("route_map_screen"), 70))
	_buttons.add_child(Ui.button("Развитие поезда", "train", "", func() -> void: ui.open("train_screen"), 60))
	_buttons.add_child(Ui.button("Коллекции", "collection", "", func() -> void: ui.open("collection_screen"), 60))
	var quests := Ui.button("Задания и события", "quest", "", func() -> void: ui.open("quests_screen"), 60)
	if _has_claimable():
		quests.text += "  •"
		quests.theme_type_variation = "PurpleButton"
	_buttons.add_child(quests)
	_buttons.add_child(Ui.button("Как играть", "question", "GhostButton", func() -> void: ui.open("help_screen"), 56))


## Название сохранённого дела: у уровней кампании — из data/campaign.json, у дела дня —
## «Дело дня», у дела-файла — из него. Сгенерированные дела не читаются как файлы.
static func case_title(cp: Dictionary) -> String:
	var lvl: Dictionary = Db.level(str(cp.get("level", "")))
	if not lvl.is_empty():
		return "Дело %d: %s" % [int(lvl["number"]), lvl["title"]]
	if str(cp.get("level", "")) == "daily":
		return "Дело дня"
	var cid: String = str(cp.get("case_id", ""))
	if Db.has_case(cid):
		return str(Db.case_data(cid).get("title", ""))
	return "Незавершённое дело"


func _has_claimable() -> bool:
	for key in ["daily", "weekly"]:
		for q: Dictionary in ProgressionManager.quest_entries(key):
			if not q["claimed"] and int(q["progress"]) >= int(q["goal"]):
				return true
	for a: Dictionary in Db.prog_list("achievements"):
		if not ProgressionManager.achievement_claimed(a["id"]) and ProgressionManager.stat(str(a["stat"])) >= int(a["goal"]):
			return true
	return false


func _continue_case() -> void:
	SaveManager.pending_case = str(SaveManager.profile["case_progress"]["case_id"])
	SaveManager.pending_resume = true
	get_tree().change_scene_to_file("res://game/game.tscn")


func start_case(case_id: String) -> void:
	SaveManager.clear_case_progress()
	SaveManager.pending_case = case_id
	SaveManager.pending_resume = false
	get_tree().change_scene_to_file("res://game/game.tscn")


var _ticket_tick: float = 0.0


func _process(delta: float) -> void:
	# Таймер билетов в верхней панели (обновляется раз в секунду).
	_ticket_tick -= delta
	if _ticket_tick <= 0.0 and _tickets:
		_ticket_tick = 1.0
		_update_tickets()
	_time += delta
	for l: Dictionary in _layers:
		l["offset"] = fmod(l["offset"] + l["speed"] * SCALE * delta * 10.0, l["w"])
		for i in l["rects"].size():
			var r: TextureRect = l["rects"][i]
			r.position.x = round(-l["offset"] + i * l["w"])
	if _train:
		_glow.modulate.a = 0.75 + 0.25 * sin(_time * 3.0) * sin(_time * 1.3)
		for i in _smoke.size():
			var s: TextureRect = _smoke[i]
			var k: float = fmod(_time * 0.6 + i * 0.25, 1.0)
			s.position = Vector2(96.0 - k * 170.0, -16.0 - k * 70.0)
			s.modulate.a = (1.0 - k) * 0.7
			s.scale = Vector2.ONE * (0.6 + k * 1.2)
