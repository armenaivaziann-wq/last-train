class_name Hud
extends Control
## Игровой экран: время до станции, ресурсы, пауза, кнопки журнала/камер/карты справа,
## джойстик слева, контекстная кнопка взаимодействия и лупа справа внизу, уведомления.
## Не перекрывает центр экрана, где находится герой.

const SIDE: int = 28

var game: Node
var joystick: TouchJoystick
var overlay: WorldOverlay
var interact_btn: Button
var magnifier_btn: Button
var journal_btn: Button
var cameras_btn: Button
var map_btn: Button
var pause_btn: Button

var _time_label: Label
var _station_label: Label
var _trip_bar: ProgressBar
var _coins: Label
var _crystals: Label
var _interact_label: Label
var _journal_badge: Label
var _toasts: VBoxContainer
var _case_label: Label
var _new_clues: int = 0
var _warn: bool = false


func setup(game_node: Node) -> void:
	game = game_node
	Ui.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	overlay = WorldOverlay.new()
	add_child(overlay)

	# --- слева сверху: время и станция
	var tl := Ui.panel("GlassPanel")
	tl.position = Vector2(SIDE, 18)
	var tlv := Ui.vbox(4)
	var row := Ui.hbox(10)
	row.add_child(Ui.icon("clock", 34))
	_time_label = Ui.label("01:58", "NumberLabel", 28)
	row.add_child(_time_label)
	row.add_child(Ui.icon("arrow_right", 22))
	_station_label = Ui.label("Долина 02:12", "GoldLabel", 20)
	row.add_child(_station_label)
	tlv.add_child(row)
	_trip_bar = Ui.progress(0, 1, "CyanBar", 10)
	_trip_bar.custom_minimum_size.x = 250
	tlv.add_child(_trip_bar)
	_case_label = Ui.label("", "SmallLabel", 16)
	tlv.add_child(_case_label)
	tl.add_child(tlv)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tl)

	# --- справа сверху: ресурсы и пауза
	var tr := Ui.hbox(10)
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.position = Vector2(-SIDE, 18)
	var c: Array = Ui.pill("coin", "0", 28)
	_coins = c[1]
	tr.add_child(c[0])
	var cr: Array = Ui.pill("crystal", "0", 28)
	_crystals = cr[1]
	tr.add_child(cr[0])
	pause_btn = Ui.icon_button("pause", 60, "GhostButton", func() -> void: game.ui.open("pause_menu"), "Пауза (Esc)")
	tr.add_child(pause_btn)
	add_child(tr)
	tr.offset_left = -tr.get_combined_minimum_size().x - SIDE
	tr.offset_right = -SIDE

	# --- справа по центру: журнал, камеры, карта поезда
	var side := Ui.vbox(14)
	side.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	journal_btn = _side_button("journal", "J", func() -> void: game.open_journal())
	cameras_btn = _side_button("cctv", "C", func() -> void: game.open_cameras())
	map_btn = _side_button("map", "M", func() -> void: game.open_train_map())
	side.add_child(journal_btn)
	side.add_child(cameras_btn)
	side.add_child(map_btn)
	add_child(side)
	side.offset_left = -84 - SIDE
	side.offset_right = -SIDE
	side.offset_top = -150
	side.offset_bottom = 150
	_journal_badge = Ui.label("", "", 16)
	_journal_badge.add_theme_stylebox_override("normal", UiTheme.sb(UiTheme.PINK, Color.WHITE, 2, 12, Color.TRANSPARENT, 0, Vector4(6, 0, 6, 0)))
	_journal_badge.position = Vector2(52, -6)
	_journal_badge.visible = false
	journal_btn.add_child(_journal_badge)

	# --- слева снизу: джойстик (зона касания — левая нижняя часть экрана)
	joystick = TouchJoystick.new()
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.offset_left = SIDE - 10
	joystick.offset_top = -300
	joystick.offset_right = 420
	joystick.offset_bottom = -12
	add_child(joystick)

	# --- справа снизу: лупа и кнопка взаимодействия
	var br := Ui.hbox(18)
	br.alignment = BoxContainer.ALIGNMENT_END
	br.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	magnifier_btn = Ui.icon_button("magnifier", 84, "CyanButton", func() -> void: game.use_magnifier(), "Лупа (Q)")
	_key_hint(magnifier_btn, "Q")
	var mag_box := Ui.vbox(0)
	mag_box.alignment = BoxContainer.ALIGNMENT_END
	mag_box.add_child(magnifier_btn)
	br.add_child(mag_box)
	var ib := Ui.vbox(6)
	ib.alignment = BoxContainer.ALIGNMENT_END
	interact_btn = Ui.icon_button("hand", 116, "PrimaryButton", func() -> void: game.interact(), "Действие (E)")
	_key_hint(interact_btn, "E")
	ib.add_child(interact_btn)
	var lp := Ui.panel("PillPanel")
	_interact_label = Ui.label("—", "", 18)
	_interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_label.custom_minimum_size.x = 150
	lp.add_child(_interact_label)
	ib.add_child(lp)
	br.add_child(ib)
	add_child(br)
	br.offset_left = -360 - SIDE
	br.offset_right = -SIDE
	br.offset_top = -200
	br.offset_bottom = -16

	# --- уведомления сверху по центру
	_toasts = Ui.vbox(8)
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.offset_left = -330
	_toasts.offset_right = 330
	_toasts.offset_top = 96
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(_toasts)

	Events.toast.connect(show_toast)
	Events.profile_changed.connect(update_resources)
	update_resources()
	set_target(null)


func _side_button(icon_name: String, key: String, cb: Callable) -> Button:
	var b := Ui.icon_button(icon_name, 76, "GhostButton", cb)
	_key_hint(b, key)
	return b


func _key_hint(b: Button, key: String) -> void:
	if OS.has_feature("mobile"):
		return
	var k := Ui.label(key, "", 14)
	k.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	k.position = Vector2(6, 2)
	b.add_child(k)


func set_case_title(text: String) -> void:
	_case_label.text = text


func update_clock(minute: float, start: float, arrival: float, station: String) -> void:
	_time_label.text = Db.format_time(minute)
	_station_label.text = "%s %s" % [station, Db.format_time(arrival)]
	_trip_bar.max_value = arrival - start
	_trip_bar.value = minute - start
	var left: float = arrival - minute
	var warn: bool = left <= 3.0
	if warn != _warn:
		_warn = warn
		_time_label.add_theme_color_override("font_color", UiTheme.DANGER if warn else UiTheme.TEXT)


func update_resources() -> void:
	_coins.text = str(EconomyManager.coins())
	_crystals.text = str(EconomyManager.crystals())


func set_target(target: Interactable, label_text: String = "") -> void:
	interact_btn.disabled = target == null
	_interact_label.text = label_text if target else "—"
	interact_btn.icon = Db.icon(target.icon_name() if target else "hand")
	overlay.set_prompt(target, label_text)


func add_new_clue() -> void:
	_new_clues += 1
	_journal_badge.text = str(_new_clues)
	_journal_badge.visible = true


func clear_new_clues() -> void:
	_new_clues = 0
	_journal_badge.visible = false


func show_toast(text: String, icon_name: String = "") -> void:
	var p := Ui.panel("HighlightPanel")
	var h := Ui.hbox(10)
	if icon_name != "":
		h.add_child(Ui.icon(icon_name, 34))
	var l := Ui.label(text, "", 20, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	p.add_child(h)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(p)
	if _toasts.get_child_count() > 3:
		_toasts.get_child(0).queue_free()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.8)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


func set_controls_visible(on: bool) -> void:
	joystick.visible = on
	interact_btn.get_parent().get_parent().visible = on
	journal_btn.get_parent().visible = on
	overlay.visible = on
