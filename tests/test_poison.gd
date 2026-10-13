extends TestSuite
## Сюжетный выбор и яд (дело 2): выпить — улика о яде и таймер противоядия, отказаться —
## другая улика; противоядие — головоломка в аптечке; не успел — поражение; выбор сохраняется.


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


func _offer() -> GameScreen:
	var inv: InvestigationManager = game.investigation
	inv.advance(1.3)
	await wait_frames(2)
	return game.ui.top()


func test_drink_poison_and_antidote() -> void:
	await _start("level_02")
	var inv: InvestigationManager = game.investigation
	var scr: GameScreen = await _offer()
	check(scr != null and scr.name == "choice_screen", "в 1-ю минуту подают напиток — окно выбора")
	scr._pick(true)
	await wait_frames(2)
	check(inv.poisoned() and inv.evidence.has("p_l2_taste"), "выпил — отравлен и знает вкус яда")
	check(is_equal_approx(game.player.speed_mult, 0.7), "яд замедляет героя")
	check(game.hud._goal_label.text.contains("противоядие"), "цель — найти противоядие")
	var snap: Dictionary = inv.snapshot()
	inv.poison = {}
	inv.choices.clear()
	inv.restore(snap)
	check(inv.poisoned() and inv.choices.get("offer_l2") == "accept", "яд и выбор сохраняются")
	game.ui.close_all()
	inv.give("s_l2_antidote_recipe")
	game.open_object("obj_l2_medkit")
	await wait_frames(1)
	var pz: GameScreen = game.ui.top()
	check(pz != null and pz.name == "puzzle_screen", "аптечка — головоломка противоядия")
	var ans: Array = inv.puzzle("puz_l2_antidote")["answer"]
	for i in ans.size():
		for _k in int(ans[i]) + 1:
			pz._cycle(i)
	pz._try_pairs()
	await wait_frames(2)
	check(not inv.poisoned() and inv.evidence.has("i_l2_antidote"), "противоядие снимает яд")
	check(is_equal_approx(game.player.speed_mult, 1.0), "скорость вернулась")
	await _end()


func test_poison_timeout_loses() -> void:
	await _start("level_02", 11)
	var inv: InvestigationManager = game.investigation
	var scr: GameScreen = await _offer()
	scr._pick(true)
	await wait_frames(1)
	inv.advance(5.1)
	await wait_frames(2)
	check(inv.ended, "не нашёл противоядие за 5 минут — дело провалено")
	await _end()


func test_refuse_drink() -> void:
	await _start("level_02", 12)
	var inv: InvestigationManager = game.investigation
	var scr: GameScreen = await _offer()
	scr._pick(false)
	await wait_frames(1)
	check(not inv.poisoned() and inv.evidence.has("p_l2_gloves_seen"), "отказался — не отравлен, заметил перчатки")
	check(inv.dialogue.topics("agata", inv.evidence, inv.dialogue_ctx("agata")).any(func(t: Dictionary) -> bool: return t["id"] == "drink"),
		"можно спросить настоящую Агату о напитке")
	await _end()


func test_pending_offer_survives_exit() -> void:
	await _start("level_02", 13)
	var inv: InvestigationManager = game.investigation
	await _offer()
	check(inv.pending_offers().size() == 1, "выбор не сделан — предложение ждёт")
	var snap: Dictionary = inv.snapshot()
	inv.restore(snap)
	check(inv.pending_offers().size() == 1, "после загрузки предложение снова ждёт выбора")
	await _end()
