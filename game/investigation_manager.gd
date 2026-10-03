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
var case_seed: int = 0
## Время ведётся одними часами дела: дедлайн, расписание пассажиров и убийства не расходятся.
var deadline_minutes: float = 20.0
var _warned: Array = []


func setup(id: String, train_layout: TrainLayout, seed_value: int = -1, case_data: Dictionary = {}, level: String = "") -> void:
	case_id = id
	level_id = level
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


# --- часы ---------------------------------------------------------------------------------
func hold(reason: String) -> void:
	_holds[reason] = true


func release(reason: String) -> void:
	_holds.erase(reason)


func is_running() -> bool:
	return _holds.is_empty() and not ended


func elapsed() -> float:
	return clock - start_time


## Звёзды за раскрытие (правила — в data/campaign.json):
## 3 — за ≤12 мин, ≥3 ключевых улик и без ошибок; 2 — за ≤16 мин и не больше одной ошибки;
## 1 — раскрыто до дедлайна; 0 — поражение.
func compute_stars(solved: bool) -> int:
	if not solved:
		return 0
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
	_check_events()
	for pair: Array in murders.due(clock):
		murder_stage.emit(pair[0], pair[1])
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
	clue_added.emit(id)
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


## Игрок дошёл до места преступления: место и время записываются в журнал.
func discover_murder(m: Dictionary) -> void:
	var i: int = int(m["index"])
	if i in murders.discovered:
		return
	murders.discovered.append(i)
	give(str(m["scenario"]["scene_clue"]))
	murder_stage.emit(m, "discovered")


func deduce(a: String, b: String) -> String:
	return evidence.deduce(a, b, clock)


## Метка на записи камеры: какие улики видны на камере cam в момент t (±допуск).
func camera_clues_at(cam_id: String, t: float, tolerance_min: float = 10.0 / 60.0) -> Array[String]:
	var out: Array[String] = []
	var cam: Dictionary = layout.camera(cam_id)
	if cam.is_empty():
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
			var seen: bool = false
			for k in range(-2, 3):
				var tt: float = clampf(t + k * tolerance_min / 2.0, Db.parse_time(w[0]), Db.parse_time(w[1]))
				if cam["rect"].has_point(timeline.position_at(cc["npc"], tt)):
					seen = true
			if seen and not cc["id"] in out:
				out.append(cc["id"])
	return out


func mark_camera(cam_id: String, t: float) -> Array[String]:
	var added: Array[String] = []
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


func max_mistakes() -> int:
	return int(data.get("max_wrong", 2)) + (1 if ProgressionManager.equipment_level("badge") > 0 else 0)


## Задержать подозреваемого. clue_ids — улики-основания (до 3), monster_guess — тип монстра.
func accuse(suspect: String, clue_ids: Array, monster_guess: String = "") -> Dictionary:
	var result: Dictionary = {"suspect": suspect, "correct": suspect == data["culprit"],
		"key": key_clues_in(clue_ids), "clues": clue_ids, "monster_guess": monster_guess}
	if ended:
		return result
	if result["correct"]:
		result["strong"] = int(result["key"]) >= int(data.get("min_key_clues", 2))
		suspects.set_flag(suspect, "detained")
		accused.emit(result)
		return result
	mistakes += 1
	suspects.set_flag(suspect, "wrongly_accused")
	EconomyManager.add("reputation", -WRONG_REPUTATION)
	clock = minf(clock + WRONG_TIME_PENALTY, arrival_time)
	result["reaction"] = str(data.get("wrong_reactions", {}).get(suspect, "Я невиновен!"))
	result["case_failed"] = mistakes >= max_mistakes()
	accused.emit(result)
	if result["case_failed"]:
		finish("mistakes")
	elif clock >= arrival_time:
		finish("timeout")
	return result


## Дополнительная проверка: для каждой выбранной улики — касается ли она подозреваемого.
## Не говорит, монстр ли он: невиновные тоже лгут и скрывают секреты.
func verify(suspect: String, clue_ids: Array) -> Dictionary:
	if verifications_left <= 0 or ended:
		return {}
	verifications_left -= 1
	clock = minf(clock + VERIFY_TIME_COST, arrival_time)
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
		"key_total": _key_total()}
	result["stars"] = compute_stars(outcome == "solved")
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


## Сколько ключевых улик можно было найти: без улик убийств, которые не произошли
## (сценарии из пула, которые не выбраны, или убийства после раскрытия).
func _key_total() -> int:
	var n: int = 0
	for id: String in data.get("key_clues", []):
		var sid: String = murder_scenario_of_clue(id)
		if sid == "":
			n += 1
			continue
		for m: Dictionary in murders.killed():
			if m["id"] == sid:
				n += 1
	return n


## Id сценария убийства, к которому относится улика (по префиксу), или "".
func murder_scenario_of_clue(id: String) -> String:
	var scenarios: Dictionary = data.get("murders", {}).get("scenarios", {})
	for sid: String in scenarios:
		var pre: String = str(scenarios[sid].get("prefix", ""))
		if pre != "" and (id.begins_with(pre + "_") or id == "c_" + pre or id.begins_with("x_" + pre + "_")):
			return sid
	return ""


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


# --- сохранение ---------------------------------------------------------------------------
func snapshot() -> Dictionary:
	return {"case_id": case_id, "clock": clock, "evidence": evidence.serialize(), "suspects": suspects.serialize(),
		"dialogue": dialogue.serialize(), "mistakes": mistakes, "verifications_left": verifications_left,
		"escalated_at": escalated_at, "events_done": events_done, "camera_marks": camera_marks,
		"murders": murders.serialize(), "level": level_id, "seed": case_seed, "warned": _warned}


func restore(s: Dictionary) -> void:
	clock = float(s.get("clock", start_time))
	evidence.restore(s.get("evidence", {}))
	suspects.restore(s.get("suspects", {}))
	dialogue.restore(s.get("dialogue", {}))
	mistakes = int(s.get("mistakes", 0))
	verifications_left = int(s.get("verifications_left", verifications_left))
	camera_marks = int(s.get("camera_marks", 0))
	_warned = s.get("warned", []).duplicate()
	events_done = []
	for e in s.get("events_done", []):
		events_done.append(int(e))
	escalated_at = float(s.get("escalated_at", -1.0))
	murders.restore(s.get("murders", {}))
	if escalated_at >= 0.0:
		var esc: Dictionary = data["escalation"]
		timeline.override_from(esc["npc"], escalated_at, esc["spot"], esc["act"])
		murders.reapply_after(esc["npc"], escalated_at, timeline)
