extends TestSuite
## Прятки и охота: укрытия есть в каждом составе и до них можно дойти; охотник выходит
## в назначенное время, ловит видимого героя (−3 минуты, улика выпадает), не ловит
## спрятавшегося; вторая поимка — поражение; состояние охоты сохраняется.


func _start(level_id: String, seed_value: int = 7) -> void:
	SaveManager.prepare_level(level_id)
	SaveManager.pending_seed = seed_value
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await wait_frames(2)
	game.ui.close_all()
	await wait_frames(1)


func _end() -> void:
	game.queue_free()
	game = null
	await wait_frames(2)


func test_hide_spots_everywhere() -> void:
	for l: Dictionary in Db.levels():
		var cid: String = str(l.get("case", "gen"))
		if cid == "gen":
			cid = "case_01"
		var d: Dictionary = Db.resolve_case(cid, 7)
		var lay := TrainLayout.build(PackedStringArray(d["carriages"]))
		var hs: Array[Dictionary] = HideSpots.build(lay, d)
		check(hs.size() >= 4, "%s: не меньше 4 укрытий (есть %d)" % [l["id"], hs.size()])
		var nav := HuntNav.new(lay)
		var ps: Dictionary = d["player_start"]
		nav.build_field(Vector2(lay.offsets[ps["carriage"]] + float(ps["pos"][0]), float(ps["pos"][1])))
		for h: Dictionary in hs:
			check(nav.reachable(h["pos"]), "%s: охотник может дойти до укрытия «%s» (%s)" % [l["id"], h["label"], h["carriage"]])


func test_hunt_catch_and_hide() -> void:
	await _start("level_12")
	var inv: InvestigationManager = game.investigation
	check(inv.hunts.size() == 1, "дело 12: одна охота — вампир во вторую ночь")
	var h0: Dictionary = inv.hunts[0]
	inv.advance(float(h0["from"]) - inv.clock + 0.05)
	await wait_frames(3)
	var hunter: Hunter = game.hunt.hunter
	check(hunter != null, "охотник вышел в начале ночи")
	if hunter == null:
		await _end()
		return
	check(game.hud.quiet and not game.hud._toasts.visible, "во время охоты уведомления скрыты")
	check(game.hud._goal_label.text.contains("Спрячьтесь"), "цель во время охоты — спрятаться")
	# Спрятавшегося не ловит.
	var near: Dictionary = HideSpots.nearest(game.hunt.spots, game.player.global_position)
	game.player.global_position = near["pos"] + Vector2(0, 8)
	var it: Interactable = null
	for n in get_tree().get_nodes_in_group(&"interactables"):
		if n is Interactable and (n as Interactable).interact_id == near["id"]:
			it = n
	game.enter_hide(it)
	check(game.player.in_hiding and not game.player.flashlight.on, "в укрытии фонарь погашен")
	hunter.global_position = game.player.global_position + Vector2(10, 0)
	await wait_seconds(1.5)
	check(inv.hunts_caught == 0, "спрятавшегося героя охотник не ловит")
	check(not hunter.sees_player(), "из укрытия героя не видно")
	# Видимого ловит: −3 минуты, улика выпадает. Герой выходит в коридор.
	game.leave_hide()
	game.player.global_position = Vector2(game.player.global_position.x, game.layout.corridor_y)
	for id: String in inv.data["objects"]:
		for hs: Dictionary in inv.data["objects"][id].get("hotspots", []):
			inv.give(str(hs["clue"]))
	var can_drop: int = inv.droppable_clues().size()
	var found_before: int = inv.evidence.found.size()
	var c0: float = inv.clock
	hunter.mode = "chase"
	hunter.global_position = game.player.global_position + Vector2(20, 0)
	await wait_seconds(1.2)
	check(inv.hunts_caught == 1, "охотник поймал видимого героя")
	check(inv.clock - c0 >= InvestigationManager.CATCH_COST - 0.01, "поимка стоит %d минут" % int(InvestigationManager.CATCH_COST))
	check(game.hunt.hunter == null and h0["id"] in inv.hunts_done, "после поимки охота закончилась")
	check(not game.hud.quiet, "после охоты уведомления вернулись")
	if can_drop > 0:
		check(inv.evidence.found.size() == found_before - 1, "одна улика выпала из рук")
	check(not inv.ended, "первая поимка — не поражение")
	var snap: Dictionary = inv.snapshot()
	inv.hunts_caught = 0
	inv.hunts_done.clear()
	inv.restore(snap)
	check(inv.hunts_caught == 1 and h0["id"] in inv.hunts_done, "охота сохраняется")
	# Вторая поимка (сюжетная ловушка) — поражение.
	inv._fire_story({"id": "t_trap", "effects": [{"type": "hunt", "id": "h_test", "minutes": 1.5, "hunter": "shadow"}]})
	await wait_frames(3)
	hunter = game.hunt.hunter
	check(hunter != null, "ловушка запускает охоту")
	game.player.global_position = Vector2(game.player.global_position.x, game.layout.corridor_y)
	hunter.mode = "chase"
	hunter.global_position = game.player.global_position + Vector2(20, 0)
	await wait_seconds(1.2)
	check(inv.ended and inv.hunts_caught == 2, "вторая поимка — поражение")
	await _end()


func test_hunter_avoids_furniture() -> void:
	await _start("level_12")
	var nav: HuntNav = game.hunt.nav
	var start: Vector2 = Vector2(40, game.layout.corridor_y)
	# Цель — свободная клетка у дальнего укрытия (сам герой в укрытии «внутри» мебели).
	var target: Vector2 = nav.center(nav.free_cell_near(HideSpots.nearest(game.hunt.spots, Vector2(game.layout.width - 60, 120))["pos"]))
	nav.build_field(target)
	var p: Vector2 = nav.center(nav.free_cell_near(start))
	var steps: int = 0
	var ok: bool = true
	while p.distance_to(target) > 10.0 and steps < 2000:
		var q: Vector2 = nav.next_point(p, target)
		if q == p:
			break
		p = p.move_toward(q, 4.0)
		if not nav.is_free(p):
			ok = false
			print("  сквозь мебель: ", p)
		steps += 1
	check(ok, "путь охотника не проходит сквозь мебель")
	check(p.distance_to(target) <= 12.0, "охотник доходит через весь поезд до укрытия")
	await _end()


## Первая охота (дело 3): отражение безвредно, из укрытия можно подслушать улику.
func test_tutorial_hunt_overhear() -> void:
	SaveManager.prepare_level("level_03")
	SaveManager.pending_seed = 7
	game = load("res://game/game.tscn").instantiate()
	add_child(game)
	await wait_frames(2)
	game.ui.close_all()
	await wait_frames(1)
	var inv: InvestigationManager = game.investigation
	inv.advance(float(inv.hunts[0]["from"]) - inv.clock + 0.05)
	await wait_frames(3)
	var hunter: Hunter = game.hunt.hunter
	check(hunter != null, "дело 3: в первую ночь из зеркала выходит фигура")
	var near: Dictionary = HideSpots.nearest(game.hunt.spots, game.player.global_position)
	game.player.global_position = near["pos"] + Vector2(0, 8)
	for n in get_tree().get_nodes_in_group(&"interactables"):
		if n is Interactable and (n as Interactable).interact_id == near["id"]:
			game.enter_hide(n)
	hunter.global_position = game.player.global_position + Vector2(80, 0)
	await wait_frames(3)
	check(inv.evidence.has("s_l3_overheard"), "из укрытия подслушана улика")
	game.leave_hide()
	var c0: float = inv.clock
	hunter.mode = "chase"
	hunter.global_position = game.player.global_position + Vector2(12, 0)
	await wait_seconds(0.6)
	check(inv.hunts_caught == 0 and inv.clock - c0 < 1.0 and not inv.ended, "первая охота безвредна")
	await _end()


## Мороз (дело 11): на открытой площадке дольше 45 секунд — −2 минуты на отогрев.
func test_cold_platform() -> void:
	await _start("level_11")
	var inv: InvestigationManager = game.investigation
	var x0: float = game.layout.offsets["v_platform"] + game.layout.widths["v_platform"] / 2.0
	game.player.global_position = Vector2(x0, game.layout.corridor_y)
	var c0: float = inv.clock
	game._sync_cold(20.0)
	check(inv.clock - c0 < 0.01, "мороз: 20 секунд — ещё терпимо")
	game._sync_cold(30.0)
	check(inv.clock - c0 >= 1.99, "мороз: 50 секунд — отогрев стоит 2 минуты")
	await _end()
