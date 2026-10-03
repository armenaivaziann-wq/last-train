extends GameScreen
## Камеры наблюдения: слева список камер с живыми мини-превью (на телефоне — это и есть
## переключатель), справа одна крупная выбранная камера; снизу шкала времени с метками
## движения, воспроизведение/перемотка и «Отметить подозрительное».
## Все каналы — настоящие виды вагонов (общий World2D): пассажиры стоят там, где были
## в выбранный момент по хронологии дела.

const SPEEDS: Array = [[1.0, "×1"], [10.0, "×10"], [40.0, "×40"]]
const THUMB := Vector2(168, 84)

var cs: CameraSystem
var inv: InvestigationManager
var _cam_ids: Array[String] = []
var _selected: String = ""
var _big_box: Control
var _big: Dictionary = {}
var _thumbs: Dictionary = {}     # id → {button, camera}
var _timeline: TimelineBar
var _time_label: Label
var _play_btn: Button
var _speed: float = 10.0
var _speed_buttons: Array[Button] = []
var _playing: bool = false
var _t: float = 0.0
var _status: Label
var _cctv_mat: ShaderMaterial
var _anim_t: float = 0.0


func build(_args: Dictionary) -> void:
	cs = game.camera_system
	inv = game.investigation
	for cam in cs.cameras():
		_cam_ids.append(str(cam["id"]))
	_selected = _cam_ids[0]
	cs.begin_playback()
	game.highlight.set_target(null)
	_t = maxf(inv.history_start, inv.clock - 5.0)
	_cctv_mat = ShaderMaterial.new()
	_cctv_mat.shader = load("res://ui/cctv.gdshader")
	_cctv_mat.set_shader_parameter("night", 1.0 if ProgressionManager.equipment_level("cameras") >= 3 else 0.0)
	game.hud.visible = false

	var root := PanelContainer.new()
	root.add_theme_stylebox_override("panel", UiTheme.sb(Color("#0f0c2e"), Color("#7a5ae6"), 2, 18, Color(UiTheme.PURPLE, 0.25), 8, Vector4(16, 12, 16, 12)))
	var col := Ui.vbox(10)
	var head := Ui.hbox(12)
	head.add_child(Ui.icon("cctv", 40))
	head.add_child(Ui.label("Камеры наблюдения", "HeaderLabel", 28))
	head.add_child(Ui.spacer())
	_time_label = Ui.label("", "NumberLabel", 30)
	head.add_child(_time_label)
	head.add_child(Ui.icon_button("close", 52, "GhostButton", close, "Закрыть"))
	col.add_child(head)

	var row := Ui.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := Ui.vbox(8)
	for cam in cs.cameras():
		list.add_child(_thumb_item(cam))
	var side := Ui.vbox(8)
	side.custom_minimum_size.x = THUMB.x + 24
	side.add_child(Ui.scroll(list))
	row.add_child(side)
	var main := Ui.vbox(8)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_big_box = Control.new()
	_big_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_big_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_big_box.clip_contents = true
	_big_box.resized.connect(_fit_big)
	main.add_child(_big_box)
	_status = Ui.label("", "SmallLabel", 17)
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	main.add_child(_status)
	row.add_child(main)
	col.add_child(row)

	_timeline = TimelineBar.new()
	_timeline.t_from = inv.history_start
	_timeline.t_to = inv.clock
	_timeline.scrubbed.connect(_on_scrub)
	col.add_child(_timeline)
	var ctrl := Ui.hbox(10)
	ctrl.add_child(Ui.icon_button("rewind", 60, "GhostButton", func() -> void: _jump(-1.0), "−1 минута"))
	_play_btn = Ui.icon_button("play", 60, "CyanButton", _toggle_play, "Воспроизведение / пауза")
	ctrl.add_child(_play_btn)
	ctrl.add_child(Ui.icon_button("ffwd", 60, "GhostButton", func() -> void: _jump(1.0), "+1 минута"))
	for s: Array in SPEEDS:
		if s[0] >= 40.0 and ProgressionManager.equipment_level("cameras") < 2:
			continue
		var sb := Ui.button(s[1], "", "ChipButton", func() -> void: _set_speed(s[0]), 52)
		sb.toggle_mode = true
		sb.set_meta("speed", s[0])
		_speed_buttons.append(sb)
		ctrl.add_child(sb)
	ctrl.add_child(Ui.spacer())
	ctrl.add_child(Ui.button("Отметить подозрительное", "flag", "PrimaryButton", _mark, 60))
	col.add_child(ctrl)
	root.add_child(col)
	safe_margin(root, 22, 14)
	_set_speed(_speed)
	_select(_selected)


func _make_view(rect: Rect2, view_size: Vector2) -> Dictionary:
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.material = _cctv_mat
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	svc.custom_minimum_size = view_size
	var vp := SubViewport.new()
	vp.world_2d = game.get_viewport().world_2d
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.size = Vector2i(view_size)
	var cam := Camera2D.new()
	vp.add_child(cam)
	_aim(cam, rect, view_size)
	svc.add_child(vp)
	return {"container": svc, "camera": cam, "viewport": vp}


func _thumb_item(cam: Dictionary) -> Control:
	var id: String = str(cam["id"])
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(THUMB.x + 12, THUMB.y + 40)
	var pad := Vector4(6, 6, 6, 6)
	b.add_theme_stylebox_override("normal", UiTheme.sb(Color("#181446"), Color("#3b3f96"), 2, 12, Color.TRANSPARENT, 0, pad))
	b.add_theme_stylebox_override("hover", UiTheme.sb(Color("#201a5a"), UiTheme.CYAN, 2, 12, Color.TRANSPARENT, 0, pad))
	b.add_theme_stylebox_override("pressed", UiTheme.sb(Color("#2a1e70"), UiTheme.PINK, 3, 12, Color(UiTheme.PINK, 0.3), 6, pad))
	b.add_theme_stylebox_override("hover_pressed", b.get_theme_stylebox("pressed"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void:
		AudioManager.play_sfx("camera_beep", -10.0)
		_select(id))
	var v := Ui.vbox(4)
	v.position = Vector2(6, 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view: Dictionary = _make_view(cam["rect"], THUMB)
	v.add_child(view["container"])
	var l := Ui.label("К%s · %s" % [id.substr(3), cam["name"]], "", 15)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size.x = THUMB.x
	v.add_child(l)
	b.add_child(v)
	_thumbs[id] = {"button": b}
	return b


func _select(id: String) -> void:
	_selected = id
	for k: String in _thumbs:
		_thumbs[k]["button"].set_pressed_no_signal(k == id)
	if not _big.is_empty():
		_big["frame"].queue_free()
	var cam: Dictionary = cs.layout.camera(id)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.sb(Color.BLACK, UiTheme.CYAN, 2, 12, Color(UiTheme.CYAN, 0.2), 6, Vector4(3, 3, 3, 3)))
	var view: Dictionary = _make_view(cam["rect"], Vector2(800, 400))
	frame.add_child(view["container"])
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := Ui.hbox(8)
	top.position = Vector2(12, 8)
	var rec := Ui.label("● REC", "", 16)
	rec.add_theme_color_override("font_color", UiTheme.DANGER)
	top.add_child(rec)
	top.add_child(Ui.label("К%s · %s" % [id.substr(3), cam["name"]], "", 18))
	overlay.add_child(top)
	frame.add_child(overlay)
	_big_box.add_child(frame)
	_big = {"frame": frame, "view": view, "rect": cam["rect"], "rec": rec}
	_fit_big()
	_refresh_markers()
	_apply_time()


func _fit_big() -> void:
	if _big.is_empty():
		return
	var area: Vector2 = _big_box.size if _big_box.size.x > 10 else Vector2(900, 420)
	var frame: PanelContainer = _big["frame"]
	frame.position = Vector2.ZERO
	frame.size = area
	var inner: Vector2 = area - Vector2(6, 6)
	var svc: SubViewportContainer = _big["view"]["container"]
	svc.custom_minimum_size = inner
	(_big["view"]["viewport"] as SubViewport).size = Vector2i(inner)
	_aim(_big["view"]["camera"], _big["rect"], inner)


## Наводит камеру на область кадра. Если кадр шире области (узкое купе), центр
## сдвигается внутрь поезда, чтобы по бокам не было пустоты за вагонами.
func _aim(cam: Camera2D, rect: Rect2, view_size: Vector2) -> void:
	var z: float = minf(view_size.x / rect.size.x, view_size.y / rect.size.y)
	cam.zoom = Vector2(z, z)
	var half_w: float = view_size.x / z / 2.0
	var center: Vector2 = rect.get_center()
	var w: float = cs.layout.width
	center.x = clampf(center.x, half_w, maxf(half_w, w - half_w))
	cam.position = center


func _refresh_markers() -> void:
	var markers: Array = []
	if ProgressionManager.equipment_level("cameras") >= 2:
		for m: Dictionary in cs.motion_markers(_selected):
			markers.append({"t": m["t"], "color": Color(str(Db.character(str(m["npc"])).get("color", "#5ad6ff"))).lightened(0.3)})
	_timeline.markers = markers
	var books: Array = []
	for cc: Dictionary in game.case_data.get("camera_clues", []):
		if inv.evidence.has(str(cc["id"])):
			books.append(Db.parse_time(str(cc["windows"][0][0])))
	_timeline.bookmarks = books
	_timeline.queue_redraw()


func _set_speed(s: float) -> void:
	_speed = s
	for b in _speed_buttons:
		b.set_pressed_no_signal(float(b.get_meta("speed")) == s)


func _toggle_play() -> void:
	_playing = not _playing
	if _playing and _t >= inv.clock - 0.01:
		_t = inv.history_start
	_play_btn.icon = Db.icon("pause" if _playing else "play")


func _jump(minutes: float) -> void:
	_t = clampf(_t + minutes, inv.history_start, inv.clock)
	_apply_time()


func _on_scrub(t: float) -> void:
	_t = t
	_apply_time()


func _apply_time() -> void:
	cs.set_time(_t)
	_timeline.set_value(_t)
	_time_label.text = Db.format_time(_t, true)
	var who: Array[String] = cs.visible_on(_selected, _t)
	if who.is_empty():
		_status.text = "В кадре никого. Перематывайте шкалу — метки показывают движение."
	else:
		var names: PackedStringArray = []
		for id in who:
			names.append(Db.char_name(id))
		_status.text = "В кадре: " + ", ".join(names)


func _process(delta: float) -> void:
	_anim_t += delta
	_cctv_mat.set_shader_parameter("time_s", _anim_t)
	if not _big.is_empty():
		_big["rec"].visible = fmod(_anim_t, 1.2) < 0.8
	if _playing:
		_t += delta * _speed / inv.seconds_per_minute
		if _t >= inv.clock:
			_t = inv.clock
			_toggle_play()
		_apply_time()


func _mark() -> void:
	AudioManager.play_sfx("shutter")
	var added: Array[String] = inv.mark_camera(_selected, _t)
	if added.is_empty():
		_status.text = "В %s на камере К%s нет ничего подозрительного." % [Db.format_time(_t), _selected.substr(3)]
	else:
		_status.text = "Отмечено: " + str(inv.evidence.clue(added[0])["title"])
	_refresh_markers()


func close() -> void:
	cs.end_playback()
	game.hud.visible = true
	game.highlight.set_target(game.player.target)
	super.close()
