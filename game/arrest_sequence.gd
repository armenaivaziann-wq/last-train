class_name ArrestSequence
extends RefCounted
## Короткие постановочные сцены: задержание с раскрытием монстра, ошибочное обвинение,
## прибытие на станцию. Управление на это время отключается, но сцены короткие.

var game: Game
var running: bool = false


func _init(g: Game) -> void:
	game = g


func _wait(sec: float) -> void:
	await game.get_tree().create_timer(sec).timeout


func _begin() -> void:
	running = true
	game.investigation.hold("arrest")
	game.player.input_enabled = false
	game.player.touch_vector = Vector2.ZERO
	game.hud.set_controls_visible(false)


func _end() -> void:
	running = false
	game.investigation.release("arrest")
	game.player.input_enabled = not game.ui.has_modal()
	game.hud.set_controls_visible(true)
	game.camera.focus_point = null


## Детектив встаёт рядом с подозреваемым (короткая вспышка-переход).
func _approach(npc: NPCController) -> void:
	var flash := _flash(Color(0.05, 0.03, 0.15, 1.0), 0.25)
	await _wait(0.25)
	# Встаём в коридоре напротив подозреваемого (там всегда свободно) или сбоку от него.
	var cy: float = game.layout.corridor_y
	if npc.global_position.y < cy - 20.0:
		game.player.global_position = Vector2(npc.global_position.x, cy)
		game.player.facing = "up"
	else:
		game.player.global_position = npc.global_position + Vector2(-22.0, 0.0)
		game.player.facing = "right"
	game.camera.focus_point = npc.global_position
	game.camera.snap_to_target()
	var tw := flash.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.3)
	tw.tween_callback(flash.get_parent().queue_free)
	await _wait(0.3)


func _flash(color: Color, fade_in: float) -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = 50
	var r := ColorRect.new()
	Ui.full_rect(r)
	r.color = color
	r.modulate.a = 0.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	game.add_child(layer)
	r.create_tween().tween_property(r, "modulate:a", 1.0, fade_in)
	return r


## Правильное задержание (≈2,5 с): реплика подозреваемого → мерцание света → дрожь силуэта →
## обычный спрайт исчезает → истинная форма злодея (отдельный спрайт villains/<id>.png) →
## короткая угрожающая поза → итог. Никакого фиолетового свечения — только свет и тень.
func play_arrest(suspect: String) -> void:
	var npc: NPCController = game.npcs.get(suspect)
	if npc == null:
		return
	_begin()
	AudioManager.play_music("")
	await _approach(npc)
	var villain_id: String = str(game.case_data["monster"])
	var villain: Dictionary = Db.monster(villain_id)
	npc.set_detained(true)
	npc.sprite.modulate = Color.WHITE
	game.player.play_action("arrest", 1.0)
	AudioManager.play_sfx("arrest", -6.0)
	game.hud.overlay.show_bark(npc, str(villain.get("reveal_line", "Я просто пассажир!")))
	await _wait(0.6)
	game.train.flicker(0.9)
	AudioManager.play_sfx("lights_flicker", -6.0)
	var tw := npc.create_tween()
	for i in 6:
		tw.tween_property(npc.sprite, "position:x", 1.5 if i % 2 == 0 else -1.5, 0.05)
	tw.tween_property(npc.sprite, "position:x", 0.0, 0.05)
	await tw.finished
	game.train.blackout(0.25)
	AudioManager.play_sfx("villain_sting")
	await _wait(0.12)
	npc.sprite.visible = false
	var true_form := AnimatedSprite2D.new()
	true_form.name = "TrueForm"
	true_form.sprite_frames = Db.villain_frames(villain_id)
	true_form.offset = Vector2(0, CharacterSprite.FOOT_OFFSET)
	true_form.play("idle")
	npc.add_child(true_form)
	await _wait(0.45)
	true_form.play("menace")
	game.hud.overlay.show_bark(npc, str(villain.get("menace_line", "...")))
	await _wait(0.8)
	true_form.play("idle")
	game.player.play_action("victory", 1.0)
	AudioManager.play_sfx("success", -4.0)
	await _wait(0.5)
	_end()


func play_wrong(suspect: String, reaction: String) -> void:
	var npc: NPCController = game.npcs.get(suspect)
	if npc == null:
		return
	_begin()
	await _approach(npc)
	npc.set_detained(true)
	game.player.play_action("arrest", 0.8)
	await _wait(0.8)
	AudioManager.play_sfx("wrong")
	game.hud.overlay.show_bark(npc, reaction if reaction != "" else "Я невиновен!")
	game.player.play_action("wrong", 1.6)
	await _wait(1.8)
	npc.set_detained(false)
	var left: int = game.investigation.max_mistakes() - game.investigation.mistakes
	var f: bool = str(Db.character(suspect).get("gender", "m")) == "f"
	Events.notify("Ошибка! %s %s. −%d репутации, −%d мин. Осталось права на ошибку: %d" % [
		Db.char_name(suspect), "невиновна" if f else "невиновен", InvestigationManager.WRONG_REPUTATION,
		int(game.investigation.wrong_penalty()), left], "guard")
	_end()


## Поражение. По дедлайну злодей побеждает: короткая сцена его исчезновения.
func play_failure(result: Dictionary) -> void:
	_begin()
	AudioManager.play_music("")
	var villain_id: String = str(game.case_data["monster"])
	var villain: Dictionary = Db.monster(villain_id)
	if result["outcome"] == "timeout":
		game.train.set_station(true)
		var npc: NPCController = game.npcs.get(str(game.case_data["culprit"]))
		if npc and not npc.dead:
			game.camera.focus_point = npc.global_position
			game.train.flicker(1.0)
			AudioManager.play_sfx("villain_escape")
			await _wait(0.5)
			npc.sprite.visible = false
			var form := AnimatedSprite2D.new()
			form.sprite_frames = Db.villain_frames(villain_id)
			form.offset = Vector2(0, CharacterSprite.FOOT_OFFSET)
			form.play("menace")
			npc.add_child(form)
			game.hud.overlay.show_bark(npc, str(villain.get("menace_line", "...")))
			var tw := form.create_tween()
			tw.tween_interval(0.6)
			tw.tween_property(form, "modulate:a", 0.0, 0.7)
			await tw.finished
			npc.set_dead(true)
		Events.notify(str(villain.get("escape_text", "Злодей скрылся.")), "train")
	else:
		Events.notify("Слишком много ошибок — охрана прекратила расследование.", "guard")
	game.player.play_action("wrong", 1.2)
	await _wait(1.2)
	_end()
