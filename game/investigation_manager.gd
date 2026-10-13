class_name InvestigationManager
extends Node
## Ход дела: игровые часы до станции, события между станциями, улики, выводы, обвинение,
## дополнительная проверка, итог и награды. Виновник и доказательства заданы данными дела
## заранее — решение никогда не выбирается случайно.

signal clock_changed(minute: float)
signal clue_added(clue_id: String)
signal case_event(event: Dictionary)
signal escalated(npc: String)
signal accused(result: Dictionary)
signal finished(result: Dictionary)
## Стадия события-убийства (tunnel_in, flicker, kill, tunnel_out, discovered).
signal murder_stage(murder: Dictionary, stage: String)
## Сработало сюжетное событие (визуальные и звуковые эффекты применяет Game).
signal story_event(event: Dictionary)
## Изменилось состояние пассажира (болен, спит, пропал...).
signal npc_state_changed(npc: String, state: String)

const WRONG_TIME_PENALTY: float = 2.0
const VERIFY_TIME_COST: float = 1.5
const WRONG_REPUTATION: int = 5

var case_id: String
var data: Dictionary
var layout: TrainLayout
var timeline: CaseTimeline
var evidence: EvidenceSystem
var suspects: SuspectManager
var dialogue: DialogueSystem
var murders: MurderDirector
var hooks: VillainHooks
var story: StoryDirector
## Состояния пассажиров: calm / scared / sick / asleep / missing / rescued / suspicious / hiding.
var npc_state: Dictionary = {}
## Сколько подсказок взял игрок (снижает итоговый рейтинг, но не мешает пройти дело).
var hints_used: int = 0
## Какие улики кому уже предъявлены: "npc|clue".
var presented: Array = []
## Верно ли названы мотив и способ в последнем обвинении (если дело их спрашивает).
var verdict_ok: bool = true
var hint_system: HintSystem
var opened: Array = []
## Доска передвижений: подозреваемый → {номер пятиминутки: вагон}, расставляет игрок.
var board: Dictionary = {}
const BOARD_FROM: float = 90.0   # 01:30
const BOARD_SLOT: float = 5.0
const BOARD_SLOTS: int = 6       # до 02:00
var story_dead: Dictionary = {}   # подозреваемый → минута, когда выбыл по сюжету (второе преступление)
## Решённые головоломки дела (id из data["puzzles"]).
var puzzles_solved: Array = []
var _hint_levels: Dictionary = {}   # цель подсказки → уже выданный уровень

var clock: float = 0.0
var start_time: float = 0.0
var arrival_time: float = 0.0
var history_start: float = 0.0
var seconds_per_minute: float = 30.0
## Сколько интерфейсов просят остановить часы (брифинг, журнал, диалог...).
var _holds: Dictionary = {}
var mistakes: int = 0
var verifications_left: int = 0
var escalated_at: float = -1.0
var events_done: Array = []
var camera_marks: int = 0
var ended: bool = false
var replay: bool = false
## Уровень кампании ("level_01"..., "daily" или "") и seed попытки (вариант дела, убийства).
var level_id: String = ""
## Профиль сложности (data/difficulty.json): цели, маркеры, подсказки, обыск, доказательства.
var profile: Dictionary = {}
var case_seed: int = 0
## Время ведётся одними часами дела: дедлайн, расписание пассажиров и убийства не расходятся.
var deadline_minutes: float = 20.0
var _warned: Array = []


func setup(id: String, train_layout: TrainLayout, seed_value: int = -1, case_data: Dictionary = {}, level: String = "") -> void:
	case_id = id
	level_id = level
	profile = Db.difficulty(level if level != "" else "level_01")
	case_seed = seed_value if seed_value >= 0 else randi() % 1000000
	# Копия: сценарии убийств дописывают в данные улики и объекты с конкретным временем.
	data = case_data if not case_data.is_empty() else Db.resolve_case(id, case_seed)
	layout = train_layout
	timeline = CaseTimeline.new(data, layout)
	evidence = EvidenceSystem.new(data)
	evidence.clue_added.connect(_on_clue_added)
	suspects = SuspectManager.new(PackedStringArray(data["suspects"]))
	dialogue = DialogueSystem.new(data["dialogues"])
	seconds_per_minute = float(data.get("seconds_per_minute", 30))
	history_start = Db.parse_time(data["history_start"])
	start_time = Db.parse_time(data["start"])
	# Дедлайн — 20 игровых минут с начала расследования (единый для всех дел).
	deadline_minutes = Db.deadline_minutes()
	arrival_time = start_time + deadline_minutes
	data["arrival"] = Db.format_time(arrival_time)
	clock = start_time
	verifications_left = int(data.get("verifications", 2))
	if ProgressionManager.has_carriage("surveillance"):
		verifications_left += 1
	replay = ProgressionManager.case_solved_before(id)
	murders = MurderDirector.new()
	murders.plan(data, layout, timeline, start_time, arrival_time, case_seed)
	hooks = VillainHooks.new()
	hooks.plan(self, case_seed)
	story = StoryDirector.new()
	story.plan(self)
	_plan_nights()
	_plan_hunts()
	hint_system = HintSystem.new(self)
	for npc: String in data.get("initial_states", {}):
		npc_state[npc] = str(data["initial_states"][npc])


# --- часы ---------------------------------------------------------------------------------
# --- ночь (свет выбило во всём поезде) ----------------------------------------------------
## Ночные отрезки: "nights": [{"at": "+6.5", "minutes": 3.0}] или по умолчанию два за дело.
## На записях камер в эти минуты все — силуэты (тёмные зоны во всех вагонах).
var nights: Array = []   # [[от, до]]


func _plan_nights() -> void:
	nights.clear()
	var defs: Array = data.get("nights", [{"at": "+6.5", "minutes": 3.0}, {"at": "+13.5", "minutes": 2.5}])
	for n: Dictionary in defs:
		var t0: float = start_time + float(str(n["at"]).trim_prefix("+"))
		var t1: float = minf(t0 + float(n.get("minutes", 2.0)), arrival_time - 0.5)
		if t1 > t0:
			nights.append([t0, t1])
			if not data.has("dark_zones"):
				data["dark_zones"] = []
			for cid in layout.carriage_ids:
				data["dark_zones"].append({"carriage": cid, "from": CaseBuilder.fmt(t0), "to": CaseBuilder.fmt(t1), "night": true})


# --- охота (злодей ищет героя в тёмном поезде) ------------------------------------------
## "hunts": [{"id", "night": 0 | "at": "+5", "minutes", "hunter", "speed", "sight", "title", "text"}].
## Охота привязана к ночи (по умолчанию) или к своему времени. Поимка — не смерть: −3 минуты
## и одна неподтверждённая улика выпадает из рук; поймали столько раз, сколько допускает
## профиль ("hunt_catches", по умолчанию 2) — поражение.
var hunts: Array = []          # [{id, from, to, def}]
var hunts_done: Array = []     # id закончившихся охот (ушёл или поймал)
var hunts_caught: int = 0
var hunts_dynamic: Array = []  # охоты, начатые сюжетом (ловушка), — для сохранения
const CATCH_COST: float = 3.0


func _plan_hunts() -> void:
	hunts.clear()
	var i: int = 0
	for h: Dictionary in data.get("hunts", []):
		var t0: float
		var t1: float
		if h.has("night"):
			var n: int = int(h["night"])
			if n >= nights.size():
				continue
			t0 = float(nights[n][0]) + float(h.get("delay", 0.3))
			t1 = float(nights[n][1])
		else:
			t0 = start_time + float(str(h["at"]).trim_prefix("+"))
			t1 = minf(t0 + float(h.get("minutes", 2.0)), arrival_time - 0.5)
		if t1 > t0:
			hunts.append({"id": str(h.get("id", "hunt_%d" % i)), "from": t0, "to": t1, "def": h})
		i += 1


## Охота, идущая в момент t (и ещё не закончившаяся), или {}.
func hunt_at(t: float) -> Dictionary:
	for h: Dictionary in hunts:
		if t >= float(h["from"]) and t < float(h["to"]) and not h["id"] in hunts_done:
			return h
	return {}


func end_hunt(id: String) -> void:
	if not id in hunts_done:
		hunts_done.append(id)


func max_catches() -> int:
	return int(profile.get("hunt_catches", 2))


## Охотник схватил героя. Возвращает id выпавшей улики ("" — выпасть было нечему).
func hunter_caught(id: String) -> String:
	hunts_caught += 1
	end_hunt(id)
	spend_time(CATCH_COST)
	var dropped: String = drop_clue()
	if hunts_caught >= max_catches() and not ended:
		finish("caught")
	return dropped


## Улики, которые можно «выронить»: вещественные и документы из предметов и багажа (их
## можно найти снова там же), не участвующие в сделанных выводах и не запускающие событий.
func droppable_clues() -> Array[String]:
	var out: Array[String] = []
	var sources: Dictionary = {}
	for oid: String in data.get("objects", {}):
		var o: Dictionary = data["objects"][oid]
		if o.has("on_open"):
			sources[str(o["on_open"])] = true
		for h: Dictionary in o.get("hotspots", []):
			sources[str(h["clue"])] = true
	for npc: String in data.get("luggage", {}):
		for it: Dictionary in data["luggage"][npc].get("items", []):
			if it.has("hotspot"):
				sources[str(it["hotspot"]["clue"])] = true
	var triggers: Dictionary = {}
	for ev: Dictionary in data.get("story_events", []):
		triggers[str(ev.get("trigger", {}).get("clue", ""))] = true
	for id: String in evidence.found:
		if not sources.has(id) or triggers.has(id) or is_proven(id):
			continue
		if evidence.clue(id).get("type") == "contradiction":
			continue
		out.append(id)
	return out


func drop_clue() -> String:
	var cand: Array[String] = droppable_clues()
	if cand.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = case_seed + hunts_caught * 7919
	var id: String = cand[rng.randi_range(0, cand.size() - 1)]
	evidence.remove(id)
	return id


# --- выбор и яд ---------------------------------------------------------------------------
## Сюжетное предложение (эффект "offer"): герою подают напиток — выпить или отказаться.
## Выбор необратим, сохраняется и меняет ход дела (разные улики, яд). Яд ("poison") —
## таймер в игровых минутах: не нашли противоядие (улика "antidote") — дело провалено.
var choices: Dictionary = {}   # id предложения → "accept" / "refuse"
var poison: Dictionary = {}    # {until, antidote, title}


func choose(offer: Dictionary, accept: bool) -> void:
	var id: String = str(offer["id"])
	if choices.has(id):
		return
	choices[id] = "accept" if accept else "refuse"
	_fire_story({"id": id + ("_accept" if accept else "_refuse"), "effects": offer.get("accept_effects" if accept else "refuse_effects", [])})


func poisoned() -> bool:
	return not poison.is_empty()


func poison_left() -> float:
	return maxf(0.0, float(poison.get("until", clock)) - clock) if poisoned() else 0.0


## Предложения, событие которых уже случилось, а выбор ещё не сделан (окно закрыли).
func pending_offers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev: Dictionary in data.get("story_events", []):
		if not story.happened(str(ev["id"])):
			continue
		for fx: Dictionary in ev.get("effects", []):
			if str(fx["type"]) == "offer" and not choices.has(str(fx["id"])):
				out.append(fx)
	return out


func night_at(t: float) -> bool:
	for n: Array in nights:
		if t >= float(n[0]) and t < float(n[1]):
			return true
	return false


func hold(reason: String) -> void:
	_holds[reason] = true


func release(reason: String) -> void:
	_holds.erase(reason)


func is_running() -> bool:
	return _holds.is_empty() and not ended


func elapsed() -> float:
	return clock - start_time


## Звёзды за раскрытие (правила — в data/campaign.json):
## Основное правило — оценка доски обвинения (score: 3/2/1, см. accuse). Без неё (старые вызовы):
## 3 — за ≤12 мин, ≥3 ключевых улик и без ошибок; 2 — за ≤16 мин и не больше одной ошибки;
## 1 — раскрыто до дедлайна; 0 — поражение.
func compute_stars(solved: bool, score: int = -1) -> int:
	if not solved:
		return 0
	# Оценка доски обвинения (score). Без неё (старые вызовы) — правила по времени.
	var base: int = score if score > 0 else _base_stars()
	if score <= 0 and not verdict_ok:
		base = mini(base, 2)
	if profile.get("hints_free", false):
		return maxi(1, base)
	# Подсказки снижают рейтинг: 1–2 подсказки −1 звезда, 3 и больше −2 (но не ниже 1).
	if hints_used >= 3:
		base -= 2
	elif hints_used >= 1:
		base -= 1
	return maxi(1, base)


func _base_stars() -> int:
	var rules: Dictionary = Db.campaign.get("stars", {})
	var three: Dictionary = rules.get("three", {"max_minutes": 12, "min_key_clues": 3, "max_mistakes": 0})
	var two: Dictionary = rules.get("two", {"max_minutes": 16, "max_mistakes": 1})
	var t: float = elapsed()
	if t <= float(three["max_minutes"]) + 0.0001 and evidence.key_found_count() >= int(three["min_key_clues"]) \
			and mistakes <= int(three["max_mistakes"]):
		return 3
	if t <= float(two["max_minutes"]) + 0.0001 and mistakes <= int(two["max_mistakes"]):
		return 2
	return 1


func minutes_left() -> float:
	return maxf(0.0, arrival_time - clock)


func _process(delta: float) -> void:
	if not is_running():
		return
	advance(delta / seconds_per_minute)


## Продвинуть часы дела на `minutes` (используется и тестами).
func advance(minutes: float) -> void:
	if ended:
		return
	clock = minf(clock + minutes, arrival_time)
	if poisoned() and clock >= float(poison["until"]):
		finish("poisoned")
		return
	_check_events()
	for pair: Array in murders.due(clock):
		murder_stage.emit(pair[0], pair[1])
	for e: Dictionary in story.due(clock):
		_fire_story(e)
	clock_changed.emit(clock)
	if clock >= arrival_time:
		finish("timeout")


func _check_events() -> void:
	for i in data.get("events", []).size():
		var ev: Dictionary = data["events"][i]
		if i in events_done:
			continue
		if clock >= Db.parse_time(ev["at"]):
			events_done.append(i)
			give_all(ev.get("gives", []))
			case_event.emit(ev)


# --- улики --------------------------------------------------------------------------------
func give(clue_id: String) -> bool:
	return evidence.add(clue_id, clock)


func give_all(ids: Array) -> Array[String]:
	var added: Array[String] = []
	for id in ids:
		if give(str(id)):
			added.append(str(id))
	return added


func _on_clue_added(id: String) -> void:
	var c: Dictionary = evidence.clue(id)
	if c.get("type") == "contradiction":
		Events.add_stat("deductions")
	else:
		Events.add_stat("clues")
	Events.clue_found.emit(id)
	if poisoned() and id == str(poison["antidote"]):
		poison = {}
	clue_added.emit(id)
	for e: Dictionary in story.on_clue(id):
		_fire_story(e)
	_check_escalation()


func _check_escalation() -> void:
	var esc: Dictionary = data.get("escalation", {})
	if esc.is_empty() or escalated_at >= 0.0:
		return
	if evidence.key_found_count() >= int(esc["key_clues"]):
		escalated_at = clock
		timeline.override_from(esc["npc"], clock, esc["spot"], esc["act"])
		murders.reapply_after(esc["npc"], clock, timeline)
		escalated.emit(esc["npc"])


# --- сюжетные события и состояния ----------------------------------------------------------
func _fire_story(e: Dictionary) -> void:
	for fx: Dictionary in e["effects"]:
		match str(fx["type"]):
			"state":
				set_state(str(fx["npc"]), str(fx["state"]))
			"give":
				give_all(fx.get("clues", []))
			"item":
				if not fx["id"] in story.spawned:
					story.spawned.append(fx["id"])
			"kill":
				# Второе преступление: подозреваемый выбывает, на месте — новая улика.
				set_state(str(fx["npc"]), "dead")
				story_dead[str(fx["npc"])] = clock
				var iid: String = str(fx.get("item", {}).get("id", ""))
				if iid != "" and not iid in story.spawned:
					story.spawned.append(iid)
			"hunt":
				# Сюжетная охота (ловушка): начинается сейчас и длится minutes.
				var h: Dictionary = {"id": str(fx["id"]), "from": clock, "to": minf(clock + float(fx.get("minutes", 1.5)), arrival_time - 0.2), "def": fx}
				hunts.append(h)
				hunts_dynamic.append(h)
			"time":
				spend_time(float(fx.get("minutes", 1.0)))
			"poison":
				poison = {"until": clock + float(fx.get("minutes", 5.0)), "antidote": str(fx["antidote"]),
					"title": str(fx.get("title", "Вы отравлены"))}
				if evidence.has(str(fx["antidote"])):
					poison = {}
			"remove_item":
				story.spawned.erase(fx["id"])
				if not story.spawned.has("-" + str(fx["id"])):
					story.spawned.append("-" + str(fx["id"]))
	story_event.emit(e)


func set_state(npc: String, state: String) -> void:
	npc_state[npc] = state
	npc_state_changed.emit(npc, state)


func state_of(npc: String) -> String:
	if murders.dead_at(npc, clock):
		return "dead"
	return str(npc_state.get(npc, "calm"))


## Человек спрятан (заперт, пропал) по сюжету — на записях камер его нет: "hidden": [{npc, from, to}].
func hidden_at(npc: String, t: float) -> bool:
	if story_dead.has(npc) and t >= float(story_dead[npc]):
		return true
	for h: Dictionary in data.get("hidden", []):
		if h["npc"] == npc and t >= Db.parse_time(str(h["from"])) and t < Db.parse_time(str(h["to"])):
			return true
	return false


## Контекст для диалогов: что уже произошло и в каком состоянии собеседник.
func dialogue_ctx(npc: String) -> Dictionary:
	return {"events": story.done, "state": state_of(npc), "wrong": suspects.flag(npc, "wrongly_accused")}


## Предъявить улику: реакция зависит от конкретной улики и уже известного.
func present(npc: String, clue_id: String) -> Dictionary:
	var r: Dictionary = dialogue.reaction(npc, clue_id, evidence, dialogue_ctx(npc))
	var key: String = npc + "|" + clue_id
	if not key in presented:
		presented.append(key)
		Events.add_stat("presented")
	if r.has("state"):
		set_state(npc, str(r["state"]))
	give_all(r.get("gives", []))
	return r


## Игрок дошёл до места преступления: место и время записываются в журнал.
func discover_murder(m: Dictionary) -> void:
	var i: int = int(m["index"])
	if i in murders.discovered:
		return
	murders.discovered.append(i)
	give(str(m["prefix"]) + "_scene")
	murder_stage.emit(m, "discovered")


func deduce(a: String, b: String) -> String:
	return evidence.deduce(a, b, clock)


## Метка на записи камеры: какие улики видны на камере cam в момент t (±допуск).
func camera_clues_at(cam_id: String, t: float, tolerance_min: float = 10.0 / 60.0) -> Array[String]:
	var out: Array[String] = []
	var cam: Dictionary = layout.camera(cam_id)
	if cam.is_empty():
		return out
	if not camera_gap(cam_id, t).is_empty():
		return out
	for cc: Dictionary in data.get("camera_clues", []):
		if cc["camera"] != cam_id:
			continue
		for w: Array in cc["windows"]:
			var t0: float = Db.parse_time(w[0]) - tolerance_min
			var t1: float = Db.parse_time(w[1]) + tolerance_min
			if t < t0 or t > t1:
				continue
			# NPC действительно в кадре рядом с отмеченным моментом
			var seen: bool = str(cc.get("npc", "")) == ""  # запись без человека (тень, свет, звук)
			for k in range(-2, 3):
				if seen:
					break
				var tt: float = clampf(t + k * tolerance_min / 2.0, Db.parse_time(w[0]), Db.parse_time(w[1]))
				if cam["rect"].has_point(timeline.position_at(cc["npc"], tt)):
					seen = true
			if seen and not cc["id"] in out:
				out.append(cc["id"])
	return out


## Камеры, которые есть в этом деле: вагоны без камер ("filmed" — список снимаемых вагонов)
## не дают ни миниатюры, ни записи.
func filmed_cameras() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var filmed: Array = data.get("filmed", [])
	for cam in layout.cameras:
		if filmed.is_empty() or str(cam.get("carriage", "")) in filmed:
			out.append(cam)
	return out


## Провалы записи камеры в момент t: {} — запись есть; иначе {kind, from, to, text, clue}.
##   tunnel  — пока поезд в туннеле, камера вагона с убийством показывает помехи;
##   damaged — повреждённый отрезок из данных дела ("damaged_records").
func camera_gap(cam_id: String, t: float) -> Dictionary:
	for g: Dictionary in camera_gaps(cam_id):
		if t >= float(g["from"]) and t < float(g["to"]):
			return g
	return {}


func camera_gaps(cam_id: String) -> Array:
	var out: Array = []
	var cam: Dictionary = layout.camera(cam_id)
	if cam.is_empty():
		return out
	if profile.get("blind_zones", true):
		for m: Dictionary in murders.murders:
			if str(m["victim"]) == "" or str(m.get("camera", "")) == "":
				continue
			if (cam["rect"] as Rect2).has_point(m["scene_pos"]):
				out.append({"kind": "tunnel", "from": float(m["t"]["tunnel_in"]), "to": float(m["t"]["tunnel_out"]),
					"text": "НЕТ СИГНАЛА — поезд в туннеле"})
	for d: Dictionary in data.get("damaged_records", []):
		if str(d["camera"]) == cam_id:
			out.append({"kind": "damaged", "from": Db.parse_time(str(d["from"])), "to": Db.parse_time(str(d["to"])),
				"text": "Запись повреждена %s–%s" % [str(d["from"]).substr(0, 5), str(d["to"]).substr(0, 5)], "clue": str(d.get("clue", ""))})
	return out


func mark_camera(cam_id: String, t: float) -> Array[String]:
	var added: Array[String] = []
	var gap: Dictionary = camera_gap(cam_id, t)
	if not gap.is_empty():
		# В провале записи видно только сам провал — это тоже улика (кто был у щитка?).
		if str(gap.get("clue", "")) != "" and give(str(gap["clue"])):
			added.append(str(gap["clue"]))
		return added
	for id in camera_clues_at(cam_id, t):
		if give(id):
			added.append(id)
	if not added.is_empty():
		camera_marks += 1
		Events.add_stat("camera_marks")
	return added


# --- обвинение ----------------------------------------------------------------------------
func key_clues_in(clue_ids: Array) -> int:
	var n: int = 0
	for id in clue_ids:
		if evidence.has(str(id)) and evidence.is_key(str(id)):
			n += 1
	return n


## После второй неверной попытки обвинения монстр сбегает (значок даёт ещё одну попытку).
func max_mistakes() -> int:
	return 2 + (1 if ProgressionManager.equipment_level("badge") > 0 else 0)


## Задержать подозреваемого. clue_ids — улики-основания (до 3), monster_guess — тип монстра.
## Следующая подсказка: для той же цели уровень растёт (намёк → связь → место).
## Каждая выданная подсказка учитывается в рейтинге.
func hints_left() -> int:
	return maxi(0, int(profile.get("hints", 99)) - hints_used)


func take_hint() -> Dictionary:
	if hints_left() <= 0:
		return {}
	var first: Dictionary = hint_system.hint(1)
	var target: String = str(first["target"])
	var lvl: int = mini(3, int(_hint_levels.get(target, 0)) + 1)
	_hint_levels[target] = lvl
	hints_used += 1
	Events.add_stat("hints")
	var h: Dictionary = hint_system.hint(lvl)
	h["level"] = lvl
	return h


## Обвинение: подозреваемый, основания (до 3 улик), тип злодея и — если дело спрашивает —
## мотив и способ (индексы вариантов из data["verdict"]).
func accuse(suspect: String, clue_ids: Array, monster_guess: String = "", motive: int = -1, method: int = -1) -> Dictionary:
	# Доска обвинения: КТО · КАК · КАКОЙ МОНСТР · 3 ключевые улики (ответы — в data["verdict"]).
	var vd: Dictionary = data.get("verdict", {})
	var result: Dictionary = {"suspect": suspect, "correct": suspect == data["culprit"],
		"key": key_clues_in(clue_ids), "clues": clue_ids, "monster_guess": monster_guess}
	result["how_ok"] = vd.is_empty() or method == int(vd.get("method", -2))
	result["motive_ok"] = vd.is_empty() or motive < 0 or motive == int(vd.get("motive", -2))
	result["method_ok"] = result["how_ok"]
	result["monster_ok"] = monster_guess == str(data["monster"])
	result["proof_ok"] = proven_against(suspect, clue_ids).size() >= 3
	verdict_ok = result["how_ok"]
	if ended:
		return result
	if result["correct"]:
		# Звёзды: всё верно — 3; верны «кто» и «монстр» — 2; только «кто» — 1.
		var score: int = 1
		if result["monster_ok"] and result["how_ok"] and result["proof_ok"]:
			score = 3
		elif result["monster_ok"]:
			score = 2
		result["score"] = score
		result["strong"] = result["proof_ok"]
		if score == 1:
			result["court"] = "Повезло, инспектор, но суд такое не примет."
		suspects.set_flag(suspect, "detained")
		accused.emit(result)
		return result
	mistakes += 1
	suspects.set_flag(suspect, "wrongly_accused")
	EconomyManager.add("reputation", -WRONG_REPUTATION)
	clock = minf(clock + wrong_penalty(), arrival_time)
	result["reaction"] = str(data.get("wrong_reactions", {}).get(suspect, "Я невиновен!"))
	result["why"] = explain_wrong(suspect, clue_ids)
	result["case_failed"] = mistakes >= max_mistakes()
	accused.emit(result)
	if result["case_failed"]:
		finish("mistakes")
	elif clock >= arrival_time:
		finish("timeout")
	return result


## Действие стоит игровых минут до станции (допрос, запись, проверка). События, которые
## наступают за это время, срабатывают как обычно.
func spend_time(minutes: float) -> void:
	if minutes > 0.0 and not ended:
		advance(minutes)


## Штраф времени за неверное обвинение (режим «Детектив» — вдвое больше).
func wrong_penalty() -> float:
	return WRONG_TIME_PENALTY * float(profile.get("wrong_mult", 1.0))


## Доказанные улики против подозреваемого: указывают на него и связаны выводом —
## это сам вывод из «Сопоставить» или улика, участвовавшая в найденном выводе.
## Разрозненные улики без вывода ключевыми не считаются.
func proven_against(suspect: String, clue_ids: Array) -> Array:
	return clue_ids.filter(func(id: Variant) -> bool:
		return evidence.has(str(id)) and suspect in evidence.clue(str(id)).get("points_to", []) and is_proven(str(id)))


func is_proven(id: String) -> bool:
	if evidence.clue(id).get("type") == "contradiction":
		return true
	for x: Dictionary in data.get("deductions", []):
		if evidence.has(str(x["result"])) and (id in x["a"] or id in x["b"]):
			return true
	return false


## Можно ли обыскать багаж пассажира: в сложных делах нужны основания против него.
func search_missing(owner: String) -> int:
	var need: int = int(profile.get("search_needs", 0))
	if data.get("luggage", {}).get(owner, {}).get("voluntary", false):
		return 0  # свидетель сам показывает вещи
	var have: int = evidence.found.filter(func(id: String) -> bool: return owner in evidence.clue(id).get("points_to", [])).size()
	return maxi(0, need - have)


## Почему обвинение ошибочно — без раскрытия виновника: какие основания не касаются
## обвинённого и опровергнуто ли то, из-за чего его подозревали.
func explain_wrong(suspect: String, clue_ids: Array) -> String:
	if str(profile.get("explain", "full")) == "short":
		return "Обвинение не подтвердилось. Перепроверьте алиби и противоречия."
	var f: bool = str(Db.character(suspect).get("gender", "m")) == "f"
	var him: String = "неё" if f else "него"
	var parts: PackedStringArray = []
	var weak: PackedStringArray = []
	for id in clue_ids:
		if not suspect in evidence.clue(str(id)).get("points_to", []):
			weak.append("«%s»" % evidence.clue(str(id)).get("title", id))
	if not weak.is_empty():
		parts.append("Эти основания не указывают на %s: %s." % [him, ", ".join(weak)])
	for x: Dictionary in data.get("deductions", []):
		for r: String in x.get("refutes", []):
			if suspect in data["clues"].get(r, {}).get("points_to", []) and evidence.has(r):
				if evidence.has(x["result"]):
					parts.append("Подозрение «%s» уже опровергнуто: «%s»." % [evidence.clue(r)["title"], evidence.clue(x["result"])["title"]])
				else:
					parts.append("Подозрение «%s» стоит проверить: сопоставьте его с записями камер и уликами." % evidence.clue(r)["title"])
	if parts.is_empty():
		parts.append("Ни одна найденная улика не связывает %s с преступлением напрямую. Ищите противоречия в показаниях." % ("её" if f else "его"))
	return " ".join(parts)


## Дополнительная проверка: для каждой выбранной улики — касается ли она подозреваемого.
## Не говорит, монстр ли он: невиновные тоже лгут и скрывают секреты.
func verify(suspect: String, clue_ids: Array) -> Dictionary:
	if verifications_left <= 0 or ended:
		return {}
	verifications_left -= 1
	spend_time(Db.action_cost(profile, "verify"))
	var out: Dictionary = {}
	for id in clue_ids:
		out[str(id)] = suspect in evidence.clue(str(id)).get("points_to", [])
	if clock >= arrival_time:
		finish("timeout")
	return out


## Завершить дело: outcome = "solved" / "timeout" / "mistakes".
func finish(outcome: String, accusation: Dictionary = {}) -> Dictionary:
	if ended:
		return {}
	ended = true
	var rw: Dictionary = data.get("rewards", {})
	var result: Dictionary = {"case_id": case_id, "outcome": outcome, "solved": outcome == "solved",
		"mistakes": mistakes, "clues": evidence.found.size(), "monster": data["monster"],
		"culprit": data["culprit"], "minutes_left": minutes_left(), "replay": replay,
		"elapsed": elapsed(), "key_found": evidence.key_found_count(), "level": level_id,
		"key_total": _key_total(), "hints_used": hints_used, "verdict_ok": verdict_ok}
	result["stars"] = compute_stars(outcome == "solved", int(accusation.get("score", -1)))
	# Монстр ушёл (дедлайн или вторая ошибка) — тратится билет (кроме дела дня и обучения).
	if outcome != "solved":
		result["ticket_spent"] = Tickets.spend_for_loss(level_id)
		result["tickets_left"] = Tickets.count()
	if accusation.has("court"):
		result["court"] = accusation["court"]
	var rewards: Dictionary = {"coins": 0, "crystals": 0, "reputation": 0}
	if outcome == "solved":
		var key: int = mini(3, int(accusation.get("key", 0)))
		var coins: float = float(rw.get("coins", 300)) + float(rw.get("per_key_clue", 40)) * key
		if minutes_left() >= 4.0:
			coins += 50
			result["time_bonus"] = true
		var mult: float = maxf(0.3, 1.0 - 0.3 * mistakes)
		if not accusation.get("strong", true):
			mult *= 0.7
		if replay:
			mult *= 0.4
		rewards["coins"] = int(round(coins * mult))
		rewards["crystals"] = int(rw.get("crystals", 10)) if not replay else 2
		if accusation.get("monster_guess", "") == data["monster"]:
			rewards["crystals"] += 5
			result["monster_guessed"] = true
		rewards["reputation"] = int(rw.get("reputation", 10)) if not replay else 2
		result["strong"] = accusation.get("strong", true)
		result["key"] = key
		result["first_catch"] = ProgressionManager.record_monster(data["monster"])
		Events.add_stat("solved")
		if mistakes == 0:
			Events.add_stat("solved_clean")
	else:
		rewards["coins"] = mini(120, 10 * evidence.found.size())
		rewards["reputation"] = -3
	# Звёзды кампании: награда только за новые звёзды, лучший результат сохраняется.
	if level_id != "":
		var rec: Dictionary = ProgressionManager.record_level(level_id, result["solved"], int(result["stars"]), elapsed())
		result["new_stars"] = rec["new_stars"]
		result["best_stars"] = rec["best"]
		result["unlocked_next"] = rec["unlocked_next"]
		var sr: Dictionary = Db.campaign.get("star_reward", {"coins": 40, "crystals": 5})
		rewards["coins"] += int(sr["coins"]) * int(rec["new_stars"])
		rewards["crystals"] += int(sr["crystals"]) * int(rec["new_stars"])
		if level_id == "daily" and result["solved"] and int(rec["new_stars"]) > 0 and int(result["stars"]) == int(rec["new_stars"]):
			var dr: Dictionary = Db.campaign.get("daily", {}).get("rewards", {})
			rewards["coins"] += int(dr.get("coins", 0))
			rewards["crystals"] += int(dr.get("crystals", 0))
	if result["solved"]:
		ProgressionManager.record_disguise(str(data["monster"]), str(data["culprit"]))
		if evidence.key_found_count() >= _key_total() and _key_total() > 0:
			Events.add_stat("all_key_clues")
	result["rewards"] = rewards
	EconomyManager.grant(rewards)
	ProgressionManager.add_archive({"case_id": case_id, "title": data["title"], "solved": result["solved"],
		"outcome": outcome, "mistakes": mistakes, "clues": evidence.found.size(),
		"date": Time.get_date_string_from_system(), "coins": rewards["coins"]})
	SaveManager.clear_case_progress()
	finished.emit(result)
	Events.case_finished.emit(result)
	return result


## Сколько ключевых улик можно было найти: улики убийств считаются, только если убийство
## уже произошло (жертвы и улики событий создаются вместе с ними).
func _key_total() -> int:
	var n: int = 0
	for id: String in data.get("key_clues", []):
		var m: Dictionary = murders.murder_of_clue(id)
		if m.is_empty() or murders.stage_done(m, "kill"):
			n += 1
	return n


## Относится ли улика к событию-убийству ("" — нет; иначе id события).
func murder_scenario_of_clue(id: String) -> String:
	var m: Dictionary = murders.murder_of_clue(id)
	return "" if m.is_empty() else str(m["id"])


func check_deadline_warnings() -> int:
	## Возвращает порог (10/5/1 мин), который только что пройден, или 0.
	var left: float = minutes_left()
	for th: int in [10, 5, 1]:
		if left <= th and not th in _warned:
			_warned.append(th)
			for smaller: int in [10, 5, 1]:
				if smaller > th and not smaller in _warned:
					_warned.append(smaller)
			return th
	return 0


# --- головоломки --------------------------------------------------------------------------
## Головоломка из данных дела: {type, title, intro, ..., reward: [улики], wrong_cost}.
## Решение выводится из найденных улик (код, порядок), ошибка стоит игровых минут.
func puzzle(id: String) -> Dictionary:
	return data.get("puzzles", {}).get(id, {})


func puzzle_solved(id: String) -> bool:
	return id in puzzles_solved


func solve_puzzle(id: String, skipped: bool = false) -> void:
	if id in puzzles_solved or puzzle(id).is_empty():
		return
	puzzles_solved.append(id)
	if skipped:
		hints_used += 1
	give_all(puzzle(id).get("reward", []))


func puzzle_wrong(id: String) -> void:
	spend_time(float(puzzle(id).get("wrong_cost", 0.5)) * float(profile.get("time_cost_mult", 1.0)))


## Предмет мира под присмотром ("guard": "npc" в данных объекта): пока хозяин рядом
## с предметом, его не дадут осмотреть.
func object_guarded(oid: String) -> bool:
	var g: String = str(data.get("objects", {}).get(oid, {}).get("guard", ""))
	if g == "":
		return false
	for it: Dictionary in data.get("extra_items", []):
		if it["id"] == oid:
			var pos := Vector2(layout.offsets[it["carriage"]] + float(it["pos"][0]), float(it["pos"][1]))
			return timeline.position_at(g, clock).distance_to(pos) < 90.0
	return false


## Предмет показывает улику, только когда рядом нужный человек ("needs_near": "npc"),
## например зеркало — отражение того, кто перед ним стоит.
func object_waiting(oid: String) -> bool:
	var n: String = str(data.get("objects", {}).get(oid, {}).get("needs_near", ""))
	if n == "":
		return false
	for it: Dictionary in data.get("extra_items", []):
		if it["id"] == oid:
			var pos := Vector2(layout.offsets[it["carriage"]] + float(it["pos"][0]), float(it["pos"][1]))
			return timeline.position_at(n, clock).distance_to(pos) > 110.0
	return false


## Хозяин сидит рядом с вещами («guarded» в данных багажа) — обыскать нельзя, пока он не отойдёт.
func luggage_guarded(owner: String) -> bool:
	if not data.get("luggage", {}).get(owner, {}).get("guarded", false):
		return false
	for lw: Dictionary in data.get("luggage_world", []):
		if lw["owner"] == owner and layout.slots.has(lw["slot"]):
			return timeline.position_at(owner, clock).distance_to(layout.slots[lw["slot"]]) < 90.0
	return false


# --- доска передвижений ------------------------------------------------------------------
func board_set(npc: String, slot: int, carriage: String) -> void:
	if not board.has(npc):
		board[npc] = {}
	if carriage == "":
		board[npc].erase(str(slot))
	else:
		board[npc][str(slot)] = carriage


## Проверка доски. Для каждого найденного показания-алиби ("alibi": {npc, from, to, carriage})
## смотрим пятиминутки, которые игрок заполнил в этом промежутке: если игрок поставил человека
## в другой вагон и это совпадает с тем, что было на самом деле, — алиби развалилось:
## выдаётся вывод, опровергающий показание. Неверная расстановка ничего не раскрывает.
## Возвращает {conflicts: {npc: текст}, empty: [npc], gained: [id выводов]}.
func check_board() -> Dictionary:
	var out: Dictionary = {"conflicts": {}, "empty": [], "gained": [], "unproven": {}}
	for id in evidence.found:
		var al: Dictionary = evidence.clue(id).get("alibi", {})
		if al.is_empty():
			continue
		var npc: String = str(al["npc"])
		var f: float = Db.parse_time(str(al["from"]))
		var to: float = Db.parse_time(str(al["to"]))
		var cells: Dictionary = board.get(npc, {})
		var any_set: bool = false
		for k in BOARD_SLOTS:
			var s0: float = BOARD_FROM + k * BOARD_SLOT
			var s1: float = s0 + BOARD_SLOT
			if s1 <= f or s0 >= to:
				continue
			if not cells.has(str(k)):
				continue
			any_set = true
			var placed: String = str(cells[str(k)])
			if placed == str(al["carriage"]):
				continue
			# Был ли человек в поставленном вагоне в эту пятиминутку (хоть раз за промежуток)?
			var truth: bool = false
			var tt: float = maxf(s0, f)
			while tt < minf(s1, to):
				if layout.carriage_at(timeline.position_at(npc, tt).x) == placed:
					truth = true
					break
				tt += 0.1
			if truth:
				out["conflicts"][npc] = "%s: по показаниям — %s с %s до %s, а по вашей доске в %s — %s." % [
					Db.char_name(npc), layout.carriage_name(str(al["carriage"])).to_lower(), str(al["from"]).substr(0, 5), str(al["to"]).substr(0, 5),
					Db.format_time(s0), layout.carriage_name(placed).to_lower()]
				for x: Dictionary in data.get("deductions", []):
					if id in x.get("refutes", []) and not evidence.has(str(x["result"])):
						if evidence.add(str(x["result"]), clock):
							out["gained"].append(str(x["result"]))
							for r: String in x.get("refutes", []):
								evidence.statuses[r] = "refuted"
			else:
				out["unproven"][npc] = "%s: расстановка расходится с показаниями, но подтвердить её пока нечем." % Db.char_name(npc)
		if not any_set:
			out["empty"].append(npc)
	return out


# --- что осмотрено ------------------------------------------------------------------------
## Объект или багаж открыт игроком (id объекта или "luggage_<владелец>").
func mark_opened(id: String) -> void:
	if not id in opened:
		opened.append(id)


## Улики, которые можно получить из объекта мира или багажа.
func clues_of(id: String) -> Array:
	var out: Array = []
	if id.begins_with("luggage_"):
		for it: Dictionary in data.get("luggage", {}).get(id.substr(8), {}).get("items", []):
			if it.has("requires_upgrade") and ProgressionManager.equipment_level(str(it["requires_upgrade"])) < 1:
				continue
			if it.has("on_open"):
				out.append(str(it["on_open"]))
			if it.has("hotspot"):
				out.append(str(it["hotspot"]["clue"]))
		return out
	var o: Dictionary = data.get("objects", {}).get(id, {})
	if o.has("on_open"):
		out.append(str(o["on_open"]))
	for h: Dictionary in o.get("hotspots", []):
		out.append(str(h["clue"]))
	return out


## Состояние для маркера: "new" — не открыт, "partial" — открыт, но улики остались, "done".
func inspect_state(id: String) -> String:
	var rest: Array = clues_of(id).filter(func(c: String) -> bool: return not evidence.has(c))
	if not id in opened:
		return "done" if rest.is_empty() and not clues_of(id).is_empty() else "new"
	return "done" if rest.is_empty() else "partial"


# --- сохранение ---------------------------------------------------------------------------
func snapshot() -> Dictionary:
	return {"case_id": case_id, "clock": clock, "evidence": evidence.serialize(), "suspects": suspects.serialize(),
		"dialogue": dialogue.serialize(), "mistakes": mistakes, "verifications_left": verifications_left,
		"escalated_at": escalated_at, "events_done": events_done, "camera_marks": camera_marks,
		"murders": murders.serialize(), "level": level_id, "seed": case_seed, "warned": _warned,
		"story": story.serialize(), "npc_state": npc_state, "hints_used": hints_used, "presented": presented,
		"hint_levels": _hint_levels, "opened": opened, "story_dead": story_dead, "board": board, "puzzles": puzzles_solved.duplicate(),
		"hunts_done": hunts_done.duplicate(), "hunts_caught": hunts_caught,
		"choices": choices.duplicate(), "poison": poison.duplicate(), "hunts_dynamic": hunts_dynamic.duplicate(true)}


func restore(s: Dictionary) -> void:
	clock = float(s.get("clock", start_time))
	evidence.restore(s.get("evidence", {}))
	suspects.restore(s.get("suspects", {}))
	dialogue.restore(s.get("dialogue", {}))
	mistakes = int(s.get("mistakes", 0))
	verifications_left = int(s.get("verifications_left", verifications_left))
	camera_marks = int(s.get("camera_marks", 0))
	_warned = s.get("warned", []).duplicate()
	story.restore(s.get("story", {}))
	npc_state = s.get("npc_state", npc_state).duplicate()
	hints_used = int(s.get("hints_used", 0))
	_hint_levels = s.get("hint_levels", {}).duplicate()
	opened = s.get("opened", []).duplicate()
	story_dead = s.get("story_dead", {}).duplicate()
	board = s.get("board", {}).duplicate(true)
	puzzles_solved = s.get("puzzles", []).duplicate()
	hunts_done = s.get("hunts_done", []).duplicate()
	hunts_caught = int(s.get("hunts_caught", 0))
	choices = s.get("choices", {}).duplicate()
	for h: Dictionary in s.get("hunts_dynamic", []):
		if not hunts.any(func(x: Dictionary) -> bool: return x["id"] == h["id"]):
			hunts.append(h)
			hunts_dynamic.append(h)
	poison = s.get("poison", {}).duplicate()
	presented = s.get("presented", []).duplicate()
	events_done = []
	for e in s.get("events_done", []):
		events_done.append(int(e))
	escalated_at = float(s.get("escalated_at", -1.0))
	murders.restore(s.get("murders", {}))
	if escalated_at >= 0.0:
		var esc: Dictionary = data["escalation"]
		timeline.override_from(esc["npc"], escalated_at, esc["spot"], esc["act"])
		murders.reapply_after(esc["npc"], escalated_at, timeline)
