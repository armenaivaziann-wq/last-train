extends TestSuite
## Убийства в туннелях (дела 3–6): за минуту — предупреждение, кто в опасности; герой рядом —
## убийца отступает; трое погибших — маньяк побеждает; спасённые сохраняются и влияют на звёзды.


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


func _victims(inv: InvestigationManager) -> Array:
	return inv.murders.murders.filter(func(m: Dictionary) -> bool: return m["victim"] != "")


func test_tunnel_plan_and_warning() -> void:
	for lvl: String in ["level_03", "level_04", "level_05", "level_06"]:
		await _start(lvl)
		var inv: InvestigationManager = game.investigation
		var ms: Array = _victims(inv)
		check(ms.size() == 3, "%s: три туннеля с жертвами" % lvl)
		var pool: Array = inv.data["murders"]["victim_pool"]
		check(ms.all(func(m: Dictionary) -> bool: return m["victim"] in pool), "%s: жертвы — только из списка дела" % lvl)
		var m: Dictionary = ms[0]
		inv.advance(float(m["t"]["warn"]) - inv.clock + 0.01)
		await wait_frames(2)
		game.ui.close_all()
		game.update_goal()
		check(game.hud._goal_label.text.contains("Туннель через") and game.hud._goal_label.text.contains(Db.char_name(m["victim"])), "%s: за минуту — кто в опасности" % lvl)
		await _end()


func test_guard_foils_murder() -> void:
	await _start("level_04")
	var inv: InvestigationManager = game.investigation
	var m: Dictionary = _victims(inv)[0]
	inv.advance(float(m["t"]["warn"]) - inv.clock + 0.01)
	await wait_frames(1)
	game.ui.close_all()
	inv.advance(float(m["t"]["kill"]) - 0.05 - inv.clock)
	await wait_frames(1)
	game.player.global_position = game.npcs[m["victim"]].global_position + Vector2(20, 0)
	inv.advance(0.1)
	await wait_frames(2)
	check(inv.murders.is_foiled(m) and inv.state_of(m["victim"]) != "dead", "герой рядом — убийца отступил, жертва жива")
	check(inv.evidence.has("s_%s_foiled" % m["prefix"]), "герой заметил примету убийцы")
	check(not game.crime_scenes.has(int(m["index"])), "тела нет")
	var snap: Dictionary = inv.murders.serialize()
	inv.murders.foiled.clear()
	inv.murders.restore(snap)
	check(inv.murders.is_foiled(m), "спасение сохраняется")
	await _end()


func test_massacre_loses() -> void:
	await _start("level_05")
	var inv: InvestigationManager = game.investigation
	var res: Array = []
	inv.finished.connect(func(r: Dictionary) -> void: res.append(r))
	var last: Dictionary = _victims(inv)[2]
	inv.advance(float(last["t"]["kill"]) + 0.05 - inv.clock)
	await wait_frames(2)
	check(inv.ended and res.size() == 1 and res[0]["outcome"] == "massacre", "трое погибли — маньяк победил")
	check(int(res[0]["dead"]) == 3, "в итоге видно, сколько погибло")
	await _end()


func test_deaths_cost_a_star() -> void:
	await _start("level_06")
	var inv: InvestigationManager = game.investigation
	var ms: Array = _victims(inv)
	inv.advance(float(ms[1]["t"]["kill"]) + 0.05 - inv.clock)
	await wait_frames(1)
	check(inv.murders.killed().size() == 2 and not inv.ended, "двое погибли — дело продолжается")
	check(inv.compute_stars(true, 3) == 2, "двое погибших — не больше двух звёзд")
	await _end()
