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
	await _start("level_05")
	var inv: InvestigationManager = game.investigation
	check(inv.hunts.size() == 2, "дело 5: две охоты (по ночам)")
	var h0: Dictionary = inv.hunts[0]
	inv.advance(float(h0["from"]) - inv.clock + 0.05)
	await wait_frames(3)
	var hunter: Hunter = game.hunt.hunter
	check(hunter != null, "охотник вышел в начале ночи")
	if hunter == null:
		await _end()
		return
	# Видимого героя ловит.
	for id: String in inv.data["objects"]:
		var o: Dictionary = inv.data["objects"][id]
		for hs: Dictionary in o.get("hotspots", []):
			inv.give(str(hs["clue"]))
	var can_drop: int = inv.droppable_clues().size()
	var found_before: int = inv.evidence.found.size()
	var c0: float = inv.clock
	hunter.global_position = game.player.global_position + Vector2(30, 0)
	await wait_seconds(1.2)
	check(inv.hunts_caught == 1, "охотник поймал видимого героя")
	check(inv.clock - c0 >= InvestigationManager.CATCH_COST - 0.01, "поимка стоит %d минут" % int(InvestigationManager.CATCH_COST))
	check(game.hunt.hunter == null and h0["id"] in inv.hunts_done, "после поимки охота закончилась")
	if can_drop > 0:
		check(inv.evidence.found.size() == found_before - 1, "одна улика выпала из рук")
	check(not inv.ended, "первая поимка — не поражение")
	# Спрятавшегося не ловит.
	var h1: Dictionary = inv.hunts[1]
	inv.advance(float(h1["from"]) - inv.clock + 0.05)
	await wait_frames(3)
	hunter = game.hunt.hunter
	check(hunter != null, "вторая охота началась")
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
	check(inv.hunts_caught == 1, "спрятавшегося героя охотник не ловит")
	check(not hunter.sees_player(), "из укрытия героя не видно")
	# Сохранение.
	var snap: Dictionary = inv.snapshot()
	inv.hunts_caught = 0
	inv.hunts_done.clear()
	inv.restore(snap)
	check(inv.hunts_caught == 1 and h0["id"] in inv.hunts_done, "охота сохраняется")
	# Вторая поимка — поражение.
	game.leave_hide()
	check(not game.player.in_hiding, "герой вышел из укрытия")
	hunter.mode = "chase"
	hunter.global_position = game.player.global_position + Vector2(20, 0)
	await wait_seconds(1.2)
	check(inv.ended and inv.hunts_caught == 2, "вторая поимка — поражение")
	await _end()


func test_hunter_avoids_furniture() -> void:
	await _start("level_05")
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
