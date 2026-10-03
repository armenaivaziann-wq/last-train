class_name Ui
extends RefCounted
## Фабрика элементов интерфейса в едином стиле (панели, кнопки, иконки, плашки ресурсов).
## Экраны строятся кодом из данных — тексты настоящие, их можно читать и локализовать.


static func label(text: String, variation: String = "", size: int = 0, autowrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if autowrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 40
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func rich(text: String, size: int = 0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = text
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	if size > 0:
		r.add_theme_font_size_override("normal_font_size", size)
		r.add_theme_font_size_override("bold_font_size", size)
	return r


static func button(text: String, icon_name: String = "", variation: String = "", cb: Callable = Callable(), min_h: int = 60) -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	if icon_name != "":
		b.icon = Db.icon(icon_name)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 36)
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_NONE
	if cb.is_valid():
		b.pressed.connect(cb)
	b.pressed.connect(func() -> void: AudioManager.play_sfx("click", -6.0))
	return b


static func icon_button(icon_name: String, size: int = 72, variation: String = "GhostButton", cb: Callable = Callable(), tooltip: String = "") -> Button:
	var b := Button.new()
	b.theme_type_variation = variation
	b.icon = Db.icon(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tooltip
	var pad: int = int(size * 0.18)
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box: StyleBox = b.get_theme_stylebox(st).duplicate()
		if box is StyleBoxFlat:
			(box as StyleBoxFlat).set_corner_radius_all(int(size * 0.32))
			box.content_margin_left = pad
			box.content_margin_right = pad
			box.content_margin_top = pad
			box.content_margin_bottom = pad
		b.add_theme_stylebox_override(st, box)
	if cb.is_valid():
		b.pressed.connect(cb)
	b.pressed.connect(func() -> void: AudioManager.play_sfx("click", -6.0))
	return b


static func icon(icon_name: String, size: int = 32) -> TextureRect:
	return tex(Db.icon(icon_name), size)


static func tex(texture: Texture2D, size: int = 64, size_y: int = -1) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size if size_y < 0 else size_y)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func panel(variation: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	if variation != "":
		p.theme_type_variation = variation
	return p


static func vbox(sep: int = 10) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func hbox(sep: int = 10) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


static func grid(columns: int, sep: int = 10) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	return g


static func margin(l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	return m


static func spacer(expand_h: bool = true, expand_v: bool = false) -> Control:
	var c := Control.new()
	if expand_h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if expand_v:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func scroll(content: Control, horizontal: bool = false) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if horizontal else ScrollContainer.SCROLL_MODE_DISABLED
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if horizontal else ScrollContainer.SCROLL_MODE_AUTO
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s


## Плашка ресурса: иконка + число. Возвращает [панель, подпись].
static func pill(icon_name: String, text: String, icon_size: int = 30) -> Array:
	var p := panel("PillPanel")
	var h := hbox(8)
	h.add_child(icon(icon_name, icon_size))
	var l := label(text, "NumberLabel")
	h.add_child(l)
	p.add_child(h)
	return [p, l]


## Портрет в рамке (пиксельный, увеличенный).
static func portrait(texture: Texture2D, size: int = 96, border: Color = UiTheme.BORDER, bg: Color = Color("#2a2266")) -> PanelContainer:
	var p := PanelContainer.new()
	var box := UiTheme.sb(bg, border, 3, int(size * 0.22), Color(border, 0.3), 6, Vector4(4, 4, 4, 4))
	p.add_theme_stylebox_override("panel", box)
	p.add_child(tex(texture, size))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func chip(text: String, color: Color, icon_name: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.sb(Color(color, 0.22), color, 2, 12, Color.TRANSPARENT, 0, Vector4(8, 2, 10, 2)))
	var h := hbox(4)
	if icon_name != "":
		h.add_child(icon(icon_name, 20))
	var l := label(text, "", 16)
	l.add_theme_color_override("font_color", color.lightened(0.35))
	h.add_child(l)
	p.add_child(h)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func progress(value: float, max_value: float, variation: String = "", height: int = 18) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = max_value
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(80, height)
	if variation != "":
		b.theme_type_variation = variation
	return b


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
	return c


static func center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	full_rect(cc)
	cc.add_child(c)
	return cc


## Заголовок экрана: иконка + текст + кнопка закрытия.
static func header(title: String, icon_name: String, on_close: Callable) -> HBoxContainer:
	var h := hbox(12)
	if icon_name != "":
		h.add_child(icon(icon_name, 44))
	h.add_child(label(title, "HeaderLabel"))
	h.add_child(spacer())
	if on_close.is_valid():
		h.add_child(icon_button("close", 56, "GhostButton", on_close, "Закрыть (Esc)"))
	return h


static func clue_color(type: String) -> Color:
	return UiTheme.CLUE_COLORS.get(type, UiTheme.TEXT)


static func clue_icon(type: String) -> String:
	return UiTheme.CLUE_ICONS.get(type, "item")
