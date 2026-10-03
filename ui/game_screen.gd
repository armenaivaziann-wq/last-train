class_name GameScreen
extends Control
## Базовый класс полноэкранных интерфейсов (журнал, камеры, документы...).
## Пока экран открыт, часы дела стоят, управление героем отключено; состояние игры сохраняется.

signal closed

## Игровая сессия (Game) или null, если экран открыт из главного меню.
var game: Node = null
var ui: UIManager = null
## Тёмная подложка под экраном (false — экран сам рисует фон).
var dim_background: bool = true
## Закрывается ли экран клавишей Esc / кнопкой «назад».
var closable: bool = true


func _init() -> void:
	Ui.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Вызывается UIManager после добавления в дерево.
func open(args: Dictionary) -> void:
	if dim_background:
		var dim := Panel.new()
		dim.theme_type_variation = "DarkOverlay"
		Ui.full_rect(dim)
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(dim)
		move_child(dim, 0)
	build(args)
	modulate.a = 0.0
	scale = Vector2(0.98, 0.98)
	pivot_offset = get_viewport_rect().size / 2.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.16)
	tw.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Построить содержимое экрана (переопределяется).
func build(_args: Dictionary) -> void:
	pass


## Обновить содержимое, если данные изменились (переопределяется).
func refresh() -> void:
	pass


func on_back() -> void:
	if closable:
		close()


func close() -> void:
	if ui:
		ui.close(self)
	else:
		queue_free()


## Безопасная область по краям экрана (кнопки не прилипают к краям телефона).
func safe_margin(content: Control, side: int = 36, top: int = 24) -> MarginContainer:
	var m := Ui.margin(side, top, side, top)
	Ui.full_rect(m)
	m.add_child(content)
	add_child(m)
	return m
