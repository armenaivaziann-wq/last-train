class_name Game
extends Node2D
## Композиционный корень сессии расследования: строит поезд, героя и пассажиров,
## связывает расследование, камеры и интерфейс. Системы не ищут друг друга сами —
## ссылки раздаются отсюда.

const AUTOSAVE_INTERVAL: float = 12.0
const BARK_DISTANCE: float = 90.0
const MAGNIFIER_RADIUS: float = 96.0

@onready var train: TrainManager = $World/Train
@onready var glow_layer: Node2D = $World/Glow
@onready var entities: Node2D = $World/Entities
@onready var overhead: Node2D = $World/Overhead
@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var camera: GameCamera = $Camera
@onready var investigation: InvestigationManager = $Investigation
@onready var camera_system: CameraSystem = $CameraSystem
@onready var hud: Hud = $UILayer/Hud
@onready var ui: UIManager = $UILayer/UIManager

var case_id: String
var case_data: Dictionary
var layout: TrainLayout
var player: PlayerController
var npcs: Dictionary = {}  # id → NPCController
var arrest: ArrestSequence
var highlight: TargetHighlight
## Места преступлений: индекс убийства → CrimeScene.
var crime_scenes: Dictionary = {}
## Предметы мира из данных дела и сюжетных событий: id → узел.
var world_items: Dictionary = {}
var villain_world: VillainWorld
const DISCOVER_DISTANCE: float = 72.0
var _autosave_timer: float = AUTOSAVE_INTERVAL
var _bark_timer: float = 2.0
var _marker_timer: float = 0.0
var _bark_rng := RandomNumberGenerator.new()


func _ready() -> void:
	case_id = SaveManager.pending_case if SaveManager.pending_case != "" else "case_01"
	var resume: bool = SaveManager.pending_resume and SaveManager.has_case_progress()
	var level_id: String = SaveManager.pending_level
	var seed_value: int = SaveManager.pending_seed
	if resume:
		var cp: Dictionary = SaveManager.profile["case_progress"]
		case_id = str(cp.get("case_id", case_id))
		level_id = str(cp.get("level", level_id))
		seed_value = int(cp.get("seed", cp.get("murders", {}).get("seed", -1)))
	if seed_value < 0:
		seed_value = randi() % 1000000
	# Данные дела собираются один раз на попытку: вариант улик/событий зависит от seed.
	case_data = Db.resolve_case(case_id, seed_value)
	layout = TrainLayout.build(PackedStringArray(case_data["carriages"]))
	train.modulate_node = canvas_modulate
	train.build(layout, str(case_data.get("ground", "forest")), entities, glow_layer)
	_spawn_luggage()
	_spawn_extra_items()
	investigation.setup(case_id, layout, seed_value, case_data, level_id)
	# Дальше — копия данных дела с подставленными сценариями убийств.
	case_data = investigation.data
	_spawn_npcs()
	_spawn_player()
	camera_system.setup(layout, investigation, npcs, player)
	camera_system.crime_scenes = crime_scenes
	villain_world = VillainWorld.new()
	entities.add_child(villain_world)
	villain_world.setup(self)
	var markers := InspectMarkers.new()
	glow_layer.add_child(markers)
	markers.setup(self)
	camera_system.villain_world = villain_world
	camera.target = player
	camera.left_limit = -40.0
	camera.right_limit = layout.width + 40.0
	ui.game = self
	hud.setup(self)
	hud.set_case_title("Дело: «%s»" % case_data["title"])
	arrest = ArrestSequence.new(self)
	highlight = TargetHighlight.new()
	glow_layer.add_child(highlight)
	_connect_signals()
	_apply_npcs(investigation.clock)
	if resume:
		_restore(SaveManager.profile["case_progress"])
		Events.notify("Расследование продолжено", "journal")
	else:
		investigation.hold("brief")
		ui.open("brief_screen", {"brief": case_data["brief"]})
	camera.snap_to_target()
	AudioManager.play_music("music_explore")
	AudioManager.set_train_ambience(true)
	_on_clock(investigation.clock)
	hud.set_key_clues(investigation.evidence.key_found_count())
	if not resume:
		for npc: String in investigation.npc_state:
			if npcs.has(npc):
				npcs[npc].set_condition(str(investigation.npc_state[npc]))


func _connect_signals() -> void:
	investigation.clock_changed.connect(_on_clock)
	investigation.clue_added.connect(_on_clue)
	investigation.case_event.connect(_on_case_event)
	investigation.escalated.connect(_on_escalated)
	investigation.finished.connect(_on_finished)
	investigation.murder_stage.connect(_on_murder_stage)
	investigation.story_event.connect(_on_story_event)
	investigation.npc_state_changed.connect(func(npc: String, st: String) -> void:
		if npcs.has(npc):
			npcs[npc].set_condition(st))
	player.target_changed.connect(_on_target_changed)
	hud.joystick.vector_changed.connect(func(v: Vector2) -> void: player.touch_vector = v)
	ui.stack_changed.connect(_on_ui_stack)


func _spawn_npcs() -> void:
	var glitch: Dictionary = case_data.get("glitch", {})
	for id: String in case_data["schedules"]:
		var npc := NPCController.new()
		npc.setup(id)
		if glitch.get("npc", "") == id:
			npc.glitch_every = glitch["every"]
		entities.add_child(npc)
		npcs[id] = npc


func _spawn_player() -> void:
	player = PlayerController.new()
	player.name = "Detective"
	var ps: Dictionary = case_data["player_start"]
	player.position = Vector2(layout.offsets[ps["carriage"]] + float(ps["pos"][0]), float(ps["pos"][1]))
	player.facing = "right"
	entities.add_child(player)


func _spawn_luggage() -> void:
	for lw: Dictionary in case_data.get("luggage_world", []):
		var pos: Vector2 = layout.slots.get(lw["slot"], Vector2.ZERO)
		var tex: Texture2D = Db.texture("props/%s.png" % lw["sprite"])
		var s := Sprite2D.new()
		s.texture = tex
		s.offset = Vector2(0, -tex.get_height() / 2.0)
		s.position = pos + Vector2(0, tex.get_height() / 2.0)
		entities.add_child(s)
		var it := Interactable.new()
		it.interact_id = "luggage_" + str(lw["owner"])
		it.owner_id = lw["owner"]
		it.kind = Interactable.Kind.LUGGAGE
		it.label = "Багаж: " + Db.char_name(lw["owner"])
		it.radius = 24.0
		it.position = Vector2(0, -tex.get_height() / 2.0)
		s.add_child(it)


## Предметы-улики из данных дела (следы на полу, жетоны, чашки) — постоянные объекты мира.
func _spawn_extra_items() -> void:
	for it: Dictionary in case_data.get("extra_items", []):
		spawn_item(it)


## Предмет в мире (улика на полу, подброшенная записка, «дышащий» чемодан...).
## Спрайт "crime/<имя>" по умолчанию или путь вида "props/<имя>".
func spawn_item(it: Dictionary) -> void:
	var id: String = str(it["id"])
	if world_items.has(id):
		return
	var root := StoryItem.new()
	root.setup(it, Vector2(layout.offsets[it["carriage"]] + float(it["pos"][0]), float(it["pos"][1])))
	(entities if it.get("tall", false) else glow_layer).add_child(root)
	world_items[id] = root


func remove_item(id: String) -> void:
	if world_items.has(id):
		world_items[id].queue_free()
		world_items.erase(id)


func _apply_npcs(t: float) -> void:
	for id: String in npcs:
		if npcs[id].dead:
			continue
		npcs[id].apply(investigation.timeline.state_at(id, t))


func _process(delta: float) -> void:
	if not camera_system.playback:
		_apply_npcs(investigation.clock)
		villain_world.apply(investigation.clock)
		player.clock_minute = investigation.clock
	_update_barks(delta)
	_marker_timer -= delta
	if _marker_timer <= 0.0:
		_marker_timer = 0.5
		_update_markers()
		update_goal()
	_check_discovery()
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_timer = AUTOSAVE_INTERVAL
		autosave()


## Телефон: приложение свернули, пришёл звонок, закрыли окно — сохраняем дело и ставим паузу,
## чтобы время до станции не уходило в фоне.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		if investigation == null or investigation.ended or not is_inside_tree():
			return
		autosave()
		var background: bool = what == NOTIFICATION_APPLICATION_PAUSED or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile"))
		if background and ui and not ui.has_modal() and not arrest.running:
			ui.open("pause_menu")


func _unhandled_input(event: InputEvent) -> void:
	if ui.has_modal() or arrest.running or investigation.ended:
		return
	if event.is_action_pressed(&"interact"):
		interact()
	elif event.is_action_pressed(&"magnifier"):
		use_magnifier()
	elif event.is_action_pressed(&"journal"):
		open_journal()
	elif event.is_action_pressed(&"cameras"):
		open_cameras()
	elif event.is_action_pressed(&"map"):
		open_train_map()


# --- взаимодействие ----------------------------------------------------------------------
func in_dark() -> bool:
	return train.in_tunnel() and ProgressionManager.equipment_level("flashlight") == 0


func interact() -> void:
	if ui.has_modal() or arrest.running or investigation.ended or player.is_busy():
		return
	var t: Interactable = player.target
	if t == null:
		return
	if t.needs_light and in_dark():
		Events.notify("Слишком темно — в туннеле нужен фонарик.", "flashlight")
		return
	match t.kind:
		Interactable.Kind.NPC:
			player.facing = CaseTimeline.facing_for(t.global_position - player.global_position)
			ui.open("passenger_screen", {"id": t.owner_id})
		Interactable.Kind.OBJECT:
			player.play_action("inspect", 0.45)
			await get_tree().create_timer(0.3).timeout
			t.inspected = true
			investigation.mark_opened(t.interact_id)
			open_object(t.interact_id)
		Interactable.Kind.LUGGAGE:
			player.play_action("interact", 0.4)
			await get_tree().create_timer(0.25).timeout
			investigation.mark_opened(t.interact_id)
			open_luggage(t.owner_id)
		Interactable.Kind.MONITOR:
			open_cameras()
		Interactable.Kind.DOOR:
			AudioManager.play_sfx("door_locked")
			Events.notify(str(t.get_meta("message", "Заперто.")), "lock")


func use_magnifier() -> void:
	if ui.has_modal() or arrest.running or player.is_busy():
		return
	player.play_action("inspect", 0.7)
	AudioManager.play_sfx("magnifier")
	if train.in_tunnel() and ProgressionManager.equipment_level("flashlight") < 2:
		Events.notify("В темноте лупа бесполезна. Нужен мощный фонарик.", "flashlight")
		return
	var radius: float = MAGNIFIER_RADIUS * (1.6 if ProgressionManager.equipment_level("magnifier") >= 2 else 1.0)
	var found: int = 0
	for node in get_tree().get_nodes_in_group(&"interactables"):
		var it := node as Interactable
		if it == null or it.kind == Interactable.Kind.NPC or it.kind == Interactable.Kind.DOOR:
			continue
		if it.global_position.distance_to(player.global_position) <= radius:
			found += 1
			_sparkle(it.global_position)
	player.set_lens_glow(true)
	get_tree().create_timer(1.6).timeout.connect(func() -> void: player.set_lens_glow(false))
	if found == 0:
		Events.notify("Рядом нечего рассматривать.", "magnifier")
	else:
		Events.notify("Лупа: рядом можно осмотреть %d %s." % [found, _plural(found, "предмет", "предмета", "предметов")], "magnifier")


func _sparkle(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = Db.texture("ui/sparkle.png")
	s.position = pos + Vector2(0, -10)
	overhead.add_child(s)
	var tw := s.create_tween()
	tw.set_loops(4)
	tw.tween_property(s, "scale", Vector2(1.6, 1.6), 0.25)
	tw.tween_property(s, "scale", Vector2(0.8, 0.8), 0.25)
	get_tree().create_timer(2.1).timeout.connect(s.queue_free)


static func _plural(n: int, one: String, few: String, many: String) -> String:
	var n10: int = n % 10
	var n100: int = n % 100
	if n10 == 1 and n100 != 11:
		return one
	if n10 >= 2 and n10 <= 4 and (n100 < 10 or n100 >= 20):
		return few
	return many


func open_object(object_id: String) -> void:
	var obj: Dictionary = case_data["objects"].get(object_id, {})
	if obj.is_empty():
		Events.notify("Ничего примечательного.", "magnifier")
		return
	# Запертый объект: открывается, только когда найдено нужное (ключ, инструмент...).
	var ev: EvidenceSystem = investigation.evidence
	var locked: bool = false
	for r: String in obj.get("requires", []):
		if not ev.has(r):
			locked = true
	var any: Array = obj.get("requires_any", [])
	if not any.is_empty() and not any.any(func(r: String) -> bool: return ev.has(r)):
		locked = true
	if locked:
		AudioManager.play_sfx("door_locked", -6.0)
		Events.notify(str(obj.get("locked_text", "Заперто.")), "lock")
		if obj.has("locked_clue"):
			investigation.give(str(obj["locked_clue"]))
		return
	ui.open("document_screen", {"object": object_id})


func open_luggage(owner: String) -> void:
	ui.open("luggage_screen", {"id": owner})


func open_documents(owner: String) -> void:
	ui.open("document_screen", {"id": owner})


func open_dialogue(who: String) -> void:
	ui.open("dialogue_screen", {"id": who})


func open_journal(tab: String = "") -> void:
	if ui.has_modal() and ui.top().name == "journal_screen":
		return
	hud.clear_new_clues()
	ui.open("journal_screen", {"tab": tab})


func open_cameras() -> void:
	if ui.find("camera_screen"):
		return
	ui.open("camera_screen", {})


func open_train_map() -> void:
	ui.open("train_map_screen", {})


# --- события ------------------------------------------------------------------------------
func _on_target_changed(t: Interactable) -> void:
	var text: String = ""
	if t:
		text = t.label
		if t.kind == Interactable.Kind.NPC:
			text = Db.char_name(appearance(t.owner_id))
	hud.set_target(t, text)
	highlight.set_target(t)


func _on_ui_stack(has_modal: bool) -> void:
	player.input_enabled = not has_modal and not arrest.running
	if has_modal:
		investigation.hold("ui")
		player.touch_vector = Vector2.ZERO
		# Палец мог остаться на джойстике: отпускание уйдёт в окно, поэтому сбрасываем сразу.
		hud.joystick.release()
	else:
		investigation.release("ui")
		investigation.release("brief")
	for id: String in npcs:
		if not has_modal:
			npcs[id].talking_to = null
	hud.overlay.visible = not has_modal and not arrest.running


## Одна текущая цель в HUD. Формулировки не подсказывают виновника.
func update_goal() -> void:
	var ev: EvidenceSystem = investigation.evidence
	var facts: int = 0
	var deductions: int = 0
	for id in ev.found:
		if ev.clue(id).get("type") == "contradiction":
			deductions += 1
		else:
			facts += 1
	var met: bool = false
	for id: String in npcs:
		if investigation.suspects.flag(id, "met"):
			met = true
	var goal: String = murder_goal()
	if goal == "":
		goal = story_goal()
	var speaker: String = str(case_data.get("brief", {}).get("speaker", "agata"))
	if goal == "" and not met:
		goal = "Цель: поговорите с проводницей" if speaker == "agata" else "Цель: выслушайте рассказ — %s" % Db.char_name(speaker)
	elif goal == "" and facts < 8:
		goal = "Цель: найдите улики (%d/8)" % facts
	elif goal == "" and deductions == 0:
		goal = "Цель: сопоставьте улики в журнале"
	elif goal == "":
		goal = "Цель: выберите подозреваемого в журнале"
	hud.set_goal(goal)


## Следующий шаг по последнему убийству — из фактов события и уже найденных улик.
## Пусто, если по убийствам всё сделано (тогда цель — общее расследование).
## Цели авторского дела по ходу расследования: "goals": [{text, until: [улики], requires: [улики]}].
## Берётся первая цель, для которой всё нужное найдено, а результата ещё нет.
func story_goal() -> String:
	var ev: EvidenceSystem = investigation.evidence
	for g: Dictionary in case_data.get("goals", []):
		if g.get("requires", []).any(func(id: String) -> bool: return not ev.has(id)):
			continue
		if g.get("until", []).any(func(id: String) -> bool: return ev.has(id)):
			continue
		return "Цель: " + str(g["text"])
	return ""


func murder_goal() -> String:
	var ev: EvidenceSystem = investigation.evidence
	var killed: Array = investigation.murders.killed()
	killed.reverse()
	for m: Dictionary in killed:
		var pre: String = m["prefix"]
		var name: String = Db.char_name(m["victim"])
		var verb: String = "убита" if str(Db.character(m["victim"]).get("gender", "m")) == "f" else "убит"
		if not int(m["index"]) in investigation.murders.discovered:
			if layout.carriage_at(player.global_position.x) != m["carriage"]:
				return "Цель: идите в %s — там %s %s" % [_to_carriage(m["carriage"]), verb, name]
			return "Цель: найдите тело: %s (%s)" % [name, str(m["where"]).to_lower()]
		if not ev.has(pre + "_body"):
			return "Цель: осмотрите тело — %s" % name
		if not ev.has(pre + "_steps"):
			return "Цель: осмотрите следы у тела — %s" % name
		for w: String in m.get("witnesses", []):
			if not ev.has("%s_w_%s" % [pre, w]) and not investigation.murders.dead_at(w, investigation.clock):
				return "Цель: поговорите со свидетелем — %s" % Db.char_name(w)
		if case_data["clues"].has("c_" + pre) and not ev.has("c_" + pre):
			return "Цель: изучите запись камеры К%s около %s" % [str(m["camera"]).substr(3), Db.format_time(m["t"]["kill"])]
	return ""


func _to_carriage(cid: String) -> String:
	return {"passenger": "пассажирский вагон", "vestibule": "тамбур", "restaurant": "вагон-ресторан",
		"sleeper": "спальный вагон", "baggage": "багажный вагон"}.get(cid, layout.carriage_name(cid))


func _on_clock(minute: float) -> void:
	hud.update_clock(minute, investigation.start_time, investigation.arrival_time, str(case_data["station_to"]))
	var warn: int = investigation.check_deadline_warnings()
	if warn > 0 and not investigation.ended:
		hud.deadline_warning(warn)
	var tension: bool = investigation.minutes_left() <= 4.0 or investigation.escalated_at >= 0.0
	if not arrest.running and not investigation.ended:
		AudioManager.play_music("music_tension" if tension else "music_explore")


func _on_clue(clue_id: String) -> void:
	hud.set_key_clues(investigation.evidence.key_found_count())
	var c: Dictionary = investigation.evidence.clue(clue_id)
	var is_deduction: bool = c.get("type") == "contradiction"
	hud.add_new_clue()
	AudioManager.play_sfx("contradiction" if is_deduction else "clue")
	AudioManager.vibrate(30)
	Events.notify(("Новый вывод: " if is_deduction else "Новая улика: ") + str(c.get("title", "")), Ui.clue_icon(str(c.get("type", ""))))
	if not ui.has_modal() and not player.is_busy():
		player.play_action("discovery", 0.6)
	autosave()


## Как пассажир выглядит сейчас (перевёртыш — чужим лицом): для карточки и подписей.
func appearance(npc_id: String) -> String:
	return investigation.hooks.appearance(npc_id, investigation.clock)


func _on_case_event(ev: Dictionary) -> void:
	match str(ev["type"]):
		"false_call":
			# Ложный вызов: крик о помощи чужим голосом из пустого купе.
			var call: Dictionary = investigation.hooks.calls[int(ev["call"])]
			AudioManager.play_sfx("female_scream", -6.0, 0.9)
			hud.show_direction(call["pos"], "Зов!", 6.0)
		"announce":
			AudioManager.play_sfx("announce")
		"tunnel_start":
			train.set_tunnel(true)
			AudioManager.play_sfx("tunnel")
		"tunnel_end":
			train.set_tunnel(false)
		"rain_start":
			train.set_rain(true)
			AudioManager.set_train_ambience(true, true)
		"station_approach":
			train.set_station(true)
			create_tween().tween_property(train, "speed_factor", 0.25, 6.0)
	if ev.has("text"):
		Events.notify(str(ev["text"]), "train")


func _on_escalated(npc_id: String) -> void:
	if npcs.has(npc_id):
		var barks: Array = case_data["escalation"].get("barks", [])
		if not barks.is_empty():
			hud.overlay.show_bark(npcs[npc_id], str(barks[0]))


func _update_barks(delta: float) -> void:
	_bark_timer -= delta
	if _bark_timer > 0.0 or ui.has_modal():
		return
	_bark_timer = _bark_rng.randf_range(3.0, 6.0)
	var near: Array = []
	for id: String in npcs:
		var n: NPCController = npcs[id]
		if n.global_position.distance_to(player.global_position) < BARK_DISTANCE and not n.detained:
			near.append(id)
	if near.is_empty():
		return
	var who: String = near[_bark_rng.randi_range(0, near.size() - 1)]
	var lines: Array = case_data.get("barks", {}).get(who, [])
	var esc: Dictionary = case_data.get("escalation", {})
	if investigation.escalated_at >= 0.0 and esc.get("npc") == who:
		lines = esc.get("barks", lines)
	if not lines.is_empty():
		hud.overlay.show_bark(npcs[who], str(lines[_bark_rng.randi_range(0, lines.size() - 1)]))


func _update_markers() -> void:
	for id: String in npcs:
		var show: bool = investigation.suspects.flag(id, "met") \
			and investigation.dialogue.has_new_topics(id, investigation.evidence, investigation.dialogue_ctx(id)) and not npcs[id].detained
		hud.overlay.set_marker(npcs[id], show)


# --- сюжетные события ----------------------------------------------------------------------
func _on_story_event(e: Dictionary) -> void:
	for fx: Dictionary in e["effects"]:
		match str(fx["type"]):
			"toast":
				Events.notify(str(fx["text"]), str(fx.get("icon", "train")))
			"sound":
				AudioManager.play_sfx(str(fx["name"]), float(fx.get("db", 0.0)))
			"banner":
				hud.show_banner(str(fx["title"]), str(fx.get("text", "")), 3.5)
			"voice":
				var pos := Vector2(layout.offsets[fx["carriage"]] + float(fx["x"]), float(fx["y"]))
				AudioManager.play_sfx(str(fx.get("sound", "female_scream")), -8.0, float(fx.get("pitch", 0.9)))
				Events.notify(str(fx["text"]), "talk")
				hud.show_direction(pos, str(fx.get("label", "Голос!")), 6.0)
			"item":
				spawn_item(fx)
			"remove_item":
				remove_item(str(fx["id"]))
	update_goal()


# --- события-убийства в туннеле -----------------------------------------------------------
func _on_murder_stage(m: Dictionary, stage: String) -> void:
	match stage:
		"tunnel_in":
			train.set_tunnel(true)
			AudioManager.set_tunnel_ambience(true)
			AudioManager.play_sfx("tunnel")
			Events.notify("Поезд въезжает в туннель.", "train")
		"flicker":
			train.flicker(1.6)
			AudioManager.play_sfx("lights_flicker")
		"kill":
			train.blackout(0.7)
			_kill(m, false)
		"tunnel_out":
			train.set_tunnel(false)
			AudioManager.set_tunnel_ambience(false)
		"discovered":
			AudioManager.play_sfx("discovery_stinger")
			hud.show_banner("ПРОИЗОШЛО УБИЙСТВО", "Осмотрите место преступления: тело, улики, свидетели", 4.0)
			AudioManager.vibrate(80)
			update_goal()


## Жертва погибает, на её месте остаётся тело. silent — восстановление из сохранения.
func _kill(m: Dictionary, silent: bool) -> void:
	var victim: NPCController = npcs.get(m["victim"])
	if victim:
		victim.set_dead(true)
	if not crime_scenes.has(int(m["index"])):
		var scene := CrimeScene.new()
		glow_layer.add_child(scene)
		scene.build(m, layout)
		crime_scenes[int(m["index"])] = scene
	if silent:
		return
	AudioManager.play_sfx("female_scream", 2.0)
	get_tree().create_timer(0.7).timeout.connect(func() -> void: AudioManager.play_sfx("passenger_panic", -2.0))
	var pos: Vector2 = m["scene_pos"]
	var same: bool = layout.carriage_at(pos.x) == layout.carriage_at(player.global_position.x)
	Events.notify("Крик в этом вагоне!" if same else "Крик из соседнего вагона!", "siren")
	hud.show_direction(pos, "Крик!", 7.0)
	for id: String in npcs:
		var n: NPCController = npcs[id]
		if not n.dead and n.global_position.distance_to(pos) < 520.0:
			n.react(pos, 4.0 + randf())
	update_goal()


func _check_discovery() -> void:
	for m: Dictionary in investigation.murders.undiscovered():
		if player.global_position.distance_to(m["scene_pos"]) < DISCOVER_DISTANCE and not camera_system.playback:
			investigation.discover_murder(m)


# --- обвинение и итог ---------------------------------------------------------------------
## Вызывается из журнала («Итог дела» → «Задержать»).
func accuse(suspect: String, clue_ids: Array, monster_guess: String, motive: int = -1, method: int = -1) -> void:
	ui.close_all()
	var result: Dictionary = investigation.accuse(suspect, clue_ids, monster_guess, motive, method)
	if result.get("correct", false):
		await arrest.play_arrest(suspect)
		investigation.finish("solved", result)
	elif not investigation.ended:
		await arrest.play_wrong(suspect, str(result.get("reaction", "")))
		if not investigation.ended:
			hud.show_banner("Почему это ошибка", str(result.get("why", "")), 6.0)


func _on_finished(result: Dictionary) -> void:
	autosave_clear()
	if result["outcome"] != "solved":
		await arrest.play_failure(result)
	ui.close_all()
	ui.open("result_screen", {"result": result})


# --- сохранение ---------------------------------------------------------------------------
func snapshot() -> Dictionary:
	var s: Dictionary = investigation.snapshot()
	s["player"] = [player.global_position.x, player.global_position.y]
	return s


func autosave() -> void:
	if investigation.ended:
		return
	SaveManager.store_case_progress(snapshot())


func autosave_clear() -> void:
	SaveManager.clear_case_progress()


func _restore(s: Dictionary) -> void:
	investigation.restore(s)
	for id: String in investigation.story.spawned:
		if id.begins_with("-"):
			remove_item(id.substr(1))
		else:
			spawn_item(investigation.story.item_def(id))
	for npc: String in investigation.npc_state:
		if npcs.has(npc):
			npcs[npc].set_condition(str(investigation.npc_state[npc]))
	for m: Dictionary in investigation.murders.killed():
		_kill(m, true)
	for m: Dictionary in investigation.murders.murders:
		var md: MurderDirector = investigation.murders
		if md.stage_done(m, "tunnel_in") and not md.stage_done(m, "tunnel_out"):
			train.set_tunnel(true)
			AudioManager.set_tunnel_ambience(true)
	var p: Array = s.get("player", [])
	if p.size() == 2:
		player.global_position = Vector2(float(p[0]), float(p[1]))
	for i in investigation.events_done:
		var ev: Dictionary = case_data["events"][i]
		match str(ev["type"]):
			"tunnel_start":
				train.set_tunnel(true)
			"tunnel_end":
				train.set_tunnel(false)
			"rain_start":
				train.set_rain(true)
			"station_approach":
				train.set_station(true)
	for id: String in npcs:
		if investigation.suspects.flag(id, "detained"):
			npcs[id].set_detained(true)


func exit_to_menu(save: bool = true) -> void:
	if save:
		autosave()
	AudioManager.set_train_ambience(false)
	get_tree().change_scene_to_file("res://ui/screens/main_menu.tscn")
