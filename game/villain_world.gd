class_name VillainWorld
extends Node2D
## Видимые проявления способностей злодея в мире. Обновляется по времени дела —
## живому или времени записи камеры (поэтому записи совпадают с тем, что видел игрок).
##   • облик перевёртыша на его спрайте;
##   • отражения в зеркалах вагонов (у зеркальника отражения нет);
##   • лишний чемодан мимика, переползающий между местами в туннелях;
##   • неправильная тень теневика.

const MIRROR_REACH_X: float = 26.0

var game: Game
var hooks: VillainHooks
var _mirrors: Array = []   # [{pos: Vector2 (центр стекла), sprite: Sprite2D}]
var _bag: Sprite2D
var _bag_it: Interactable
var _lamps: Array[Vector2] = []
var _windows: Array = []    # [{pos, carriage, sprite}]
var _dark: Dictionary = {}  # вагон → ColorRect затемнения
var _ghost: Sprite2D
var _lingers: Array = []    # [{def, sprite, it}]
var _t_now: float = 0.0


func setup(g: Game) -> void:
	game = g
	hooks = g.investigation.hooks
	z_index = 1
	for cid in g.layout.carriage_ids:
		for p: Dictionary in Db.layout(cid).get("props", []):
			if p["sprite"] == "mirror":
				var center := Vector2(g.layout.offsets[cid] + float(p["pos"][0]), float(p["pos"][1]) + 1.0)
				var s := Sprite2D.new()
				s.position = center
				s.scale = Vector2(0.42, 0.42)
				s.modulate = Color(0.75, 0.9, 1.0, 0.7)
				s.visible = false
				add_child(s)
				_mirrors.append({"pos": center, "sprite": s})
	if hooks.villain == "mimic":
		_bag = Sprite2D.new()
		_bag.texture = Db.texture("props/suitcase_brown.png")
		g.entities.add_child(_bag)
		_bag_it = Interactable.new()
		_bag_it.interact_id = "obj_mimic_bag"
		_bag_it.label = "Осмотреть чемодан"
		_bag_it.kind = Interactable.Kind.OBJECT
		_bag_it.radius = 22.0
		_bag.add_child(_bag_it)
	if hooks.villain == "shadow" and not g.case_data.has("shadow_ghost"):
		var npc: NPCController = g.npcs.get(hooks.culprit)
		if npc:
			npc.shadow_wrong = true
	# Лампы — источники теней; окна — отражения; тёмные зоны — силуэты.
	for cid in g.layout.carriage_ids:
		var lay: Dictionary = Db.layout(cid)
		for l: Array in lay.get("lamps", []):
			_lamps.append(Vector2(g.layout.offsets[cid] + float(l[0]), float(l[1])))
		for w: Array in lay.get("window_lights", []):
			var ws := Sprite2D.new()
			ws.position = Vector2(g.layout.offsets[cid] + float(w[0]), 31.0)
			ws.scale = Vector2(0.42, 0.42)
			ws.modulate = Color(0.8, 0.9, 1.0, 0.5)
			ws.visible = false
			ws.z_index = -1
			g.train.add_child(ws)
			_windows.append({"pos": Vector2(g.layout.offsets[cid] + float(w[0]), 100.0), "carriage": cid, "sprite": ws})
		var dark := ColorRect.new()
		dark.position = Vector2(g.layout.offsets[cid], 56.0)
		dark.size = Vector2(g.layout.widths[cid], 136.0)
		dark.color = Color(0.06, 0.05, 0.16, 0.78)
		dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dark.visible = false
		g.glow_layer.add_child(dark)
		_dark[cid] = dark
	# Люди без тени по сюжету дела.
	for id: String in g.case_data.get("no_shadow", []):
		var ns: NPCController = g.npcs.get(id)
		if ns:
			ns._shadow.visible = false
	var sg: Dictionary = g.case_data.get("shadow_ghost", {})
	if not sg.is_empty():
		_ghost = _shadow_sprite()
		g.glow_layer.add_child(_ghost)
		var owner: NPCController = g.npcs.get(str(sg["npc"]))
		if owner:
			owner._shadow.visible = false
		for l: Dictionary in sg.get("linger", []):
			var s := _shadow_sprite()
			s.position = Vector2(g.layout.offsets[l["carriage"]] + float(l["pos"][0]), float(l["pos"][1]))
			g.glow_layer.add_child(s)
			var it := Interactable.new()
			it.interact_id = str(l["object"])
			it.label = "Осмотреть тень"
			it.kind = Interactable.Kind.OBJECT
			it.needs_light = false
			s.add_child(it)
			_lingers.append({"def": l, "sprite": s, "it": it})


## Тень-силуэт человека на полу (для «живой» тени).
func _shadow_sprite() -> Sprite2D:
	var img := Image.create(16, 30, false, Image.FORMAT_RGBA8)
	for y in 30:
		for x in 16:
			var head: bool = Vector2(x + 0.5 - 8.0, y + 0.5 - 5.0).length() < 4.0
			var body: bool = y > 8 and absf(x + 0.5 - 8.0) < 5.0 - (y - 8) * 0.06 and y < 29
			if head or body:
				img.set_pixel(x, y, Color(0.03, 0.01, 0.08, 0.62))
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	s.rotation = -0.25
	s.offset = Vector2(0, -14)
	s.visible = false
	return s


func _in_zone(cid: String, t: float) -> bool:
	for z: Dictionary in game.case_data.get("dark_zones", []):
		if z["carriage"] == cid and t >= Db.parse_time(str(z["from"])) and t < Db.parse_time(str(z["to"])):
			return true
	return false


## Применить состояние способностей на момент t.
func apply(t: float) -> void:
	_t_now = t
	# Тёмные зоны: пол темнеет, люди внутри — силуэты без лица.
	for cid: String in _dark:
		_dark[cid].visible = _in_zone(cid, t)
	for id: String in game.npcs:
		var n: NPCController = game.npcs[id]
		var dark: bool = _in_zone(game.layout.carriage_at(n.global_position.x), t)
		n.set_silhouette(dark)
	# Полупрозрачность (призрак проходит сквозь стены): "translucent": [{npc, from, to}].
	for h: Dictionary in game.case_data.get("translucent", []):
		var tn: NPCController = game.npcs.get(str(h["npc"]))
		if tn:
			var on: bool = t >= Db.parse_time(str(h["from"])) and t < Db.parse_time(str(h["to"]))
			tn.sprite.modulate = Color(0.75, 0.85, 1.0, 0.38) if on else (Color(0.82, 1.0, 0.78) if tn.condition == "sick" else Color.WHITE)
	game.player.sprite.self_modulate = Color(0.08, 0.07, 0.14) if _in_zone(game.layout.carriage_at(game.player.global_position.x), t) else Color.WHITE
	# «Живая» тень: идёт по маршруту хозяина с опережением и задерживается у двери.
	var sg: Dictionary = game.case_data.get("shadow_ghost", {})
	if _ghost:
		var tl: CaseTimeline = game.investigation.timeline
		var owner: String = str(sg["npc"])
		var lead: float = float(sg.get("lead", 0.3))
		var st: Dictionary = tl.state_at(owner, t + lead)
		_ghost.visible = not game.investigation.murders.dead_at(owner, t)
		_ghost.global_position = (st["pos"] as Vector2) + Vector2(4, 2)
		# Отлучки тени без хозяина: тень одна стоит в другом месте.
		for a: Dictionary in sg.get("away", []):
			if t >= Db.parse_time(str(a["from"])) and t < Db.parse_time(str(a["to"])):
				_ghost.global_position = Vector2(game.layout.offsets[a["carriage"]] + float(a["pos"][0]), float(a["pos"][1]))
		for l: Dictionary in _lingers:
			var on: bool = t >= Db.parse_time(str(l["def"]["from"])) and t < Db.parse_time(str(l["def"]["to"]))
			l["sprite"].visible = on
			l["it"].enabled = on
	if hooks.villain == "shapeshifter" or not game.case_data.get("camera_disguises", []).is_empty():
		for id: String in game.npcs:
			game.npcs[id].set_look(hooks.appearance(id, t))
	if _bag:
		var at: Array = hooks.mimic_at(t)
		if not at.is_empty():
			_bag.position = Vector2(game.layout.offsets[at[0]] + float(at[1][0]), float(at[1][1]))
			_bag.offset = Vector2(0, -_bag.texture.get_height() / 2.0)


func _process(_delta: float) -> void:
	_update_mirrors()
	_update_shadows()
	_update_window_reflections()


## Тени от ближайшей лампы: длина и направление зависят от положения света.
func _update_shadows() -> void:
	var people: Array = game.npcs.values()
	people.append(game.player)
	for n: Node2D in people:
		var sh: Sprite2D = n._shadow
		if n is NPCController and ((n as NPCController).shadow_wrong):
			continue
		var best: Vector2 = Vector2.ZERO
		var bd: float = INF
		for l in _lamps:
			var d: float = l.distance_squared_to(n.global_position)
			if d < bd:
				bd = d
				best = l
		var dir: Vector2 = (n.global_position - best)
		var dist: float = dir.length()
		var away: Vector2 = dir / maxf(dist, 1.0)
		sh.position = Vector2(clampf(away.x * dist * 0.05, -6.0, 6.0), -1.0 + clampf(away.y * 2.0, 0.0, 2.5)).round()
		sh.scale = Vector2(1.0 + clampf(absf(away.x) * dist / 400.0, 0.0, 0.5), 1.0)


## Отражения в окнах вагонов. В некоторых делах окна «запаздывают» — правило задаётся
## в данных ("reflection_delay": {вагон: минуты}) и проверяется наблюдением.
func _update_window_reflections() -> void:
	var inv: InvestigationManager = game.investigation
	var t: float = game.camera_system.playback_time if game.camera_system.playback else inv.clock
	var delays: Dictionary = game.case_data.get("reflection_delay", {})
	for w: Dictionary in _windows:
		var tt: float = t - float(delays.get(w["carriage"], 0.0))
		var spr: Sprite2D = w["sprite"]
		var best_tex: Texture2D = null
		var bd: float = INF
		for id: String in game.npcs:
			if not hooks.has_reflection(id) or inv.murders.dead_at(id, tt) or tt < inv.history_start:
				continue
			var p: Vector2 = inv.timeline.position_at(id, tt)
			var d: Vector2 = p - w["pos"]
			if absf(d.x) < 34.0 and d.y > -30.0 and d.y < 60.0 and d.length() < bd:
				bd = d.length()
				var sheet: String = str(Db.character(game.npcs[id].look_id).get("sprite", id))
				best_tex = Db.character_frames(sheet).get_frame_texture(&"idle_down", 0)
		var tr: Array = game.player.track_at(tt)
		if not tr.is_empty():
			var dp: Vector2 = (tr[1] as Vector2) - w["pos"]
			if absf(dp.x) < 34.0 and dp.y > -30.0 and dp.y < 60.0 and dp.length() < bd:
				best_tex = game.player.sprite.sprite_frames.get_frame_texture(&"idle_down", 0)
		spr.visible = best_tex != null
		spr.texture = best_tex


## Отражение ближайшего человека, стоящего у зеркала (уменьшенная копия кадра).
func _update_mirrors() -> void:
	for m: Dictionary in _mirrors:
		var spr: Sprite2D = m["sprite"]
		var best: Node2D = null
		var bd: float = INF
		var people: Array = game.npcs.values()
		people.append(game.player)
		for n: Node2D in people:
			if not n.visible:
				continue
			var d: Vector2 = n.global_position - m["pos"]
			if absf(d.x) < MIRROR_REACH_X and d.y > 40.0 and d.y < 120.0 and d.length() < bd:
				bd = d.length()
				best = n
		var show: bool = best != null
		if best is NPCController and not hooks.has_reflection((best as NPCController).npc_id):
			show = false
		spr.visible = show
		if show:
			var cs: CharacterSprite = best.sprite if best is NPCController else (best as PlayerController).sprite
			spr.texture = cs.sprite_frames.get_frame_texture(cs.animation, cs.frame)
			spr.flip_h = not cs.flip_h


# --- Искажения на записях камер ------------------------------------------------------------
## Злодей обманывает камеру по-своему — только на записи, не вживую:
##   vampire — не виден, двери открываются сами; shadow — пропадает в тёмных участках;
##   mirror — на записи зеркальное отражение вместо человека; mimic — повторяет позу соседа
##   с задержкой; voice — голос «висит» в пустом углу кадра; sleeper — рядом с ним все спят;
##   puppeteer — нити к ближайшим людям; passenger_zero — помехи вместо фигуры;
##   werewolf — в лунное окно ("beast_window") огромная тень; witch — зелёное свечение.
var _cam_fx: Array = []   # временные узлы эффектов (нити, значки)


func _culprit() -> NPCController:
	return game.npcs.get(str(game.case_data.get("culprit", "")))


func camera_view(t: float) -> void:
	_clear_fx()
	var npc: NPCController = _culprit()
	if npc == null or not npc.visible:
		return
	var monster: String = str(game.case_data.get("monster", ""))
	var car: String = game.layout.carriage_at(npc.global_position.x)
	match monster:
		"vampire":
			npc.sprite.modulate.a = 0.0
			npc._shadow.visible = false
		"shadow":
			if _in_zone(car, t):
				npc.sprite.modulate.a = 0.0
				npc._shadow.visible = false
		"mirror":
			npc.sprite.flip_h = not npc.sprite.flip_h
			npc.sprite.modulate = Color(0.7, 0.85, 1.0, 0.8)
		"mimic":
			var other: NPCController = _nearest(npc, 260.0)
			if other:
				var st: Dictionary = game.investigation.timeline.state_at(other.npc_id, t - 0.03)
				npc.sprite.play_state("walk" if st["moving"] else "idle", str(st["facing"]))
		"voice":
			var x0: float = game.layout.offsets[car]
			_icon_at(Vector2(x0 + game.layout.widths[car] - (npc.global_position.x - x0), 96.0), "talk")
		"sleeper":
			for id: String in game.npcs:
				var o: NPCController = game.npcs[id]
				if o != npc and o.visible and o.global_position.distance_to(npc.global_position) < 120.0:
					_icon_at(o.global_position + Vector2(8, -44), "sleep")
		"puppeteer":
			for o: NPCController in _nearest_list(npc, 220.0, 2):
				var line := Line2D.new()
				line.width = 1.0
				line.default_color = Color(0.85, 0.8, 1.0, 0.55)
				line.add_point(npc.global_position + Vector2(0, -30))
				line.add_point(o.global_position + Vector2(0, -30))
				line.z_index = 40
				game.entities.add_child(line)
				_cam_fx.append(line)
		"passenger_zero":
			npc.sprite.modulate = Color(0.1, 0.1, 0.14, 0.35 + 0.2 * sin(t * 400.0))
			npc._shadow.visible = false
		"werewolf":
			if _beast(t):
				npc.sprite.modulate = Color(0.35, 0.28, 0.22)
				npc.sprite.scale = Vector2(1.3, 1.3)
		"witch":
			npc.sprite.modulate = Color(0.7, 1.0, 0.75)


func _beast(t: float) -> bool:
	var bw: Array = game.case_data.get("beast_window", [])
	return bw.size() == 2 and t >= Db.parse_time(str(bw[0])) and t < Db.parse_time(str(bw[1]))


## Подпись в списке «В кадре»: "" — человек на записи не виден.
func camera_label(id: String, t: float, name: String) -> String:
	if id != str(game.case_data.get("culprit", "")):
		return name
	var npc: NPCController = _culprit()
	match str(game.case_data.get("monster", "")):
		"vampire":
			return ""
		"shadow":
			return "" if npc and _in_zone(game.layout.carriage_at(npc.global_position.x), t) else name
		"mirror":
			return name + " (отражение)"
		"passenger_zero":
			return "помехи в форме человека"
		"werewolf":
			return "огромная тень" if _beast(t) else name
	return name


func camera_view_end() -> void:
	_clear_fx()
	var npc: NPCController = _culprit()
	if npc:
		npc.set_condition(npc.condition)
		npc._shadow.visible = not (npc.npc_id in game.case_data.get("no_shadow", []) or str(game.case_data.get("shadow_ghost", {}).get("npc", "")) == npc.npc_id)
	apply(game.investigation.clock)


func _clear_fx() -> void:
	for n in _cam_fx:
		if is_instance_valid(n):
			n.queue_free()
	_cam_fx.clear()
	var npc: NPCController = _culprit()
	if npc:
		npc.sprite.scale = Vector2.ONE
		npc.sprite.modulate = Color(0.82, 1.0, 0.78) if npc.condition == "sick" else Color.WHITE


func _icon_at(pos: Vector2, icon: String) -> void:
	var s := Sprite2D.new()
	s.texture = Db.texture("ui/bubble.png")
	s.global_position = pos
	s.z_index = 40
	var ic := Sprite2D.new()
	ic.texture = Db.texture("acts/%s.png" % icon)
	ic.position = Vector2(0, -1)
	s.add_child(ic)
	game.entities.add_child(s)
	_cam_fx.append(s)


func _nearest(npc: NPCController, radius: float) -> NPCController:
	var l: Array = _nearest_list(npc, radius, 1)
	return l[0] if not l.is_empty() else null


func _nearest_list(npc: NPCController, radius: float, n: int) -> Array:
	var others: Array = []
	for id: String in game.npcs:
		var o: NPCController = game.npcs[id]
		if o != npc and o.visible and o.global_position.distance_to(npc.global_position) < radius:
			others.append(o)
	others.sort_custom(func(a: NPCController, b: NPCController) -> bool: return a.global_position.distance_to(npc.global_position) < b.global_position.distance_to(npc.global_position))
	return others.slice(0, n)
