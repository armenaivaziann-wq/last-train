class_name VillainHooks
extends RefCounted
## Способности злодеев во время игры. Всё рассчитывается заранее по seed попытки (после
## планирования убийств), поэтому одинаково воспроизводится после загрузки сохранения и
## совпадает с записями камер. Способности понятны через наблюдение и не наказывают случайно.
##   shapeshifter — в каждом туннеле меняет облик на другого пассажира;
##   mirror       — в зеркалах вагонов нет его отражения; заходит к зеркалу во время игры;
##   mimic        — лишний чемодан без бирки переползает на новое место в каждом туннеле;
##   shadow       — тень падает не туда и дёргается при мигании ламп;
##   voice        — ложные вызовы о помощи чужим голосом из пустых купе.

var inv: InvestigationManager
var villain: String = ""
var culprit: String = ""
var disguises: Array = []      # [[минута, персонаж]] — облик перевёртыша с момента
var mimic_path: Array = []     # [[минута, вагон, Vector2 локально]]
var calls: Array = []          # ложные вызовы


func plan(investigation: InvestigationManager, seed_value: int) -> void:
	inv = investigation
	villain = str(inv.data["monster"])
	culprit = str(inv.data["culprit"])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 9001
	match villain:
		"shapeshifter":
			_plan_shapeshifter(rng)
		"mirror":
			_plan_mirror()
		"mimic":
			_plan_mimic(rng)
		"voice":
			_plan_voice(rng)


## Погибнет ли персонаж к моменту t по плану убийств (облик мёртвого и голос мёртвого не берём).
func _dead_by(npc: String, t: float) -> bool:
	for m: Dictionary in inv.murders.murders:
		if m["victim"] == npc and float(m["t"]["kill"]) <= t:
			return true
	return false


func _tunnels() -> Array:
	return inv.murders.murders.map(func(m: Dictionary) -> float: return float(m["t"]["tunnel_in"]))


func _add_clue(id: String, type: String, title: String, text: String, points: Array, t: float, key: bool) -> void:
	var c := {"type": type, "title": title, "text": text, "points_to": points}
	if t >= 0.0:
		c["time"] = Db.format_time(t)
	inv.data["clues"][id] = c
	if key:
		inv.data["key_clues"].append(id)


func _camera_clue(id: String, npc: String, t: float, title: String, text: String, key: bool, before: float = 0.15, after: float = 0.4) -> void:
	var pos: Vector2 = inv.timeline.position_at(npc, t)
	var cam_id: String = ""
	var area: float = INF
	for cam in inv.layout.cameras:
		if (cam["rect"] as Rect2).has_point(pos) and (cam["rect"] as Rect2).get_area() < area:
			area = (cam["rect"] as Rect2).get_area()
			cam_id = str(cam["id"])
	if cam_id == "":
		return
	var rect: Rect2 = inv.layout.camera(cam_id)["rect"]
	for iv: Array in inv.timeline.presence(npc, rect, t - before, t + after, 1.0 / 120.0):
		if iv[1] - iv[0] > 0.05:
			inv.data["camera_clues"].append({"id": id, "camera": cam_id, "npc": npc,
				"windows": [[Db.format_time(iv[0] + 0.01, true), Db.format_time(iv[1] - 0.01, true)]]})
			_add_clue(id, "camera", title, text.replace("{cam}", "К" + cam_id.substr(3)), [npc], iv[0], key)
			return


# --- Перевёртыш ----------------------------------------------------------------------------
func _plan_shapeshifter(rng: RandomNumberGenerator) -> void:
	var pool: Array = inv.data["suspects"].filter(func(s: String) -> bool: return s != culprit)
	var cur: String = pool[rng.randi_range(0, pool.size() - 1)]
	disguises = [[-INF, cur]]
	var i: int = 0
	for t: float in _tunnels():
		var sw0: float = t + MurderDirector.TO_FLICKER
		var options: Array = pool.filter(func(s: String) -> bool: return s != cur and not _dead_by(s, sw0))
		if options.is_empty():
			options = pool.filter(func(s: String) -> bool: return s != cur)
		var nxt: String = options[rng.randi_range(0, options.size() - 1)]
		var sw: float = t + MurderDirector.TO_FLICKER
		disguises.append([sw, nxt])
		_camera_clue("h_shift_%d" % i, culprit, sw, "Запись: смена облика",
			"Камера {cam}: в туннеле %s пассажир в облике «%s» шагнул в темноту, а после вспышки там же стоял «%s»." % [
				Db.format_time(sw), Db.char_name(cur), Db.char_name(nxt)], true, 0.2, 0.5)
		cur = nxt
		i += 1


## Чей облик у перевёртыша в момент t (для живого мира и записей камер).
func disguise_at(t: float) -> String:
	var look: String = culprit
	for e: Array in disguises:
		if t >= float(e[0]):
			look = e[1]
	return look


## Как выглядит персонаж (для карточки и подписи): перевёртыш — чужим лицом.
func appearance(npc: String, t: float) -> String:
	if villain == "shapeshifter" and npc == culprit:
		return disguise_at(t)
	return npc


# --- Зеркальник ----------------------------------------------------------------------------
func _plan_mirror() -> void:
	# Во время игры он один раз задерживается у зеркала — отражения у него нет.
	var t: float = inv.start_time + 5.5
	for tt: float in _tunnels():
		if absf(tt - t) < 1.5:
			t = tt + 2.0
	inv.timeline.add_excursion(culprit, t - inv.timeline.travel_minutes(culprit, t - 0.6, "end_mirror") - 0.05, "end_mirror", "hide", t + 1.2)


func has_reflection(npc: String) -> bool:
	return not (villain == "mirror" and npc == culprit)


# --- Мимик --------------------------------------------------------------------------------
const MIMIC_SPOTS: Array = [["passenger", [618, 150]], ["passenger", [250, 150]], ["restaurant", [600, 150]],
	["passenger", [480, 150]], ["restaurant", [150, 150]], ["vestibule", [44, 120]]]


func _plan_mimic(rng: RandomNumberGenerator) -> void:
	var order: Array = range(MIMIC_SPOTS.size())
	for i in range(order.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp
	mimic_path = [[-INF, MIMIC_SPOTS[order[0]][0], MIMIC_SPOTS[order[0]][1]]]
	var k: int = 1
	for t: float in _tunnels():
		var s: Array = MIMIC_SPOTS[order[k % order.size()]]
		mimic_path.append([t + MurderDirector.TO_KILL, s[0], s[1]])
		k += 1
	inv.data["objects"]["obj_mimic_bag"] = {"title": "Чемодан без бирки", "kind": "item",
		"text": "Потёртый чемодан. Бирка без рейса и без владельца, на ручке — свежие царапины. Вчера на этом месте его не было.",
		"on_open": "g_tag", "hotspots": []}


## Где лишний чемодан в момент t: [вагон, локальная позиция].
func mimic_at(t: float) -> Array:
	var cur: Array = []
	for e: Array in mimic_path:
		if t >= float(e[0]):
			cur = [e[1], e[2]]
	return cur


# --- Голос за дверью ----------------------------------------------------------------------
func _plan_voice(rng: RandomNumberGenerator) -> void:
	var times: Array = [inv.start_time + 5.5, inv.start_time + 12.5]
	var tunnels: Array = _tunnels()
	for i in times.size():
		for tt: float in tunnels:
			if absf(tt - times[i]) < 1.5:
				times[i] = tt + 2.0
	var innocents: Array = inv.data["suspects"].filter(func(s: String) -> bool: return s != culprit)
	for i in times.size():
		var t: float = times[i]
		if t > inv.arrival_time - 2.0:
			continue
		# пустое купе (никого рядом в момент вызова)
		var bay: int = 1
		for k in [4, 2, 3, 1]:
			var x0: float = 110.0 + 112.0 * (k - 1)
			var empty: bool = true
			for npc in inv.timeline.npc_ids():
				var p: Vector2 = inv.timeline.position_at(npc, t)
				if p.x > x0 and p.x < x0 + 106 and p.y < 132:
					empty = false
			if empty:
				bay = k
				break
		var living: Array = innocents.filter(func(s: String) -> bool: return not _dead_by(s, t + 3.0))
		if living.is_empty():
			continue
		var owner: String = living[rng.randi_range(0, living.size() - 1)]
		var spot: String = "bay%d_c" % bay
		inv.timeline.add_excursion(culprit, t - inv.timeline.travel_minutes(culprit, t - 0.6, spot) - 0.05, spot, "hide", t + 0.6)
		var where: String = CaseGenerator.spot_place(str(inv.timeline.state_at(owner, t)["spot"]))
		var call := {"index": i, "t": t, "bay": bay, "owner": owner,
			"pos": Vector2(110.0 + 112.0 * (bay - 1) + 53.0, 100.0)}
		calls.append(call)
		var cid: String = "h_call_%d" % i
		_add_clue(cid, "testimony", "Ложный вызов №%d" % (i + 1), "В %s из пустого купе №%d звали на помощь голосом пассажира: %s." % [Db.format_time(t), bay, Db.char_name(owner)], [], t, false)
		var deny: String = "Это не я! В %s я был%s %s." % [Db.format_time(t), "а" if str(Db.character(owner).get("gender", "m")) == "f" else "", where]
		_add_clue("h_deny_%d" % i, "testimony", "%s не звал%s" % [Db.char_name(owner), "а" if str(Db.character(owner).get("gender", "m")) == "f" else ""], "%s: «%s»" % [Db.char_name(owner), deny], [owner], t, false)
		inv.data["dialogues"][owner]["topics"].append({"id": "h_call_%d" % i, "q": "Это вы звали на помощь из купе №%d?" % bay, "a": [deny], "gives": ["h_deny_%d" % i], "requires": [cid]})
		_camera_clue("h_callcam_%d" % i, culprit, t, "Запись: у пустого купе",
			"Камера {cam}: в %s у пустого купе №%d стоял человек %s." % [Db.format_time(t), bay, Db.character(culprit).get("look", "")], true, 0.3, 0.6)
		_add_clue("x_h_fake_%d" % i, "contradiction", "Голос подделан", "%s в момент вызова был в другом месте — кто-то подделал голос." % Db.char_name(owner), [], t, false)
		inv.data["deductions"].append({"result": "x_h_fake_%d" % i, "a": [cid], "b": ["h_deny_%d" % i]})
		_add_clue("x_h_voice_%d" % i, "contradiction", "Кто звал на самом деле", "У пустого купе в момент ложного вызова стоял один и тот же человек: %s." % Db.character(culprit).get("look", ""), [culprit], t, true)
		inv.data["deductions"].append({"result": "x_h_voice_%d" % i, "a": ["x_h_fake_%d" % i], "b": ["h_callcam_%d" % i]})
		inv.data["events"].append({"at": Db.format_time(t, true), "type": "false_call", "call": i,
			"text": "«Помогите!» — голос %s из купе №%d!" % [Db.char_name(owner), bay], "gives": [cid]})
