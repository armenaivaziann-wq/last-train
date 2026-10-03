extends Node
## Визуальный язык интерфейса по референсу: тёмно-синие и фиолетовые панели, яркие голубые
## контуры, округлые карточки, золотые акценты, крупный читаемый текст. Тема собирается кодом
## и назначается корневому окну — все Control-узлы получают её автоматически.

const BG_DEEP := Color("#0b0a22")
const PANEL := Color("#16133c")
const PANEL_2 := Color("#211c55")
const CARD := Color("#1c1848")
const INSET := Color("#0f0d2a")
const BORDER := Color("#4fd0ff")
const BORDER_DIM := Color("#3b3f96")
const PURPLE := Color("#9b5cf6")
const PURPLE_D := Color("#5a2fc8")
const PINK := Color("#ff5aa8")
const GOLD := Color("#f2c14e")
const GOLD_D := Color("#c0782a")
const TEXT := Color("#f4f0ff")
const TEXT_DIM := Color("#aaa6dc")
const DANGER := Color("#ff4a6a")
const SUCCESS := Color("#4ae08a")
const CYAN := Color("#5ad6ff")
const OUTLINE := Color("#120e30")

## Цвета типов улик.
const CLUE_COLORS: Dictionary = {
	"document": Color("#ffd27a"), "physical": Color("#ff9a5a"), "item": Color("#c08aff"),
	"camera": Color("#5ad6ff"), "testimony": Color("#ff8ac8"), "contradiction": Color("#ffe14a"),
}
const CLUE_ICONS: Dictionary = {
	"document": "document", "physical": "footprint", "item": "item", "camera": "video",
	"testimony": "testimony", "contradiction": "contradiction",
}
const CLUE_TYPE_NAMES: Dictionary = {
	"document": "Документ", "physical": "Физический след", "item": "Предмет", "camera": "Запись камеры",
	"testimony": "Показание", "contradiction": "Вывод",
}

var theme: Theme
var font: Font
var font_bold: Font


func _ready() -> void:
	theme = build()
	get_tree().root.theme = theme


func sb(bg: Color, border: Color = Color.TRANSPARENT, bw: int = 0, radius: int = 16,
		shadow: Color = Color.TRANSPARENT, shadow_size: int = 0, margin: Vector4 = Vector4(14, 10, 14, 10)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.shadow_color = shadow
	s.shadow_size = shadow_size
	s.content_margin_left = margin.x
	s.content_margin_top = margin.y
	s.content_margin_right = margin.z
	s.content_margin_bottom = margin.w
	s.anti_aliasing = true
	return s


func build() -> Theme:
	var t := Theme.new()
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Nunito", "Rubik", "Montserrat", "Roboto", "Helvetica Neue", "Arial", "sans-serif"])
	sys.font_weight = 700
	sys.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font = sys
	var bold := SystemFont.new()
	bold.font_names = sys.font_names
	bold.font_weight = 900
	font_bold = bold
	t.default_font = font
	t.default_font_size = 22

	# Панели
	t.set_stylebox("panel", "PanelContainer", sb(Color(PANEL, 0.97), BORDER, 3, 20, Color(BORDER, 0.28), 10, Vector4(18, 16, 18, 16)))
	t.set_stylebox("panel", "Panel", sb(Color(PANEL, 0.97), BORDER, 3, 20, Color(BORDER, 0.28), 10))
	_variation(t, "CardPanel", "PanelContainer", sb(CARD, BORDER_DIM, 2, 16, Color.TRANSPARENT, 0, Vector4(12, 10, 12, 10)))
	_variation(t, "InsetPanel", "PanelContainer", sb(INSET, Color(BORDER_DIM, 0.8), 2, 14, Color.TRANSPARENT, 0, Vector4(10, 8, 10, 8)))
	_variation(t, "PillPanel", "PanelContainer", sb(Color(INSET, 0.92), Color(BORDER, 0.75), 2, 24, Color(0, 0, 0, 0.35), 4, Vector4(12, 4, 16, 4)))
	_variation(t, "GlassPanel", "PanelContainer", sb(Color(PANEL, 0.82), Color(BORDER, 0.6), 2, 18, Color.TRANSPARENT, 0, Vector4(14, 10, 14, 10)))
	_variation(t, "PaperPanel", "PanelContainer", sb(Color("#f6e9c8"), Color("#c08a4a"), 3, 12, Color(0, 0, 0, 0.4), 6, Vector4(16, 12, 16, 12)))
	_variation(t, "IdPanel", "PanelContainer", sb(Color("#dbe6f6"), Color("#2f4377"), 3, 12, Color(0, 0, 0, 0.4), 6, Vector4(16, 12, 16, 12)))
	_variation(t, "SuitcasePanel", "PanelContainer", sb(Color("#5a3426"), Color("#d9a441"), 4, 18, Color(0, 0, 0, 0.45), 8, Vector4(16, 14, 16, 14)))
	_variation(t, "HighlightPanel", "PanelContainer", sb(Color(PURPLE_D, 0.55), PINK, 3, 16, Color(PINK, 0.3), 8, Vector4(12, 10, 12, 10)))
	_variation(t, "DarkOverlay", "Panel", sb(Color(0.02, 0.01, 0.08, 0.72), Color.TRANSPARENT, 0, 0))

	# Кнопки
	_button(t, "Button", Color("#2a2470"), Color("#6a5ae6"), TEXT)
	_button(t, "PrimaryButton", Color("#f2a83e"), Color("#ffe08a"), Color("#3a1a06"))
	_button(t, "DangerButton", Color("#d8304e"), Color("#ff8aa0"), TEXT)
	_button(t, "CyanButton", Color("#1f7aa8"), Color("#8ae8ff"), TEXT)
	_button(t, "PurpleButton", Color("#6a34d6"), Color("#c8a8ff"), TEXT)
	_button(t, "GhostButton", Color(INSET, 0.7), Color(BORDER, 0.7), TEXT)
	_button(t, "TabButton", Color("#1a1748"), Color("#3b3f96"), TEXT_DIM, Color("#5a34c8"), PINK)
	_button(t, "ChipButton", Color("#221e58"), Color("#4a4ab0"), TEXT, Color("#3a7ad6"), CYAN, 12)
	_button(t, "ListButton", Color(CARD, 0.95), Color(BORDER_DIM, 0.9), TEXT, Color("#3a2a8a"), PINK, 12)
	t.set_constant("h_separation", "Button", 10)
	t.set_constant("icon_max_width", "Button", 40)

	# Подписи
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", OUTLINE)
	_label(t, "TitleLabel", 44, GOLD, 10, font_bold)
	_label(t, "HeaderLabel", 30, TEXT, 6, font_bold)
	_label(t, "SubHeaderLabel", 24, Color("#c8b8ff"), 4, font_bold)
	_label(t, "DimLabel", 19, TEXT_DIM, 0, null)
	_label(t, "SmallLabel", 17, TEXT_DIM, 0, null)
	_label(t, "NumberLabel", 24, TEXT, 5, font_bold)
	_label(t, "GoldLabel", 22, GOLD, 4, font_bold)
	_label(t, "DarkLabel", 20, Color("#2a1a10"), 0, null)
	_label(t, "DarkHeaderLabel", 24, Color("#3a1a06"), 0, font_bold)

	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font_size("normal_font_size", "RichTextLabel", 21)
	t.set_font("bold_font", "RichTextLabel", font_bold)
	t.set_constant("line_separation", "RichTextLabel", 4)

	# Прогресс-бар
	t.set_stylebox("background", "ProgressBar", sb(INSET, Color(BORDER_DIM, 0.9), 2, 10, Color.TRANSPARENT, 0, Vector4(0, 0, 0, 0)))
	t.set_stylebox("fill", "ProgressBar", sb(Color("#f29a3e"), Color("#ffd27a"), 1, 10, Color.TRANSPARENT, 0, Vector4(0, 0, 0, 0)))
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_font_size("font_size", "ProgressBar", 16)
	_variation_box(t, "CyanBar", "ProgressBar", "fill", sb(Color("#3ab8f0"), Color("#a8f0ff"), 1, 10, Color.TRANSPARENT, 0, Vector4.ZERO))
	_variation_box(t, "PurpleBar", "ProgressBar", "fill", sb(PURPLE, Color("#d8b8ff"), 1, 10, Color.TRANSPARENT, 0, Vector4.ZERO))

	# Слайдер
	t.set_stylebox("slider", "HSlider", sb(INSET, BORDER_DIM, 2, 8, Color.TRANSPARENT, 0, Vector4(0, 6, 0, 6)))
	t.set_stylebox("grabber_area", "HSlider", sb(Color("#3ab8f0"), Color.TRANSPARENT, 0, 8, Color.TRANSPARENT, 0, Vector4(0, 6, 0, 6)))
	t.set_stylebox("grabber_area_highlight", "HSlider", sb(CYAN, Color.TRANSPARENT, 0, 8, Color.TRANSPARENT, 0, Vector4(0, 6, 0, 6)))
	var grab := _circle_icon(26, GOLD, Color("#fff1a8"))
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", grab)

	# Прокрутка
	t.set_stylebox("scroll", "VScrollBar", sb(Color(INSET, 0.6), Color.TRANSPARENT, 0, 6, Color.TRANSPARENT, 0, Vector4(4, 4, 4, 4)))
	t.set_stylebox("grabber", "VScrollBar", sb(Color(PURPLE, 0.8), Color.TRANSPARENT, 0, 6))
	t.set_stylebox("grabber_highlight", "VScrollBar", sb(PURPLE, Color.TRANSPARENT, 0, 6))
	t.set_stylebox("grabber_pressed", "VScrollBar", sb(PINK, Color.TRANSPARENT, 0, 6))
	t.set_stylebox("scroll", "HScrollBar", sb(Color(INSET, 0.6), Color.TRANSPARENT, 0, 6, Color.TRANSPARENT, 0, Vector4(4, 4, 4, 4)))
	t.set_stylebox("grabber", "HScrollBar", sb(Color(PURPLE, 0.8), Color.TRANSPARENT, 0, 6))

	t.set_stylebox("panel", "TooltipPanel", sb(PANEL_2, BORDER, 2, 10))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 18)
	t.set_font_size("font_size", "CheckButton", 22)
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_font_size("font_size", "CheckBox", 20)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_color("font_pressed_color", "CheckBox", GOLD)
	return t


func _variation(t: Theme, name: String, base: String, box: StyleBox) -> void:
	t.set_type_variation(name, base)
	t.set_stylebox("panel", name, box)


func _variation_box(t: Theme, name: String, base: String, item: String, box: StyleBox) -> void:
	t.set_type_variation(name, base)
	t.set_stylebox(item, name, box)


func _label(t: Theme, name: String, size: int, color: Color, outline: int, f: Font) -> void:
	t.set_type_variation(name, "Label")
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)
	t.set_color("font_outline_color", name, OUTLINE)
	t.set_constant("outline_size", name, outline)
	if f:
		t.set_font("font", name, f)


func _button(t: Theme, name: String, bg: Color, border: Color, fg: Color,
		pressed_bg: Color = Color.TRANSPARENT, pressed_border: Color = Color.TRANSPARENT, radius: int = 16) -> void:
	if name != "Button":
		t.set_type_variation(name, "Button")
	var margin := Vector4(18, 10, 18, 10)
	var normal := sb(bg, border, 3, radius, Color(0, 0, 0, 0.35), 4, margin)
	var hover := sb(bg.lightened(0.12), border.lightened(0.2), 3, radius, Color(border, 0.35), 8, margin)
	var pressed := sb(pressed_bg if pressed_bg.a > 0 else bg.darkened(0.18),
		pressed_border if pressed_border.a > 0 else border, 3, radius, Color(0, 0, 0, 0.2), 2, margin)
	var disabled := sb(bg.darkened(0.45), border.darkened(0.5), 3, radius, Color.TRANSPARENT, 0, margin)
	t.set_stylebox("normal", name, normal)
	t.set_stylebox("hover", name, hover)
	t.set_stylebox("pressed", name, pressed)
	t.set_stylebox("hover_pressed", name, pressed)
	t.set_stylebox("disabled", name, disabled)
	t.set_stylebox("focus", name, StyleBoxEmpty.new())
	t.set_color("font_color", name, fg)
	t.set_color("font_hover_color", name, fg.lightened(0.1) if fg.v < 0.5 else Color.WHITE)
	t.set_color("font_pressed_color", name, fg if pressed_bg.a == 0 else Color.WHITE)
	t.set_color("font_hover_pressed_color", name, fg if pressed_bg.a == 0 else Color.WHITE)
	t.set_color("font_focus_color", name, fg)
	t.set_color("font_disabled_color", name, Color(fg, 0.45))
	t.set_color("font_outline_color", name, OUTLINE)
	t.set_constant("outline_size", name, 0 if fg.v < 0.5 else 4)
	t.set_font("font", name, font_bold)
	t.set_font_size("font_size", name, 22)


func _circle_icon(size: int, fill: Color, rim: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r: float = size / 2.0
	for y in size:
		for x in size:
			var d: float = Vector2(x + 0.5 - r, y + 0.5 - r).length()
			if d <= r - 0.5:
				img.set_pixel(x, y, rim if d > r - 3.5 else fill)
	return ImageTexture.create_from_image(img)
