extends GameScreen
## Допрос: портрет собеседника, реплики с эффектом печати и список тем. Новые темы
## открываются найденными уликами. Сказанное записывается в журнал как показание.

var _id: String
var _text: Label
var _name: Label
var _topics: VBoxContainer
var _lines: Array = []
var _line_i: int = 0
var _pending_gives: Array = []
var _hero: TextureRect
var _continue: Button
var _tween: Tween


func build(args: Dictionary) -> void:
	dim_background = false
	_id = str(args.get("id", ""))
	var inv: InvestigationManager = game.investigation
	if inv.suspects.set_flag(_id, "met"):
		Events.add_stat("talks")
	ProgressionManager.meet(_id)
	var npc: NPCController = game.npcs.get(_id)
	if npc:
		npc.talking_to = game.player
		game.player.facing = CaseTimeline.facing_for(npc.global_position - game.player.global_position)
		game.player.sprite.play_state("idle", game.player.facing)

	var shade := ColorRect.new()
	Ui.full_rect(shade)
	shade.color = Color(0.02, 0.01, 0.08, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var m := Ui.margin(28, 0, 28, 20)
	m.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	m.offset_top = -330
	var p := Ui.panel()
	var row := Ui.hbox(22)
	var left := Ui.vbox(6)
	var look: String = game.appearance(_id)
	left.add_child(Ui.portrait(Db.portrait(look), 170, Color(str(Db.character(look).get("color", "#4fd0ff"))).lightened(0.3)))
	row.add_child(left)
	var mid := Ui.vbox(10)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name = Ui.label(Db.char_name(look), "SubHeaderLabel", 28)
	mid.add_child(_name)
	_text = Ui.label("", "", 24, true)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.custom_minimum_size = Vector2(420, 150)
	mid.add_child(_text)
	var cont_row := Ui.hbox(10)
	cont_row.add_child(Ui.spacer())
	_continue = Ui.button("Далее", "arrow_right", "PrimaryButton", _advance, 54)
	cont_row.add_child(_continue)
	mid.add_child(cont_row)
	row.add_child(mid)
	var right := Ui.vbox(8)
	right.custom_minimum_size = Vector2(420, 0)
	var th := Ui.hbox(8)
	th.add_child(Ui.label("Спросить:", "DimLabel"))
	th.add_child(Ui.spacer())
	_hero = Ui.tex(Db.portrait("detective"), 56)
	th.add_child(_hero)
	right.add_child(th)
	_topics = Ui.vbox(8)
	right.add_child(Ui.scroll(_topics))
	var bye := Ui.button("Закончить разговор", "close", "GhostButton", close, 52)
	right.add_child(bye)
	row.add_child(right)
	p.add_child(row)
	m.add_child(p)
	add_child(m)
	_say([inv.dialogue.greet(_id)], [])
	_rebuild_topics()


func _rebuild_topics() -> void:
	Ui.clear(_topics)
	var inv: InvestigationManager = game.investigation
	for t: Dictionary in inv.dialogue.topics(_id, inv.evidence):
		var b := Ui.button(str(t["q"]), "check" if t["asked"] else "question", "ListButton" if t["asked"] else "ChipButton", func() -> void: _ask(t["id"]), 52)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 19)
		if t["asked"]:
			b.modulate = Color(1, 1, 1, 0.7)
		_topics.add_child(b)


func _ask(topic_id: String) -> void:
	var inv: InvestigationManager = game.investigation
	var t: Dictionary = inv.dialogue.ask(_id, topic_id, inv.evidence)
	if t.is_empty():
		return
	game.player.play_action("suspicion", 0.5)
	_say(t["a"], t.get("gives", []))


func _say(lines: Array, gives: Array) -> void:
	_lines = lines
	_line_i = 0
	_pending_gives = gives
	_topics.modulate.a = 0.5
	_show_line()


func _show_line() -> void:
	_text.text = str(_lines[_line_i])
	_text.visible_ratio = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_text, "visible_ratio", 1.0, 0.018 * _text.text.length())
	AudioManager.play_sfx("talk", -12.0, randf_range(0.9, 1.15))
	_continue.visible = true


func _advance() -> void:
	if _text.visible_ratio < 1.0:
		if _tween:
			_tween.kill()
		_text.visible_ratio = 1.0
		return
	if _line_i < _lines.size() - 1:
		_line_i += 1
		_show_line()
		return
	_continue.visible = false
	_topics.modulate.a = 1.0
	var added: Array[String] = game.investigation.give_all(_pending_gives)
	_pending_gives = []
	if not added.is_empty():
		_hero.texture = Db.portrait("detective", "smile")
		game.player.play_action("note", 0.9)
		AudioManager.play_sfx("note", -6.0)
	_rebuild_topics()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and _continue.visible:
		_advance()


func close() -> void:
	if not _pending_gives.is_empty():
		game.investigation.give_all(_pending_gives)
	var npc: NPCController = game.npcs.get(_id)
	if npc:
		npc.talking_to = null
	super.close()
