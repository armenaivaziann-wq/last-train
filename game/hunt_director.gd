class_name HuntDirector
extends Node
## Охота в живом поезде: укрытия, появление охотника в назначенное время (обычно ночью),
## нарастающая опасность на экране (красная виньетка, вибрация «сердцебиение»), поимка.
## Пока открыто окно (журнал, камеры, диалог) — охотник замирает вместе со временем дела.

var game: Game
var nav: HuntNav
var spots: Array[Dictionary] = []
var hunter: Hunter = null
var current: Dictionary = {}
var _beat: float = 0.0
var _step_sfx: float = 0.0
var _hinted: bool = false


func setup(g: Game) -> void:
	game = g
	name = "HuntDirector"
	nav = HuntNav.new(g.layout)
	spots = HideSpots.build(g.layout, g.case_data)
	for sp: Dictionary in spots:
		var it := Interactable.new()
		it.interact_id = str(sp["id"])
		it.kind = Interactable.Kind.HIDE
		it.label = str(sp["label"])
		it.radius = 22.0
		it.needs_light = false
		it.position = sp["pos"]
		g.glow_layer.add_child(it)


func _process(delta: float) -> void:
	var inv: InvestigationManager = game.investigation
	var paused: bool = game.ui.has_modal() or game.arrest.running or inv.ended or game.camera_system.playback
	if hunter:
		hunter.set_physics_process(not paused)
	if paused:
		return
	var h: Dictionary = inv.hunt_at(inv.clock)
	if hunter and (h.is_empty() or str(h["id"]) != str(current.get("id", ""))):
		_finish_hunt()
	if hunter == null and not h.is_empty():
		_start(h)
	_update_danger(delta)


func _start(h: Dictionary) -> void:
	current = h
	var def: Dictionary = h["def"]
	var p: Vector2 = game.player.global_position
	var w: float = game.layout.width
	# Охотник выходит с дальнего от героя конца поезда.
	var x: float = w - 40.0 if p.x < w / 2.0 else 40.0
	var start: Vector2 = nav.center(nav.free_cell_near(Vector2(x, game.layout.corridor_y)))
	var d2: Dictionary = def.duplicate()
	d2["speed_mult"] = float(game.investigation.profile.get("hunt_speed", 1.0))
	hunter = Hunter.new()
	hunter.setup(nav, game.player, str(def.get("hunter", game.case_data.get("monster", "shadow"))), start, d2, game.investigation.case_seed + game.investigation.hunts_done.size())
	hunter.caught.connect(_on_caught)
	game.entities.add_child(hunter)
	AudioManager.play_sfx("villain_sting", -6.0)
	game.hud.show_banner(str(def.get("title", "Кто-то идёт")), str(def.get("text", "В темноте по вагонам кто-то бродит и ищет вас. Спрячьтесь — под полкой, под столом, за ящиками.")), 3.5)
	if not _hinted and not spots.is_empty():
		_hinted = true
		# Подсказка, где спрятаться, — после баннера, чтобы не накладывались.
		get_tree().create_timer(3.6).timeout.connect(func() -> void:
			if hunter and is_instance_valid(game):
				var near: Dictionary = HideSpots.nearest(spots, game.player.global_position)
				game.hud.show_direction(near["pos"], "Укрытие: " + str(near["label"]).to_lower(), 5.0))


func _finish_hunt() -> void:
	if hunter == null:
		return
	game.investigation.end_hunt(str(current["id"]))
	hunter.queue_free()
	hunter = null
	current = {}
	game.hud.set_danger(0.0)
	Events.notify("Шаги стихли. Охотник ушёл.", "footprint")


func _on_caught() -> void:
	var inv: InvestigationManager = game.investigation
	var id: String = str(current.get("id", ""))
	hunter.queue_free()
	hunter = null
	current = {}
	game.hud.set_danger(0.0)
	AudioManager.play_sfx("villain_escape", -2.0)
	AudioManager.vibrate(220)
	if game.player.in_hiding:
		game.leave_hide()
	var dropped: String = inv.hunter_caught(id)
	if inv.ended:
		return
	# Очнулся в ближайшем тамбуре (или у начала поезда).
	game.player.global_position = _wake_point()
	game.player.velocity = Vector2.ZERO
	game.camera.snap_to_target()
	var lost: String = ""
	if dropped != "":
		lost = " Улика «%s» выпала из рук — найдите её снова." % inv.evidence.clue(dropped)["title"]
	game.hud.show_banner("Вас схватили!", "Очнулись в тамбуре: −%d мин.%s Ещё раз — и дело провалено." % [int(InvestigationManager.CATCH_COST), lost] if inv.hunts_caught + 1 >= inv.max_catches()
		else "Очнулись в тамбуре: −%d мин.%s" % [int(InvestigationManager.CATCH_COST), lost], 5.0)
	game.hud.set_key_clues(inv.evidence.key_found_count())


func _wake_point() -> Vector2:
	var best: Vector2 = Vector2.INF
	var p: Vector2 = game.player.global_position
	for cid in game.layout.carriage_ids:
		if game.layout.widths[cid] < 200.0:
			var c := Vector2(game.layout.offsets[cid] + game.layout.widths[cid] / 2.0, game.layout.corridor_y)
			if best == Vector2.INF or c.distance_to(p) < best.distance_to(p):
				best = c
	if best == Vector2.INF:
		var ps: Dictionary = game.case_data["player_start"]
		best = Vector2(game.layout.offsets[ps["carriage"]] + float(ps["pos"][0]), float(ps["pos"][1]))
	return nav.center(nav.free_cell_near(best))


func _update_danger(delta: float) -> void:
	if hunter == null:
		return
	var d: float = hunter.global_position.distance_to(game.player.global_position)
	var danger: float = clampf(1.0 - (d - 40.0) / 320.0, 0.0, 1.0)
	if hunter.mode == "chase":
		danger = maxf(danger, 0.7)
	if game.player.in_hiding:
		danger *= 0.6
	game.hud.set_danger(danger)
	_beat -= delta
	if danger > 0.45 and _beat <= 0.0:
		_beat = lerpf(1.0, 0.45, danger)
		AudioManager.vibrate(int(20 + 40 * danger))
	_step_sfx -= delta
	if _step_sfx <= 0.0:
		_step_sfx = 0.7
		AudioManager.play_sfx("steps_wall", lerpf(-28.0, -6.0, danger), randf_range(0.8, 0.95))
