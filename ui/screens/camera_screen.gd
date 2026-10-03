extends GameScreen
## Камеры наблюдения: сетка из 4 камер или одна крупно, шкала времени с метками движения,
## воспроизведение/пауза/скорость, перемотка, отметка подозрительного момента.
## Каналы — это настоящие виды вагонов (общий World2D), пассажиры стоят там,
## где были в выбранный момент по хронологии дела.

const SPEEDS: Array = [[1.0, "×1"], [10.0, "×10"], [40.0, "×40"]]

var cs: CameraSystem
var inv: InvestigationManager
var _cam_ids: Array[String] = []
var _selected: String = ""
var _grid_mode: bool = true
var _feeds_box: Control
var _feeds: Array = []   # [{id, container, camera, label}]
var _timeline: TimelineBar
var _time_label: Label
var _play_btn: Button
var _speed: float = 10.0
var _playing: bool = false
var _t: float = 0.0
var _cam_buttons: Dictionary = {}
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
	_t = maxf(inv.history_start, inv.clock - 5.0)
	_cctv_mat = ShaderMaterial.new()
	_cctv_mat.shader = load("res://ui/cctv.gdshader")
	_cctv_mat.set_shader_parameter("night", 1.0 if ProgressionManager.equipment_level("cameras") >= 3 else 0.0)
	game.hud.visible = false

	var root := Ui.panel()
	var col := Ui.vbox(12)
	var head := Ui.header("Камеры наблюдения", "cctv", close)
	col.add_child(head)
	var row := Ui.hbox(16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var side := Ui.vbox(10)
	side.custom_minimum_size.x = 230
	var grid_btn := Ui.button("Все камеры", "collection", "TabButton", func() -> void: _set_grid(true), 56)
	grid_btn.toggle_mode = true
	_cam_buttons["grid"] = grid_btn
	side.add_child(grid_btn)
	for cam in cs.cameras():
		var id: String = str(cam["id"])
		var b := Ui.button("К%s · %s" % [id.substr(3), cam["name"]], "cctv", "TabButton", func() -> void: _select(id), 56)
		b.toggle_mode = true
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 17)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_cam_buttons[id] = b
		side.add_child(b)
	side.add_child(Ui.spacer(false, true))
	_status = Ui.label("", "SmallLabel", 17, true)
	side.add_child(_status)
	row.add_child(side)
	_feeds_box = Control.new()
	_feeds_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feeds_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_feeds_box.clip_contents = true
	row.add_child(_feeds_box)
	col.add_child(row)

	var bar := Ui.panel("GlassPanel")
	var bv := Ui.vbox(8)
	_timeline = TimelineBar.new()
	_timeline.t_from = inv.history_start
	_timeline.t_to = inv.clock
	_timeline.scrubbed.connect(_on_scrub)
	bv.add_child(_timeline)
	var ctrl := Ui.hbox(10)
	_time_label = Ui.label("", "NumberLabel", 28)
	_time_label.custom_minimum_size.x = 130
	ctrl.add_child(_time_label)
	ctrl.add_child(Ui.icon_button("rewind", 56, "GhostButton", func() -> void: _jump(-1.0), "−1 минута"))
	_play_btn = Ui.icon_button("play", 56, "CyanButton", _toggle_play, "Воспроизведение / пауза")
	ctrl.add_child(_play_btn)
	ctrl.add_child(Ui.icon_button("ffwd", 56, "GhostButton", func() -> void: _jump(1.0), "+1 минута"))
	for s: Array in SPEEDS:
		if s[0] >= 40.0 and ProgressionManager.equipment_level("cameras") < 2:
			continue
		var sb := Ui.button(s[1], "", "ChipButton", func() -> void: _set_speed(s[0]), 50)
		sb.toggle_mode = true
		sb.set_meta("speed", s[0])
		ctrl.add_child(sb)
	ctrl.add_child(Ui.spacer())
	ctrl.add_child(Ui.button("Отметить подозрительное", "flag", "PrimaryButton", _mark, 58))
	bv.add_child(ctrl)
	bar.add_child(bv)
	col.add_child(bar)
	root.add_child(col)
	safe_margin(root, 26, 16)
	_set_speed(_speed)
	_set_grid(true)
	_refresh_markers()
	_apply_time()


func _set_grid(on: bool) -> void:
	_grid_mode = on
	_rebuild_feeds.call_deferred()


func _select(id: String) -> void:
	_selected = id
	_grid_mode = false
	_rebuild_feeds.call_deferred()
	_refresh_markers()


func _rebuild_feeds() -> void:
	for f: Dictionary in _feeds:
		f["container"].queue_free()
	_feeds.clear()
	for k: String in _cam_buttons:
		_cam_buttons[k].set_pressed_no_signal((k == "grid" and _grid_mode) or (not _grid_mode and k == _selected))
	var area: Vector2 = _feeds_box.size
	if area.x < 10:
		area = Vector2(900, 470)
	if _grid_mode:
		var w: float = floor((area.x - 12) / 2.0)
		var h: float = floor((area.y - 12) / 2.0)
		for i in _cam_ids.size():
			_add_feed(_cam_ids[i], Rect2(Vector2((i % 2) * (w + 12), (i / 2) * (h + 12)), Vector2(w, h)))
	else:
		_add_feed(_selected, Rect2(Vector2.ZERO, area))
	_apply_time()


func _add_feed(id: String, r: Rect2) -> void:
	var cam: Dictionary = cs.layout.camera(id)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.sb(Color.BLACK, UiTheme.BORDER, 3, 12, Color(UiTheme.BORDER, 0.25), 6, Vector4(4, 4, 4, 4)))
	frame.position = r.position
	frame.size = r.size
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.material = _cctv_mat
	svc.mouse_filter = Control.MOUSE_FILTER_PASS
	var vp := SubViewport.new()
	vp.world_2d = game.get_viewport().world_2d
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.size = Vector2i(r.size - Vector2(8, 8))
	var c2d := Camera2D.new()
	var rect: Rect2 = cam["rect"]
	c2d.position = rect.get_center()
	var z: float = minf((r.size.x - 8) / rect.size.x, (r.size.y - 8) / rect.size.y)
	c2d.zoom = Vector2(z, z)
	vp.add_child(c2d)
	svc.add_child(vp)
	frame.add_child(svc)
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := Ui.hbox(8)
	top.position = Vector2(10, 8)
	var rec := Ui.label("● REC", "", 16)
	rec.add_theme_color_override("font_color", UiTheme.DANGER)
	top.add_child(rec)
	top.add_child(Ui.label("К%s · %s" % [id.substr(3), cam["name"]], "", 17))
	overlay.add_child(top)
	var ts := Ui.label("", "NumberLabel", 18)
	ts.position = Vector2(10, r.size.y - 40)
	overlay.add_child(ts)
	frame.add_child(overlay)
	if _grid_mode:
		var click := Button.new()
		click.flat = true
		click.focus_mode = Control.FOCUS_NONE
		click.pressed.connect(func() -> void: _select(id))
		frame.add_child(click)
	_feeds_box.add_child(frame)
	_feeds.append({"id": id, "container": frame, "label": ts, "rec": rec})


func _refresh_markers() -> void:
	var markers: Array = []
	if ProgressionManager.equipment_level("cameras") >= 2:
		var ids: Array[String] = _cam_ids if _grid_mode else [_selected] as Array[String]
		for id in ids:
			for m: Dictionary in cs.motion_markers(id):
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
	for n in _play_btn.get_parent().get_children():
		if n is Button and n.has_meta("speed"):
			(n as Button).set_pressed_no_signal(float(n.get_meta("speed")) == s)


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
	for f: Dictionary in _feeds:
		f["label"].text = Db.format_time(_t, true)
	var who: Array[String] = []
	if not _grid_mode:
		who = cs.visible_on(_selected, _t)
	if _grid_mode:
		_status.text = "Нажмите на камеру, чтобы развернуть её. Метки на шкале — движение в кадре."
	elif who.is_empty():
		_status.text = "В кадре никого."
	else:
		var names: PackedStringArray = []
		for id in who:
			names.append(Db.char_name(id))
		_status.text = "В кадре: " + ", ".join(names)


func _process(delta: float) -> void:
	_anim_t += delta
	_cctv_mat.set_shader_parameter("time_s", _anim_t)
	for f: Dictionary in _feeds:
		f["rec"].visible = fmod(_anim_t, 1.2) < 0.8
	if _playing:
		_t += delta * _speed / inv.seconds_per_minute
		if _t >= inv.clock:
			_t = inv.clock
			_toggle_play()
		_apply_time()


func _mark() -> void:
	var cam_id: String = _selected
	if _grid_mode:
		_status.text = "Сначала разверните камеру, на которой заметили странность."
		AudioManager.play_sfx("wrong", -10.0)
		return
	AudioManager.play_sfx("shutter")
	var added: Array[String] = inv.mark_camera(cam_id, _t)
	if added.is_empty():
		_status.text = "В %s на камере К%s нет ничего подозрительного." % [Db.format_time(_t), cam_id.substr(3)]
	else:
		_status.text = "Отмечено: " + str(inv.evidence.clue(added[0])["title"])
	_refresh_markers()


func close() -> void:
	cs.end_playback()
	game.hud.visible = true
	super.close()
