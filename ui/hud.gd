class_name Hud
extends Control
## Игровой экран (мобильная раскладка по референсу):
## сверху — время до станции и дело, одна текущая цель, валюты и пауза;
## снизу — джойстик слева, одна крупная контекстная кнопка справа («Осмотреть» /
## «Поговорить» / «Проверить») и компактные кнопки журнала (с числом новых улик) и камер.
## Центр экрана, где герой, остаётся свободным. Клавиши ПК работают, но на экране не подписаны.

const MIN_SIDE: float = 28.0

var game: Node
var joystick: TouchJoystick
var overlay: WorldOverlay
var interact_btn: Button
var journal_btn: Button
var cameras_btn: Button
var pause_btn: Button

var _time_label: Label
var _station_label: Label
var _trip_bar: ProgressBar
var _case_label: Label
var _goal_label: Label
var _coins: Label
var _crystals: Label
var _interact_label: Label
var _journal_badge: Label
var _toasts: VBoxContainer
var _top_left: Control
var _top_right: Control
var _goal_panel: Control
var _bottom_right: Control
var _new_clues: int = 0
var _warn: bool = false
var _target_kind: int = -1
var _banner: PanelContainer
var _dir_panel: PanelContainer
var _dir_label: Label
var _dir_icon: TextureRect
var _dir_target: Vector2
var _dir_left: float = 0.0


func setup(game_node: Node) -> void:
	game = game_node
	theme = UiTheme.theme
	Ui.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	overlay = WorldOverlay.new()
	add_child(overlay)

	# --- сверху слева: время, станция, дело
	var tl := Ui.panel("PillPanel")
	var tlv := Ui.vbox(2)
	var row := Ui.hbox(8)
	row.add_child(Ui.icon("hourglass", 34))
	# Крупный таймер: сколько игрового времени осталось до дедлайна (мм:сс).
	_time_label = Ui.label("20:00", "NumberLabel", 36)
	row.add_child(_time_label)
	_station_label = Ui.label("", "SmallLabel", 16)
	row.add_child(_station_label)
	tlv.add_child(row)
	_trip_bar = Ui.progress(0, 1, "CyanBar", 6)
	tlv.add_child(_trip_bar)
	_case_label = Ui.label("", "SmallLabel", 15)
	tlv.add_child(_case_label)
	tl.add_child(tlv)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_left = tl
	add_child(tl)

	# --- сверху по центру: одна текущая цель
	_goal_panel = Ui.panel("PillPanel")
	var gh := Ui.hbox(8)
	gh.add_child(Ui.icon("flag", 26))
	_goal_label = Ui.label("", "", 18)
	gh.add_child(_goal_label)
	_goal_panel.add_child(gh)
	_goal_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_goal_panel)

	# --- сверху справа: валюты и пауза
	var tr := Ui.hbox(8)
	# Только число найденных ключевых улик (какие именно — не подсказываем).
	var kc: Array = Ui.pill("magnifier", "0", 26)
	_coins = kc[1]
	tr.add_child(kc[0])
	pause_btn = Ui.icon_button("pause", 56, "GhostButton", func() -> void: game.ui.open("pause_menu"), "Пауза")
	tr.add_child(pause_btn)
	_top_right = tr
	add_child(tr)

	# --- снизу слева: джойстик (зона касания — левая нижняя часть экрана)
	joystick = TouchJoystick.new()
	add_child(joystick)

	# --- снизу справа: контекстная кнопка + журнал и камеры
	var br := Ui.hbox(14)
	br.alignment = BoxContainer.ALIGNMENT_END
	var ib := Ui.vbox(4)
	ib.alignment = BoxContainer.ALIGNMENT_END
	interact_btn = _round_button(128, func() -> void: _on_interact())
	interact_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ib.add_child(interact_btn)
	var lp := Ui.panel("PillPanel")
	_interact_label = Ui.label("Лупа", "", 20)
	_interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_label.custom_minimum_size.x = 132
	lp.add_child(_interact_label)
	lp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ib.add_child(lp)
	br.add_child(ib)
	var side := Ui.vbox(10)
	side.alignment = BoxContainer.ALIGNMENT_END
	cameras_btn = _compact_button("cctv", "Камеры", func() -> void: game.open_cameras())
	journal_btn = _compact_button("journal", "Журнал", func() -> void: game.open_journal())
	side.add_child(cameras_btn)
	side.add_child(journal_btn)
	_journal_badge = Ui.label("", "", 17)
	_journal_badge.add_theme_stylebox_override("normal", UiTheme.sb(UiTheme.DANGER, Color.WHITE, 2, 14, Color(0, 0, 0, 0.4), 3, Vector4(8, 0, 8, 1)))
	_journal_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_journal_badge.position = Vector2(66, -12)
	_journal_badge.visible = false
	journal_btn.add_child(_journal_badge)
	br.add_child(side)
	_bottom_right = br
	add_child(br)

	# --- уведомления: компактные, под верхней панелью
	_toasts = Ui.vbox(6)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)

	# --- крупный баннер события и указатель направления звука
	_banner = PanelContainer.new()
	_banner.add_theme_stylebox_override("panel", UiTheme.sb(Color(0.18, 0.03, 0.08, 0.92), UiTheme.DANGER, 3, 16, Color(UiTheme.DANGER, 0.45), 14, Vector4(28, 12, 28, 14)))
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	add_child(_banner)
	_dir_panel = Ui.panel("PillPanel")
	var dh := Ui.hbox(8)
	_dir_icon = Ui.icon("arrow_right", 34)
	_dir_icon.pivot_offset = Vector2(17, 17)
	_dir_label = Ui.label("", "", 20)
	dh.add_child(_dir_icon)
	dh.add_child(_dir_label)
	_dir_panel.add_child(dh)
	_dir_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dir_panel.visible = false
	add_child(_dir_panel)

	Events.toast.connect(show_toast)
	Events.profile_changed.connect(update_resources)
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	update_resources()
	set_target(null)
	_layout.call_deferred()


## Большая круглая кнопка в стиле референса: тёмная, с бирюзово-фиолетовым свечением.
func _round_button(size_px: int, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size_px, size_px)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 0)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_NONE
	var r: int = size_px / 2
	var pad := Vector4(24, 24, 24, 24)
	b.add_theme_stylebox_override("normal", UiTheme.sb(Color("#1d1656"), UiTheme.CYAN, 4, r, Color(UiTheme.PURPLE, 0.6), 14, pad))
	b.add_theme_stylebox_override("hover", UiTheme.sb(Color("#2a2070"), Color("#a8f0ff"), 4, r, Color(UiTheme.CYAN, 0.6), 18, pad))
	b.add_theme_stylebox_override("pressed", UiTheme.sb(Color("#3a2a90"), UiTheme.PINK, 4, r, Color(UiTheme.PINK, 0.5), 10, pad))
	b.add_theme_stylebox_override("hover_pressed", b.get_theme_stylebox("pressed"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	return b


func _compact_button(icon_name: String, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(88, 84)
	b.focus_mode = Control.FOCUS_NONE
	b.icon = Db.icon(icon_name)
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", 40)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.text = text
	b.add_theme_font_size_override("font_size", 16)
	var pad := Vector4(6, 8, 6, 6)
	b.add_theme_stylebox_override("normal", UiTheme.sb(Color("#241c62"), Color("#8a6af0"), 3, 16, Color(UiTheme.PURPLE, 0.45), 8, pad))
	b.add_theme_stylebox_override("hover", UiTheme.sb(Color("#2e247a"), UiTheme.CYAN, 3, 16, Color(UiTheme.CYAN, 0.45), 10, pad))
	b.add_theme_stylebox_override("pressed", UiTheme.sb(Color("#3a2a90"), UiTheme.PINK, 3, 16, Color.TRANSPARENT, 0, pad))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", UiTheme.TEXT)
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_color_override("font_outline_color", UiTheme.OUTLINE)
	b.pressed.connect(cb)
	b.pressed.connect(func() -> void: AudioManager.play_sfx("click", -6.0))
	return b


## Отступы от краёв с учётом выреза/закруглений экрана телефона.
func safe_insets() -> Vector4:
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var vs: Vector2 = get_viewport_rect().size
	if win.x <= 0 or safe.size.x <= 0 or not OS.has_feature("mobile"):
		return Vector4(MIN_SIDE, 14, MIN_SIDE, 12)
	var k: float = vs.x / win.x
	return Vector4(maxf(MIN_SIDE, safe.position.x * k + 8), maxf(14, safe.position.y * k + 6),
		maxf(MIN_SIDE, (win.x - safe.end.x) * k + 8), maxf(12, (win.y - safe.end.y) * k + 6))


func _layout() -> void:
	var vs: Vector2 = get_viewport_rect().size
	var ins: Vector4 = safe_insets()
	_top_left.position = Vector2(ins.x, ins.y)
	_top_right.reset_size()
	_top_right.position = Vector2(vs.x - ins.z - _top_right.get_combined_minimum_size().x, ins.y)
	_goal_panel.reset_size()
	var gw: float = _goal_panel.get_combined_minimum_size().x
	_goal_panel.position = Vector2(round((vs.x - gw) / 2.0), ins.y + 6)
	_toasts.position = Vector2(round(vs.x / 2.0 - 260), ins.y + 66)
	_toasts.size = Vector2(520, 0)
	joystick.position = Vector2(ins.x - 10, vs.y * 0.45)
	joystick.size = Vector2(minf(420.0, vs.x * 0.35), vs.y * 0.55 - ins.w)
	_bottom_right.reset_size()
	var bs: Vector2 = _bottom_right.get_combined_minimum_size()
	_bottom_right.position = Vector2(vs.x - ins.z - bs.x, vs.y - ins.w - bs.y)


func set_case_title(text: String) -> void:
	_case_label.text = text


func set_goal(text: String) -> void:
	if _goal_label.text == text:
		return
	_goal_label.text = text
	_layout.call_deferred()


func update_clock(minute: float, start: float, arrival: float, station: String) -> void:
	var left: float = maxf(0.0, arrival - minute)
	var secs: int = int(ceil(left * 60.0 - 0.001))
	_time_label.text = "%02d:%02d" % [secs / 60, secs % 60]
	_station_label.text = "до ст. " + station
	_trip_bar.max_value = arrival - start
	_trip_bar.value = minute - start
	var col: Color = UiTheme.TEXT
	if left <= 1.0:
		col = UiTheme.DANGER
	elif left <= 5.0:
		col = UiTheme.GOLD
	_time_label.add_theme_color_override("font_color", col)
	if left <= 1.0 and left > 0.0:
		_time_label.modulate.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() / 120.0)
	else:
		_time_label.modulate.a = 1.0


## Предупреждение о дедлайне: мягкое (10 мин), заметное (5), срочное (1). Управление не блокирует.
func deadline_warning(threshold: int) -> void:
	var texts := {10: "Осталось 10 минут", 5: "Осталось 5 минут! Пора делать выводы", 1: "Последняя минута! Задержите подозреваемого"}
	show_toast(str(texts.get(threshold, "")), "hourglass")
	if threshold <= 5:
		var tw := _time_label.create_tween()
		_time_label.pivot_offset = _time_label.size / 2.0
		for i in (2 if threshold == 5 else 4):
			tw.tween_property(_time_label, "scale", Vector2(1.25, 1.25), 0.15)
			tw.tween_property(_time_label, "scale", Vector2.ONE, 0.15)
		AudioManager.play_sfx("camera_beep", -4.0 if threshold == 1 else -10.0)


func set_key_clues(n: int) -> void:
	_coins.text = str(n)


func update_resources() -> void:
	pass


## Контекстная кнопка: подпись и значок зависят от того, что перед героем.
## Если рядом ничего нет — кнопка работает как лупа.
func set_target(target: Interactable, label_text: String = "") -> void:
	var icon_name: String = "magnifier"
	var text: String = "Лупа"
	_target_kind = -1 if target == null else target.kind
	if target:
		match target.kind:
			Interactable.Kind.NPC:
				icon_name = "talk"
				text = "Поговорить"
			Interactable.Kind.LUGGAGE:
				icon_name = "suitcase"
				text = "Проверить"
			Interactable.Kind.MONITOR:
				icon_name = "cctv"
				text = "Камеры"
			Interactable.Kind.DOOR:
				icon_name = "lock"
				text = "Дверь"
			_:
				icon_name = "magnifier"
				text = "Осмотреть"
	interact_btn.icon = Db.icon(icon_name)
	_interact_label.text = text
	overlay.set_prompt(target, label_text)


func _on_interact() -> void:
	AudioManager.play_sfx("click", -6.0)
	if _target_kind == -1:
		game.use_magnifier()
	else:
		game.interact()


func add_new_clue() -> void:
	_new_clues += 1
	_journal_badge.text = str(_new_clues)
	_journal_badge.visible = true
	var tw := journal_btn.create_tween()
	journal_btn.pivot_offset = journal_btn.size / 2.0
	tw.tween_property(journal_btn, "scale", Vector2(1.12, 1.12), 0.12)
	tw.tween_property(journal_btn, "scale", Vector2.ONE, 0.18)


func clear_new_clues() -> void:
	_new_clues = 0
	_journal_badge.visible = false


## Компактное уведомление в одну строку (не больше двух одновременно).
func show_toast(text: String, icon_name: String = "") -> void:
	var p := Ui.panel("PillPanel")
	var h := Ui.hbox(8)
	if icon_name != "":
		h.add_child(Ui.icon(icon_name, 26))
	var l := Ui.label(text, "", 18)
	h.add_child(l)
	p.add_child(h)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toasts.add_child(p)
	while _toasts.get_child_count() > 2:
		var old: Node = _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.35)
	tw.tween_callback(p.queue_free)


## Крупный баннер на несколько секунд (например, «ПРОИЗОШЛО УБИЙСТВО»).
func show_banner(title: String, subtitle: String, duration: float = 4.0) -> void:
	Ui.clear(_banner)
	var v := Ui.vbox(2)
	var t := Ui.label(title, "TitleLabel", 38)
	t.add_theme_color_override("font_color", Color("#ff6a7a"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := Ui.label(subtitle, "", 21)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	_banner.add_child(v)
	_banner.visible = true
	_banner.reset_size()
	var vs: Vector2 = get_viewport_rect().size
	_banner.position = Vector2(round((vs.x - _banner.get_combined_minimum_size().x) / 2.0), vs.y * 0.22)
	_banner.modulate.a = 0.0
	var tw := _banner.create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.2)
	tw.tween_interval(duration)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: _banner.visible = false)


## Указать направление на точку мира на несколько секунд (у края экрана, со стрелкой).
func show_direction(world_pos: Vector2, text: String, duration: float = 6.0) -> void:
	_dir_target = world_pos
	_dir_label.text = text
	_dir_left = duration
	_dir_panel.visible = true


func _process(delta: float) -> void:
	if _dir_left <= 0.0:
		return
	_dir_left -= delta
	if _dir_left <= 0.0:
		_dir_panel.visible = false
		return
	var vs: Vector2 = get_viewport_rect().size
	var sp: Vector2 = get_viewport().get_canvas_transform() * _dir_target
	var on_screen: bool = sp.x > 60 and sp.x < vs.x - 60
	_dir_panel.reset_size()
	var sz: Vector2 = _dir_panel.get_combined_minimum_size()
	var x: float
	if on_screen:
		x = clampf(sp.x - sz.x / 2.0, 20.0, vs.x - sz.x - 20.0)
		_dir_icon.rotation = PI / 2.0
	elif sp.x <= 60:
		x = 24.0
		_dir_icon.rotation = PI
	else:
		x = vs.x - sz.x - 24.0
		_dir_icon.rotation = 0.0
	_dir_panel.position = Vector2(round(x), round(vs.y * 0.36))
	_dir_panel.modulate.a = 0.6 + 0.4 * sin(_dir_left * 8.0)


func set_controls_visible(on: bool) -> void:
	joystick.visible = on
	_bottom_right.visible = on
	_goal_panel.visible = on
	overlay.visible = on
