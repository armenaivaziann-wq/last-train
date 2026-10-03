class_name ConfirmDialog
extends Control
## Модальное подтверждение в стиле игры (вместо системного окна).

signal confirmed
signal cancelled


static func create(title: String, text: String, ok_text: String = "Да", cancel_text: String = "Отмена", ok_variation: String = "DangerButton") -> ConfirmDialog:
	var d := ConfirmDialog.new()
	d._build(title, text, ok_text, cancel_text, ok_variation)
	return d


func _build(title: String, text: String, ok_text: String, cancel_text: String, ok_variation: String) -> void:
	Ui.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := Panel.new()
	dim.theme_type_variation = "DarkOverlay"
	Ui.full_rect(dim)
	add_child(dim)
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(620, 0)
	var v := Ui.vbox(18)
	v.add_child(Ui.label(title, "HeaderLabel", 30, true))
	v.add_child(Ui.label(text, "", 21, true))
	var h := Ui.hbox(14)
	var cancel := Ui.button(cancel_text, "back", "GhostButton", func() -> void:
		cancelled.emit()
		queue_free(), 60)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ok := Ui.button(ok_text, "check", ok_variation, func() -> void:
		confirmed.emit()
		queue_free(), 60)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(cancel)
	h.add_child(ok)
	v.add_child(h)
	p.add_child(v)
	add_child(Ui.center(p))
