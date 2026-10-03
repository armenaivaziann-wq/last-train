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


func play_arrest(suspect: String) -> void:
	var npc: NPCController = game.npcs.get(suspect)
	if npc == null:
		return
	_begin()
	AudioManager.play_music("")
	await _approach(npc)
	npc.set_detained(true)
	game.player.play_action("arrest", 1.4)
	AudioManager.play_sfx("arrest")
	game.hud.overlay.show_bark(npc, "Что?! Я... я просто пассажир!")
	await _wait(1.2)
	# Раскрытие: дрожь, вспышка, истинная форма
	var tw := npc.create_tween()
	for i in 6:
		tw.tween_property(npc.sprite, "position:x", 2.0 if i % 2 == 0 else -2.0, 0.05)
	tw.tween_property(npc.sprite, "position:x", 0.0, 0.05)
	await tw.finished
	AudioManager.play_sfx("reveal")
	var flash := _flash(Color(1, 0.95, 1, 1), 0.12)
	await _wait(0.15)
	npc.sprite.visible = false
	var monster := AnimatedSprite2D.new()
	monster.sprite_frames = Db.monster_frames(str(game.case_data["monster"]))
	monster.offset = Vector2(0, -22)
	monster.scale = Vector2(0.2, 0.2)
	monster.play()
	npc.add_child(monster)
	var glow := Sprite2D.new()
	glow.texture = Db.texture("ui/glow_purple.png")
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.position = Vector2(0, -20)
	glow.scale = Vector2(2.2, 2.2)
	npc.add_child(glow)
	var ft := flash.create_tween()
	ft.tween_property(flash, "modulate:a", 0.0, 0.35)
	ft.tween_callback(flash.get_parent().queue_free)
	var mt := monster.create_tween()
	mt.tween_property(monster, "scale", Vector2(1.15, 1.15), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	mt.tween_property(monster, "scale", Vector2.ONE, 0.15)
	game.hud.overlay.show_bark(npc, "Ой-ой... Меня раскрыли!")
	for i in 6:
		game._sparkle(npc.global_position + Vector2(randf_range(-20, 20), randf_range(-30, 0)))
	await _wait(1.0)
	game.player.play_action("victory", 1.4)
	AudioManager.play_sfx("success")
	# Монстра забирает волшебная ловушка-фонарь
	var gt := glow.create_tween().set_parallel(true)
	gt.tween_property(glow, "scale", Vector2(0.3, 0.3), 1.0)
	gt.tween_property(monster, "scale", Vector2(0.3, 0.3), 1.0).set_delay(0.3)
	gt.tween_property(monster, "modulate:a", 0.0, 0.6).set_delay(0.7)
	await _wait(1.5)
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
	Events.notify("Ошибка! %s невиновен(-на). −%d репутации, −%d мин. Осталось права на ошибку: %d" % [
		Db.char_name(suspect), InvestigationManager.WRONG_REPUTATION, int(InvestigationManager.WRONG_TIME_PENALTY), left], "guard")
	_end()


func play_failure(result: Dictionary) -> void:
	_begin()
	AudioManager.play_music("")
	if result["outcome"] == "timeout":
		game.train.set_station(true)
		Events.notify("Поезд прибыл на станцию %s. Монстр скрылся в толпе..." % game.case_data["station_to"], "train")
	else:
		Events.notify("Слишком много ошибок — охрана прекратила расследование.", "guard")
	game.player.play_action("wrong", 1.6)
	await _wait(2.2)
	_end()
