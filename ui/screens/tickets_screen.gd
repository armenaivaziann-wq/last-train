extends GameScreen
## «Билеты закончились»: таймер до следующего билета и варианты — подождать, билет за рекламу,
## восполнить все за кристаллы, «Полная версия» (бесконечные билеты).

var _timer: Label
var _count: Label
var _on_ready: Callable


func build(args: Dictionary) -> void:
	_on_ready = args.get("on_ready", Callable())
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(640, 0)
	var v := Ui.vbox(12)
	v.add_child(Ui.header("Билеты закончились", "ticket", close))
	var row := Ui.hbox(12)
	row.add_child(Ui.icon("ticket", 64))
	var info := Ui.vbox(4)
	_count = Ui.label("", "HeaderLabel", 28)
	info.add_child(_count)
	_timer = Ui.label("", "NumberLabel", 26)
	info.add_child(_timer)
	row.add_child(info)
	v.add_child(row)
	v.add_child(Ui.label("Билет тратится, когда монстр уходит от вас. Новый билет — каждые 30 минут, даже когда игра закрыта.", "SmallLabel", 17, true))
	v.add_child(Ui.button("Получить билет за рекламу", "video", "CyanButton", _ad, 58))
	var refill := Ui.button("Восполнить все за %d кристаллов" % Tickets.REFILL_CRYSTALS, "crystal", "PurpleButton", _refill, 58)
	refill.disabled = EconomyManager.crystals() < Tickets.REFILL_CRYSTALS
	v.add_child(refill)
	v.add_child(Ui.button("Полная версия — бесконечные билеты", "star", "PrimaryButton", _full, 58))
	v.add_child(Ui.button("Подождать", "hourglass", "GhostButton", close, 54))
	p.add_child(v)
	add_child(Ui.center(p))
	_tick()


func _process(_delta: float) -> void:
	_tick()


func _tick() -> void:
	var n: int = Tickets.count()
	_count.text = "Билеты: %d / %d" % [n, Tickets.MAX]
	_timer.text = "Следующий через %s" % Tickets.format_wait(Tickets.seconds_to_next()) if n < Tickets.MAX else "Все билеты на месте"


func _ad() -> void:
	AdsService.show_rewarded(func(ok: bool) -> void:
		if ok:
			Tickets.add(1)
			Events.notify("Получен билет.", "ticket")
			_done())


func _refill() -> void:
	if Tickets.refill_for_crystals():
		Events.notify("Все билеты восполнены.", "ticket")
		_done()


func _full() -> void:
	# Покупка будет подключена к магазину приложений; пока флаг включается сразу.
	Tickets.unlock_full_version()
	Events.notify("Полная версия: билеты бесконечны.", "star")
	_done()


func _done() -> void:
	Events.profile_changed.emit()
	var cb: Callable = _on_ready
	close()
	if cb.is_valid() and Tickets.count() > 0:
		cb.call()
