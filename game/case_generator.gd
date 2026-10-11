class_name CaseGenerator
extends RefCounted
## Генератор дел кампании (уровни 2–10 и «Дело дня»). Из базового состава
## (data/cases/_base.json) и описания злодея собирает согласованное дело:
##   • по seed выбирает виновника, место и время происшествия (несколько вариантов на дело);
##   • прокладывает вылазку виновника в хронологии — записи камер и показания берутся из неё;
##   • добавляет честные улики разных типов: запись камеры, свидетеля, ложное алиби, след,
##     приметы в документах, а также особые улики способности злодея;
##   • все ключевые улики доступны (места улик — только в играбельных вагонах).
## Улики времени игры (смена облика в туннеле, ложные вызовы...) добавляет VillainHooks.

## Места происшествия: точка вылазки, описание, вагон, позиция следа на полу (локальная).
const CRIME_SPOTS: Dictionary = {
	"svc_shelf": {"name": "в служебном купе", "short": "служебное купе", "carriage": "passenger", "trace": [78, 124],
		"incident": "из служебного купе пропала связка ключей от всех вагонов"},
	"end_mirror": {"name": "у стеллажа в конце пассажирского вагона", "short": "стеллаж с багажом", "carriage": "passenger", "trace": [590, 130],
		"incident": "кто-то рылся в чужих чемоданах на стеллаже"},
	"vest_window": {"name": "в тамбуре", "short": "тамбур", "carriage": "vestibule", "trace": [30, 104],
		"incident": "в тамбуре кто-то сорвал пломбу со стоп-крана"},
	"rest_trash": {"name": "у кофейного автомата в ресторане", "short": "кофейный автомат", "carriage": "restaurant", "trace": [560, 146],
		"incident": "у кофейного автомата кто-то подсыпал порошок в сахарницу"},
}
const CRIME_TIMES: Array = ["01:39", "01:41:30", "01:44", "01:46:30"]
const STATIONS: Array = ["Долина", "Каменный мост", "Озёрная", "Сосновый бор", "Старая шахта", "Эхо", "Лунный разъезд", "Снежный перевал", "Огни"]
const EXCURSION_STAY: float = 1.6

var d: Dictionary
var layout: TrainLayout
var timeline: CaseTimeline
var rng := RandomNumberGenerator.new()
var villain_id: String
var villain: Dictionary
var culprit: String
var crime_spot: String
var crime_t: float
var crime_cam: String
var witness: String = ""
var key_clues: Array = []


static func generate(ref: String, seed_value: int) -> Dictionary:
	var g := CaseGenerator.new()
	return g._build(ref, seed_value)


# --- вспомогательное ---------------------------------------------------------------------
func _ch(id: String) -> Dictionary:
	return Db.character(id)


func _g(id: String, m: String, f: String) -> String:
	return f if str(_ch(id).get("gender", "m")) == "f" else m


func _fmt(t: float) -> String:
	var total: float = t * 60.0
	var h: int = int(total / 3600.0)
	var mi: int = int(fmod(total, 3600.0) / 60.0)
	var s: float = fmod(total, 60.0)
	return "%02d:%02d:%05.2f" % [h, mi, s]


func clue(id: String, type: String, title: String, text: String, points: Array = [], time: float = -1.0, key: bool = false) -> void:
	var c := {"type": type, "title": title, "text": text, "points_to": points}
	if time >= 0.0:
		c["time"] = Db.format_time(time)
	d["clues"][id] = c
	if key and not id in key_clues:
		key_clues.append(id)


func topic(npc: String, tid: String, q: String, a: Array, gives: Array = [], requires: Array = [], requires_any: Array = []) -> void:
	var t := {"id": tid, "q": q, "a": a}
	if not gives.is_empty():
		t["gives"] = gives
	if not requires.is_empty():
		t["requires"] = requires
	if not requires_any.is_empty():
		t["requires_any"] = requires_any
	d["dialogues"][npc]["topics"].append(t)


func deduction(result: String, a: Array, b: Array, refutes: Array = [], confirms: Array = []) -> void:
	var x := {"result": result, "a": a, "b": b}
	if not refutes.is_empty():
		x["refutes"] = refutes
	if not confirms.is_empty():
		x["confirms"] = confirms
	d["deductions"].append(x)


## Предмет-улика на полу (появляется в мире как интерактивный объект).
func floor_item(id: String, carriage: String, pos: Array, sprite: String, label: String, title: String, text: String, clue_id: String) -> void:
	d["extra_items"].append({"id": id, "carriage": carriage, "pos": pos, "sprite": sprite, "label": label})
	d["objects"][id] = {"title": title, "kind": "item", "text": text, "on_open": clue_id, "hotspots": []}


## Ближайшая свободная точка пола (не в мебели и не в стене) — улика всегда доступна.
func free_floor(carriage: String, local: Vector2) -> Array:
	var cols: Array = Db.layout(carriage)["colliders"]
	for r in range(0, 80, 6):
		for dir: Vector2 in [Vector2.ZERO, Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var p: Vector2 = local + dir * r
			if p.y < 66.0 or p.y > 186.0:
				continue
			var blocked: bool = false
			for c: Array in cols:
				if Rect2(float(c[0]) - 4, float(c[1]) - 4, float(c[2]) + 8, float(c[3]) + 8).has_point(p):
					blocked = true
					break
			if not blocked:
				return [round(p.x), round(p.y)]
	return [round(local.x), 160]


func doc_hotspot(npc: String, label: String, text: String, clue_id: String) -> void:
	d["documents"][npc]["hotspots"].append({"id": clue_id, "label": label, "text": text, "clue": clue_id})


func luggage_hotspot(npc: String, name: String, text: String, label: String, detail: String, clue_id: String) -> void:
	d["luggage"][npc]["items"].append({"name": name, "text": text, "hotspot": {"label": label, "text": detail, "clue": clue_id}})


## Вылазка в хронологии (переписывается в расписание дела).
func excursion(npc: String, at: float, spot: String, act: String, stay: float) -> void:
	var depart: float = at - timeline.travel_minutes(npc, at - 0.6, spot) - 0.05
	timeline.add_excursion(npc, depart, spot, act, at + stay)


## Камера, в чей кадр попадает точка (самая «узкая» — так запись нагляднее).
func camera_for(pos: Vector2) -> String:
	var best: String = ""
	var area: float = INF
	for cam in layout.cameras:
		var r: Rect2 = cam["rect"]
		if r.has_point(pos) and r.get_area() < area:
			area = r.get_area()
			best = str(cam["id"])
	return best


## Окно записи: когда npc в кадре камеры рядом с моментом t (внутри реального присутствия).
func camera_window(cam: String, npc: String, t: float, before: float = 1.0, after: float = 2.0) -> Array:
	var rect: Rect2 = layout.camera(cam)["rect"]
	for iv: Array in timeline.presence(npc, rect, t - before, t + after, 1.0 / 120.0):
		if iv[0] <= t + after and iv[1] >= t - before:
			var a: float = iv[0] + 0.02
			var b: float = iv[1] - 0.02
			if b > a:
				return [_fmt(a), _fmt(b)]
	return []


func camera_clue(id: String, cam: String, npc: String, t: float, title: String, text: String, points: Array, key: bool, before: float = 1.0, after: float = 2.0) -> bool:
	var w: Array = camera_window(cam, npc, t, before, after)
	if w.is_empty():
		return false
	d["camera_clues"].append({"id": id, "camera": cam, "npc": npc, "windows": [w]})
	clue(id, "camera", title, text, points, Db.parse_time(w[0]), key)
	return true


## Где был человек в момент t — для правдивых показаний.
func place(npc: String, t: float) -> String:
	var s: Dictionary = timeline.state_at(npc, t)
	var p: String = spot_place(str(s["spot"]))
	return ("шёл " + p) if s["moving"] else p


## Куда ведут следы: «в вагон-ресторан, к 3-му столику», «в тамбур»...
static func spot_direction(spot: String) -> String:
	if spot.begins_with("svc_"):
		return "в служебное купе"
	if spot.begins_with("bay"):
		return "в купе №%s" % spot.substr(3, 1)
	if spot.begins_with("corr_win"):
		return "к окну в коридоре"
	if spot.begins_with("end_"):
		return "в конец пассажирского вагона"
	if spot.begins_with("vest_"):
		return "в тамбур"
	if spot.begins_with("rb"):
		return "в вагон-ресторан, к %s-му столику" % spot.substr(2, 1)
	if spot in ["rest_coffee", "rest_trash"]:
		return "к кофейному автомату"
	if spot.begins_with("bar_"):
		return "к барной стойке"
	if spot == "piano":
		return "к пианино в ресторане"
	return "в вагон-ресторан"


static func spot_place(spot: String) -> String:
	if spot.begins_with("svc_"):
		return "в служебном купе"
	if spot.begins_with("bay"):
		return "в купе №%s" % spot.substr(3, 1)
	if spot.begins_with("corr_win"):
		return "у окна в коридоре"
	if spot.begins_with("end_"):
		return "в конце пассажирского вагона"
	if spot.begins_with("vest_"):
		return "в тамбуре"
	if spot.begins_with("rb"):
		return "в ресторане, за %s-м столиком" % spot.substr(2, 1)
	if spot in ["rest_coffee", "rest_trash"]:
		return "у кофейного автомата"
	if spot.begins_with("bar_"):
		return "у барной стойки"
	if spot == "piano":
		return "у пианино в ресторане"
	return "в вагоне-ресторане"


func home_spot(npc: String) -> String:
	return str(d["schedules"][npc][0][1])


func near_spot(pos: Vector2, exclude: Array) -> String:
	var best: String = ""
	var bd: float = INF
	for sid: String in layout.spots:
		if sid in exclude:
			continue
		var dist: float = (layout.spots[sid]["pos"] as Vector2).distance_to(pos)
		if dist >= 14.0 and dist < bd and layout.spots[sid]["pose"] == "stand":
			bd = dist
			best = sid
	return best


# --- сборка дела -------------------------------------------------------------------------
func _build(ref: String, seed_value: int) -> Dictionary:
	rng.seed = seed_value
	var lvl: Dictionary = Db.level(ref)
	villain_id = str(lvl.get("villain", ref))
	villain = Db.monster(villain_id)
	d = Db.case_data("_base").duplicate(true)
	d["id"] = "gen:" + ref
	d["monster"] = villain_id
	d["title"] = str(lvl.get("title", villain.get("name", "Дело дня")))
	d["station_from"] = str(lvl.get("from", STATIONS[rng.randi_range(0, STATIONS.size() - 1)]))
	d["station_to"] = str(lvl.get("to", STATIONS[rng.randi_range(0, STATIONS.size() - 1)]))
	d["route"] = ref
	d["extra_items"] = []
	d["variant"] = "seed %d" % seed_value
	layout = TrainLayout.build(PackedStringArray(d["carriages"]))
	timeline = CaseTimeline.new(d, layout)

	_pick_culprit()
	_pick_crime()
	excursion(culprit, crime_t, crime_spot, "hide_evidence", EXCURSION_STAY)
	if has_method("_villain_" + villain_id + "_schedule"):
		call("_villain_" + villain_id + "_schedule")
	_write_schedules()
	_generic_clues()
	if has_method("_villain_" + villain_id):
		call("_villain_" + villain_id)
	_murders()
	_brief_and_truth()
	d["culprit"] = culprit
	d["key_clues"] = key_clues
	d["escalation"] = {"npc": culprit, "key_clues": 3, "spot": "vest_door", "act": "nervous",
		"barks": ["Скорее бы станция...", "Душно тут.", "Не смотрите на меня так."]}
	return d


func _pick_culprit() -> void:
	var fixed: String = {"conductor_double": "agata", "passenger_zero": "tikhon"}.get(villain_id, "")
	if fixed != "":
		culprit = fixed
		return
	var pool: Array = []
	for s: String in d["suspects"]:
		if s != "agata":
			pool.append(s)
	culprit = pool[rng.randi_range(0, pool.size() - 1)]


func _pick_crime() -> void:
	var spots: Array = CRIME_SPOTS.keys()
	if villain_id == "mirror":
		spots.erase("end_mirror")
	crime_spot = spots[rng.randi_range(0, spots.size() - 1)]
	crime_t = Db.parse_time(CRIME_TIMES[rng.randi_range(0, CRIME_TIMES.size() - 1)])


func _write_schedules() -> void:
	for npc in timeline.npc_ids():
		var out: Array = []
		for e: Array in timeline.entries(npc):
			out.append([_fmt(e[0]), e[1], e[2]])
		d["schedules"][npc] = out


func _spot_pos(spot: String) -> Vector2:
	return layout.spots[spot]["pos"]


# --- общие честные улики -----------------------------------------------------------------
func _generic_clues() -> void:
	var cs: Dictionary = CRIME_SPOTS[crime_spot]
	var c_name: String = Db.char_name(culprit)
	var look: String = str(_ch(culprit)["look"])
	crime_cam = camera_for(_spot_pos(crime_spot))
	var tt: String = Db.format_time(crime_t)
	# Происшествие (из брифинга)
	clue("g_incident", "testimony", "Происшествие", "Около %s %s." % [tt, cs["incident"]], [], crime_t)
	# Документы каждого подозреваемого: приметы, следы обуви, подпись
	for s: String in d["suspects"]:
		var ch: Dictionary = _ch(s)
		clue("d_look_" + s, "document", "Приметы: " + Db.char_name(s),
			"%s: %s; %s; подпись: %s." % [Db.char_name(s), ch.get("look", ""), ch.get("steps", ""), ch.get("signature", "")], [s])
		var doc: Dictionary = d["documents"][s]
		if not doc.has("gives"):
			doc["gives"] = []
		doc["gives"].append("d_look_" + s)
		if doc.has("fields"):
			doc["fields"].append(["Приметы", str(ch.get("look", ""))])
		elif doc.has("id"):
			doc["id"].append(["Приметы", str(ch.get("look", ""))])
	# Запись камеры: виновник на месте происшествия
	var cam_text: String = "Камера: около %s %s был человек %s." % [tt, cs["name"], look]
	if villain_id == "black_cloak":
		cam_text = "Камера: около %s %s — высокая фигура в чёрном плаще и шляпе. Под плащом — чужая одежда: %s." % [tt, cs["name"], look.trim_prefix("в ")]
	elif villain_id == "shadow":
		cam_text += " Его тень падает к лампе, а не от неё."
	camera_clue("g_cam_crime", crime_cam, culprit, crime_t, "Запись: %s" % cs["short"], cam_text, [culprit], true, 0.4, EXCURSION_STAY)
	# След на месте происшествия
	var trace: String = str(_ch(culprit)["trace"])
	if villain_id == "black_cloak":
		trace = "клочок чёрной плотной ткани и рядом — " + trace
	clue("g_trace", "physical", "След: " + cs["short"], "На полу %s — %s." % [cs["name"], trace])
	floor_item("obj_g_trace", cs["carriage"], cs["trace"], "fabric_scrap", "Осмотреть след", "След на полу", "Здесь недавно кто-то был: " + trace + ".", "g_trace")
	clue("x_g_trace", "contradiction", "След совпадает с приметами", "%s на месте происшествия совпадает с приметами пассажира: %s." % [trace.capitalize(), c_name], [culprit], -1.0, true)
	deduction("x_g_trace", ["g_trace"], ["d_look_" + culprit])
	# Алиби: виновник лжёт, остальные говорят правду (по хронологии)
	var lie_place: String = spot_place(home_spot(culprit))
	for s: String in d["suspects"]:
		var where: String = lie_place if s == culprit else place(s, crime_t).replace("шёл ", "шёл " if _g(s, "m", "f") == "m" else "шла ")
		var line: String = "Около %s я был%s %s." % [tt, _g(s, "", "а"), where]
		clue("g_alibi_" + s, "testimony", "Алиби: " + Db.char_name(s), "%s: «%s»" % [Db.char_name(s), line], [s], crime_t)
		topic(s, "g_alibi", "Где вы были около %s?" % tt, [line], ["g_alibi_" + s])
	clue("x_g_alibi", "contradiction", "Ложное алиби", "%s говорит, что был%s %s, но запись камеры показывает: %s." % [c_name, _g(culprit, "", "а"), lie_place, cs["name"]], [culprit], crime_t, true)
	deduction("x_g_alibi", ["g_alibi_" + culprit], ["g_cam_crime"], ["g_alibi_" + culprit])
	# Свидетель: ближайший невиновный к месту в момент происшествия
	var best: float = INF
	for s: String in d["suspects"]:
		if s == culprit:
			continue
		var dist: float = timeline.position_at(s, crime_t).distance_to(_spot_pos(crime_spot))
		if dist < best:
			best = dist
			witness = s
	if witness != "":
		var wl: String = "Около %s мимо меня к месту «%s» прошёл человек %s." % [tt, cs["short"], look]
		clue("g_witness", "testimony", "Свидетель: " + Db.char_name(witness), "%s: «%s»" % [Db.char_name(witness), wl], [culprit], crime_t, true)
		topic(witness, "g_saw", "Вы видели кого-нибудь около %s?" % tt, [wl], ["g_witness"], ["g_incident"])
		deduction("x_g_alibi", ["g_alibi_" + culprit], ["g_witness"], ["g_alibi_" + culprit])
	# Лор злодея: книга профессора и разговор о злодее
	d["clues"]["i_prof_book"]["title"] = "Заметки о злодее"
	d["clues"]["i_prof_book"]["text"] = "Пометки профессора: «%s. %s Как поймать: %s»" % [villain.get("name", ""), villain.get("short", ""), villain.get("counter", "")]
	for it: Dictionary in d["luggage"]["professor"]["items"]:
		if it.has("hotspot") and it["hotspot"]["clue"] == "i_prof_book":
			it["hotspot"]["text"] = d["clues"]["i_prof_book"]["text"]
	clue("g_lore", "testimony", "Как распознать злодея", "Профессор: «%s»" % villain.get("counter", ""), [])
	topic("professor", "g_lore", "Что вы знаете о злодее в поезде?", ["%s — %s" % [villain.get("name", ""), str(villain.get("short", "")).to_lower()], str(villain.get("counter", ""))], ["g_lore"])


# --- убийства: кто может погибнуть и как связать улики --------------------------------------
func _murders() -> void:
	var cfg: Dictionary = d["murders"]
	cfg["murderer"] = culprit
	# Защищены: виновник, свидетель происшествия, рассказчик брифинга, профессор (знает о злодее)
	# и особые участники способности злодея (усыплённый, «куклы»).
	var protected: Array = [culprit, "detective", "professor", "john" if culprit == "agata" else "agata"]
	if witness != "":
		protected.append(witness)
	for key in ["sleeper_w"]:
		if has_meta(key):
			protected.append(get_meta(key))
	if has_meta("puppets"):
		protected.append_array(get_meta("puppets"))
	cfg["protected"] = protected
	var pool: Array = ["vera", "orlov", "mark"]
	for s2: String in d["suspects"]:
		if not s2 in protected:
			pool.append(s2)
	cfg["victim_pool"] = pool
	cfg["murderer_look"] = "высокий, в длинном чёрном плаще и шляпе" if villain_id == "black_cloak" else str(_ch(culprit)["look"])
	cfg["links"] = {"fibers": ["c_{pre}", "d_look_{culprit}"], "steps": ["g_alibi_{culprit}"], "home_spots": [home_spot(culprit)]}


const BRIEF_OPENERS: Array[String] = [
	"Инспектор, хорошо, что вы здесь. Мне нужна ваша помощь — и тишина.",
	"Инспектор… прошу, говорите тише. Пассажиры ещё ничего не знают.",
	"Слава богу, вы в поезде, инспектор. Столько лет на этой линии — а такого не припомню.",
	"Инспектор, на пару слов. Не здесь — в коридоре нас могут услышать.",
]
const BRIEF_ODDITIES: Array[String] = [
	"Двери были заперты, в коридоре никого не видели. И всё же кто-то там был.",
	"Никто ничего не слышал. Или делает вид, что не слышал.",
	"Свет мигнул всего на секунду. Когда он зажёгся, всё уже случилось.",
	"Странно другое: у каждого пассажира есть объяснение. Слишком гладкое объяснение.",
]
const BRIEF_SUSPICIONS: Array[String] = [
	"Тот, кто это сделал, всё ещё в поезде. Он сидит рядом с нами и улыбается.",
	"Кто-то из пассажиров — не тот, за кого себя выдаёт. Я не знаю, кто.",
	"Я смотрю на знакомые лица — и не могу доверять ни одному из них.",
	"Он среди пассажиров. И, кажется, он знает, что вы здесь.",
]


static func _pick(generator: RandomNumberGenerator, lines: Array[String]) -> String:
	return lines[generator.randi_range(0, lines.size() - 1)]


func _brief_and_truth() -> void:
	var cs: Dictionary = CRIME_SPOTS[crime_spot]
	var speaker: String = "john" if culprit == "agata" else "agata"
	var tt: String = Db.format_time(crime_t)
	# Вводная в духе детектива: что случилось и что настораживает — без имени злодея и его
	# способностей (их игрок узнаёт сам, по уликам). Фразы — из наборов, по зерну дела.
	var flavor := RandomNumberGenerator.new()
	flavor.seed = hash("%d|brief" % rng.seed)
	d["brief"] = {"speaker": speaker, "lines": [
		_pick(flavor, BRIEF_OPENERS),
		"Около %s %s." % [tt, cs["incident"]],
		_pick(flavor, BRIEF_ODDITIES),
		_pick(flavor, BRIEF_SUSPICIONS),
		"До станции %s двадцать минут. Там преступник сойдёт — и мы его больше не увидим." % d["station_to"]],
		"goal": "Найдите виновного за 20 минут: записи камер, документы, багаж, показания. Никому не верьте на слово.",
		"gives": ["g_incident"] + (["g_archive"] if d["clues"].has("g_archive") else [])}
	d["truth"] = [
		"%s выдавал себя за пассажира: %s." % [villain.get("name", "Злодей"), Db.char_name(culprit)],
		"Около %s он был %s — это видно на записи камеры, а на полу остался след: %s." % [tt, cs["name"], _ch(culprit)["trace"]],
		"Его способность: %s Контрмера: %s" % [villain.get("ability", ""), villain.get("counter", "")],
	]


# --- особые улики злодеев (история дела) ---------------------------------------------------
func _villain_black_cloak() -> void:
	var sig: String = str(_ch(culprit).get("signature", ""))
	clue("g_sign", "document", "Чужая подпись", "Подпись на корешке билета — печатными буквами. Настоящая подпись владельца: %s." % sig, [culprit], -1.0, true)
	doc_hotspot(culprit, "Подпись на корешке билета", "Подпись выведена печатными буквами, чернила свежие. Не похоже на подпись владельца: %s." % sig, "g_sign")


func _villain_shapeshifter() -> void:
	clue("g_face", "document", "Лицо не совпадает с фото", "Фото в документах %s не совпадает с лицом того, кто их предъявил." % Db.char_name(culprit), [culprit], -1.0, true)
	doc_hotspot(culprit, "Фото в документах", "Фото в документах — другое лицо. Тот, кто предъявил билет, лишь похож на чужого пассажира.", "g_face")
	clue("g_bag", "item", "Вещи не по размеру", "В багаже — вещи %s: облик меняется, а багаж остаётся прежним." % Db.char_name(culprit), [culprit], -1.0, true)
	luggage_hotspot(culprit, "Сменная одежда", "Сложена очень аккуратно.", "Бирки и размер", "Все бирки подписаны одним почерком, хотя хозяин «выглядит» иначе.", "g_bag")


func _villain_mirror_schedule() -> void:
	var t2: float = crime_t - 7.0 if crime_t - 7.0 > Db.parse_time("01:27") else crime_t + 6.0
	set_meta("mirror_t", t2)
	excursion(culprit, t2, "end_mirror", "hide", 1.2)


func _villain_mirror() -> void:
	var t2: float = get_meta("mirror_t")
	camera_clue("g_mirror_cam", "cam1", culprit, t2, "Запись: у зеркала", "Камера: человек %s стоит у зеркала — а в самом зеркале пусто." % _ch(culprit)["look"], [culprit], true, 0.3, 1.2)
	clue("g_mirror_photo", "document", "Блик вместо глаз", "На фото в документах %s вместо глаз — блики, как в стекле." % Db.char_name(culprit), [culprit], -1.0, true)
	doc_hotspot(culprit, "Фото в документах", "Вместо глаз на фото — два стеклянных блика.", "g_mirror_photo")
	clue("x_g_mirror", "contradiction", "Нет отражения", "Тот, кто стоял у зеркала без отражения, и человек с бликами на фото — один пассажир.", [culprit], -1.0, true)
	deduction("x_g_mirror", ["g_mirror_cam"], ["g_mirror_photo", "d_look_" + culprit])


func _villain_mimic() -> void:
	# Мимик копирует людей: повторяет фразы с задержкой, путается в чужой биографии, оставляет воск.
	var witness: String = d["suspects"].filter(func(s: String) -> bool: return s != culprit)[0]
	clue("g_echo", "testimony", "Повторил слово в слово", "%s: «%s повторил мою фразу слово в слово — через минуту, тем же голосом, будто эхо»." % [Db.char_name(witness), Db.char_name(culprit)], [culprit], -1.0, true)
	topic(witness, "g_echo", "Кто-нибудь вёл себя странно?", ["%s повторил мою фразу слово в слово. Через минуту. Тем же голосом." % Db.char_name(culprit), "Как эхо. Мне стало не по себе."], ["g_echo"])
	clue("g_wax", "physical", "Серый воск на ткани", "На одежде %s — серый воск: тянется, как свечной, но не пахнет и не плавится." % Db.char_name(culprit), [culprit], -1.0, true)
	luggage_hotspot(culprit, "Сменная одежда", "Сложена аккуратно.", "Подкладка", "На подкладке — серый воск: тянется, как свечной, и ничем не пахнет.", "g_wax")
	clue("g_memory", "testimony", "Не помнит общего прошлого", "%s не смог вспомнить ни одного общего знакомого из своего же города." % Db.char_name(culprit), [culprit])
	topic(culprit, "g_memory", "Вы ведь из того же города, что и я? Помните аптеку на площади?", ["Аптеку? Да... конечно. Аптеку на площади... на площади.", "(Он повторяет ваши слова и не говорит ничего своего.)"], ["g_memory"])
	clue("x_g_mimic", "contradiction", "Тот, кто копирует", "Он повторяет чужие слова, не помнит собственного прошлого и оставляет серый воск: это мимик в чужом облике.", [culprit], -1.0, true)
	deduction("x_g_mimic", ["g_echo", "g_memory"], ["g_wax"])


func _villain_shadow() -> void:
	var cs: Dictionary = CRIME_SPOTS[crime_spot]
	clue("g_bulb", "physical", "Выкрученная лампа", "Лампа рядом с местом «%s» выкручена — кому-то мешал свет." % cs["short"], [])
	floor_item("obj_g_bulb", cs["carriage"], free_floor(cs["carriage"], Vector2(cs["trace"][0] + 22, cs["trace"][1] - 6)), "floor_ticket", "Осмотреть лампочку", "Лампочка на полу", "Кто-то выкрутил лампу и бросил её на пол.", "g_bulb")
	clue("x_g_shadow", "contradiction", "Тень к свету", "Свет погасили там, где тень пассажира падала не туда: его тень живёт своей жизнью.", [culprit], -1.0, true)
	deduction("x_g_shadow", ["g_bulb"], ["g_cam_crime"])


func _villain_sleeper_schedule() -> void:
	# Свидетель засыпает рядом с местом происшествия; виновник заходил к нему за 6 минут до этого.
	var best: String = ""
	var bd: float = INF
	for s: String in d["suspects"]:
		if s == culprit:
			continue
		var dist: float = timeline.position_at(s, crime_t).distance_to(_spot_pos(crime_spot))
		if dist < bd:
			bd = dist
			best = s
	set_meta("sleeper_w", best)
	var st: Dictionary = timeline.state_at(best, crime_t - 4.0)
	timeline.add_excursion(best, crime_t - 4.0, str(st["spot"]), "sleep", crime_t + 3.0)
	var visit: String = near_spot(timeline.position_at(best, crime_t - 6.0), [crime_spot])
	set_meta("sleeper_visit", visit)
	if visit != "":
		excursion(culprit, crime_t - 6.0, visit, "talk", 0.8)


func _villain_sleeper() -> void:
	var w: String = get_meta("sleeper_w")
	var t0: float = crime_t - 4.0
	var gap: String = "Я выпил%s чаю и уснул%s около %s, а проснул%s только в %s. Ничего не помню." % [_g(w, "", "а"), _g(w, "", "а"), Db.format_time(t0), _g(w, "ся", "ась"), Db.format_time(crime_t + 3.0)]
	clue("g_gap", "testimony", "Провал в памяти", "%s: «%s»" % [Db.char_name(w), gap], [w], t0)
	topic(w, "g_gap", "Вы ничего не слышали?", [gap], ["g_gap"])
	var pos: Vector2 = timeline.position_at(w, t0)
	var car: String = layout.carriage_at(pos.x)
	floor_item("obj_g_cup", car, free_floor(car, Vector2(pos.x - layout.offsets[car] + 14, pos.y + 12)), "cup_spill", "Осмотреть чашку", "Чашка у спящего", "Чай с горьким осадком и сладковатым запахом.", "g_cup")
	clue("g_cup", "physical", "Горький осадок", "В чашке у места, где уснул%s %s, — горький осадок с запахом лаванды." % [_g(w, "", "а"), Db.char_name(w)], [])
	clue("g_powder", "item", "Сонный порошок", "В багаже %s — пакетик порошка с запахом лаванды." % Db.char_name(culprit), [culprit], -1.0, true)
	luggage_hotspot(culprit, "Аптечка", "Бинты, пластырь, пакетики.", "Пакетик без надписи", "Белый порошок с запахом лаванды. Тот же запах, что у осадка в чашке.", "g_powder")
	clue("x_g_sleep", "contradiction", "Свидетеля усыпили", "Осадок в чашке и порошок из багажа — одно и то же: свидетеля усыпили нарочно.", [culprit], -1.0, true)
	deduction("x_g_sleep", ["g_cup", "g_gap"], ["g_powder"])
	var visit: String = get_meta("sleeper_visit")
	if visit != "":
		var cam: String = camera_for(_spot_pos(visit))
		camera_clue("g_visit_cam", cam, culprit, crime_t - 6.0, "Запись: визит к свидетелю", "Камера: за несколько минут до сна %s к пассажиру подходил человек %s с чашкой." % [Db.char_name(w), _ch(culprit)["look"]], [culprit], true, 0.4, 0.8)


func _villain_conductor_double_schedule() -> void:
	# Самозванка обходит купе с конца вагона — настоящая Агата всегда начинает с первого.
	timeline.add_excursion("agata", Db.parse_time("01:26"), "bay4_c", "check", Db.parse_time("01:27"))
	timeline.add_excursion("agata", Db.parse_time("01:27"), "bay3_c", "check", Db.parse_time("01:28"))
	timeline.add_excursion("agata", Db.parse_time("01:28"), "bay2_c", "check", Db.parse_time("01:29"))


func _villain_conductor_double() -> void:
	camera_clue("g_round", "cam1", "agata", Db.parse_time("01:26:30"), "Запись: обход вагона", "Камера: в 01:26 проводница начала обход с последнего купе и пошла к первому.", ["agata"], true, 0.3, 2.0)
	clue("g_badge", "document", "Новое удостоверение", "Удостоверение проводницы выдано три года назад, хотя «стаж 40 лет».", ["agata"], -1.0, true)
	doc_hotspot("agata", "Дата выдачи", "Выдано три года назад. При стаже сорок лет удостоверение было бы старым и потёртым.", "g_badge")
	var line: String = "Агата Петровна двадцать лет начинает обход с первого купе и приносит мне чай с лимоном. А сегодня пошла с конца и принесла кофе."
	clue("g_habit", "testimony", "Чужие привычки", "Профессор: «%s»" % line, ["agata"], -1.0, true)
	topic("professor", "g_habit", "Агата Петровна сегодня вела себя как обычно?", [line], ["g_habit"])
	clue("x_g_double", "contradiction", "Не та проводница", "Обход в обратном порядке и чужие привычки: проводница — самозванка.", ["agata"], -1.0, true)
	deduction("x_g_double", ["g_round"], ["g_habit", "g_badge"])


func _villain_puppeteer_schedule() -> void:
	var pool: Array = []
	for s: String in d["suspects"]:
		if s != culprit and s != "agata":
			pool.append(s)
	var a: String = pool.pop_at(rng.randi_range(0, pool.size() - 1))
	var b: String = pool.pop_at(rng.randi_range(0, pool.size() - 1))
	set_meta("puppets", [a, b])
	var va: String = near_spot(timeline.position_at(a, crime_t - 9.0), [crime_spot])
	var vb: String = near_spot(timeline.position_at(b, crime_t - 6.0), [crime_spot, va])
	excursion(culprit, crime_t - 9.0, va, "talk", 0.8)
	excursion(culprit, crime_t - 6.0, vb, "talk", 0.8)
	set_meta("puppet_spots", [va, vb])


func _villain_puppeteer() -> void:
	var puppets: Array = get_meta("puppets")
	var spots: Array = get_meta("puppet_spots")
	var same: String = "Весь вечер — окно, огни и далёкий колокольчик. Больше ничего не помню."
	for i in 2:
		var p: String = puppets[i]
		# Внушённое воспоминание заменяет правдивое алиби — у обоих слово в слово.
		for t: Dictionary in d["dialogues"][p]["topics"]:
			if t["id"] == "g_alibi":
				t["a"] = [same]
		d["clues"]["g_alibi_" + p]["text"] = "%s: «%s»" % [Db.char_name(p), same]
		var t0: float = crime_t - (9.0 if i == 0 else 6.0)
		camera_clue("g_puppet_%d" % i, camera_for(_spot_pos(spots[i])), culprit, t0, "Запись: разговор с %s" % Db.char_name(p),
			"Камера: за несколько минут до происшествия человек %s о чём-то долго говорил с пассажиром: %s." % [_ch(culprit)["look"], Db.char_name(p)], [culprit], true, 0.4, 0.8)
	clue("x_g_same", "contradiction", "Слово в слово", "%s и %s описывают вечер одинаковыми словами — это внушённые воспоминания." % [Db.char_name(puppets[0]), Db.char_name(puppets[1])], [])
	deduction("x_g_same", ["g_alibi_" + puppets[0]], ["g_alibi_" + puppets[1]])
	clue("x_g_puppet", "contradiction", "Кукловод", "Оба «запрограммированных» свидетеля перед этим говорили с одним и тем же человеком.", [culprit], -1.0, true)
	deduction("x_g_puppet", ["x_g_same"], ["g_puppet_0", "g_puppet_1"])


func _villain_passenger_zero() -> void:
	var tokens: Array = [["passenger", [300, 140]], ["vestibule", [40, 170]], ["restaurant", [250, 150]]]
	for i in tokens.size():
		var id: String = "g_token_%d" % i
		clue(id, "physical", "Жетон без номера (%s)" % layout.carriage_name(tokens[i][0]), "Латунный жетон без номера — такие находили в прошлых делах.", [])
		floor_item("obj_" + id, tokens[i][0], tokens[i][1], "floor_ticket", "Осмотреть жетон", "Жетон без номера", "Латунный жетон без номера и без имени.", id)
	var solved: int = 0
	for l: Dictionary in Db.levels():
		if ProgressionManager.level_completed(l["id"]):
			solved += 1
	clue("g_archive", "item", "Архив прошлых дел", "Архив: у злодеев из %d раскрытых дел находили латунные жетоны без номера. Кто-то вёл их всех." % solved, [])
	d["brief"] = {}
	clue("g_tokens", "item", "Связка жетонов", "В узелке Тихона — связка жетонов без номера.", ["tikhon"], -1.0, true)
	luggage_hotspot("tikhon", "Холщовый мешочек", "Позвякивает.", "Содержимое", "Связка латунных жетонов без номера — точь-в-точь как в каждом вагоне.", "g_tokens")
	d["objects"]["obj_register"]["fields"] = [["Пассажиров по ведомости", "7"], ["Пассажиров в вагоне", "8"], ["Примечание", "Одного имени в ведомости нет"]]
	d["objects"]["obj_register"]["on_open"] = "g_noname"
	clue("g_noname", "document", "Пассажира нет в ведомости", "В ведомости 7 имён, а в вагоне едут 8 человек.", [])
	clue("x_g_zero", "contradiction", "Пассажир ноль", "Жетоны в каждом вагоне и связка жетонов в узелке Тихона: человек без имени связан со всеми прошлыми делами.", ["tikhon"], -1.0, true)
	deduction("x_g_zero", ["g_token_0", "g_token_1", "g_token_2", "g_archive"], ["g_tokens"])
	clue("x_g_noname", "contradiction", "Тот, кого нет", "Лишний пассажир без имени и без билета — Тихон.", ["tikhon"], -1.0, true)
	deduction("x_g_noname", ["g_noname"], ["d_tikhon_noticket"])
