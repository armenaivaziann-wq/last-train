class_name HintSystem
extends RefCounted
## Подсказки по реальному состоянию дела (не называют виновника):
##   1 — лёгкий намёк (в каком направлении думать);
##   2 — указание на связь (с какой уже найденной уликой это связано / что сопоставить);
##   3 — где искать (точное место: чей багаж, какой предмет, кого и о чём спросить, какая камера).
## Цель подсказки — следующая ещё не найденная ключевая улика, которую уже можно получить,
## или ещё не сделанный вывод, для которого всё найдено. Каждая подсказка снижает рейтинг.

var inv: InvestigationManager


func _init(investigation: InvestigationManager) -> void:
	inv = investigation


## Подсказка уровня level (1–3) для текущей цели. {text, target}
func hint(level: int) -> Dictionary:
	var ev: EvidenceSystem = inv.evidence
	var d: Dictionary = inv.data
	if not inv.murders.undiscovered().is_empty():
		var m: Dictionary = inv.murders.undiscovered()[0]
		return {"target": "scene", "text": ["Случилось что-то серьёзное — найдите место происшествия.",
			"После крика нужно осмотреть место преступления, пока улики на месте.",
			"Идите туда: %s." % str(m["where"]).to_lower()][clampi(level, 1, 3) - 1]}
	# 1) Вывод, для которого обе стороны уже найдены
	for x: Dictionary in d.get("deductions", []):
		if ev.has(x["result"]) or not x["result"] in d.get("key_clues", []):
			continue
		var fa: Array = x["a"].filter(func(i: String) -> bool: return ev.has(i))
		var fb: Array = x["b"].filter(func(i: String) -> bool: return ev.has(i))
		if not fa.is_empty() and not fb.is_empty():
			var ta: String = str(ev.clue(fa[0])["title"])
			var tb: String = str(ev.clue(fb[0])["title"])
			return {"target": x["result"], "text": ["У вас уже есть всё, чтобы сделать новый вывод. Загляните в журнал.",
				"Одна из найденных улик не сходится с другой. Перечитайте «%s»." % ta,
				"Сопоставьте в журнале «%s» и «%s»." % [ta, tb]][clampi(level, 1, 3) - 1]}
	# 2) Ключевая улика, которую уже можно получить
	for id: String in d.get("key_clues", []):
		if ev.has(id) or not d["clues"].has(id):
			continue
		var src: Dictionary = _source(id)
		if src.is_empty():
			continue
		var related: String = _related_found(id)
		var t1: String = {"doc": "Документы пассажиров иногда говорят больше, чем они сами.",
			"luggage": "Чьи-то вещи хранят ответ. Осмотрите багаж внимательнее — с лупой.",
			"object": "В поезде остались следы, которые вы ещё не осмотрели.",
			"topic": "Кто-то знает больше, чем рассказал. Задайте новые вопросы.",
			"reaction": "Попробуйте предъявить найденную улику тому, кого она касается.",
			"camera": "Камеры видели то, чего не видели люди."}.get(src["kind"], "Осмотритесь внимательнее.")
		var t2: String = "Обратите внимание: %s." % src["subject"]
		if related != "":
			t2 = "Обратите внимание: %s. Это связано с «%s»." % [src["subject"], related]
		return {"target": id, "text": [t1, t2, "Где искать: %s." % src["place"]][clampi(level, 1, 3) - 1]}
	return {"target": "verdict", "text": ["Похоже, улик достаточно. Сделайте выводы и подумайте, кому выгодно.",
		"Сравните алиби подозреваемых с записями камер и найденными следами.",
		"Откройте вкладку «Итог дела»: выберите подозреваемого, мотив, способ и до трёх оснований."][clampi(level, 1, 3) - 1]}


## Найденная улика, связанная с целью общим выводом или общим человеком.
func _related_found(id: String) -> String:
	for x: Dictionary in inv.data.get("deductions", []):
		if id in x["a"] or id in x["b"]:
			for other: String in x["a"] + x["b"]:
				if other != id and inv.evidence.has(other):
					return str(inv.evidence.clue(other)["title"])
	return ""


## Откуда можно получить улику прямо сейчас: {kind, subject, place} или {}.
func _source(id: String) -> Dictionary:
	var d: Dictionary = inv.data
	var ev: EvidenceSystem = inv.evidence
	for npc: String in d.get("documents", {}):
		var doc: Dictionary = d["documents"][npc]
		if doc.get("on_open", "") == id or id in doc.get("gives", []):
			return {"kind": "doc", "subject": "документы — " + _name(npc), "place": "проверьте документы: " + _name(npc)}
		for h: Dictionary in doc.get("hotspots", []):
			if h["clue"] == id:
				return {"kind": "doc", "subject": "мелкие детали в документах — " + _name(npc),
					"place": "документы: %s, деталь «%s» (включите лупу)" % [_name(npc), h["label"]]}
	for npc: String in d.get("luggage", {}):
		for it: Dictionary in d["luggage"][npc].get("items", []):
			if it.get("on_open", "") == id or it.get("hotspot", {}).get("clue", "") == id:
				return {"kind": "luggage", "subject": "багаж — " + _name(npc),
					"place": "багаж: %s, вещь «%s»%s" % [_name(npc), it["name"], " (с лупой)" if it.has("hotspot") else ""]}
	for oid: String in d.get("objects", {}):
		var o: Dictionary = d["objects"][oid]
		var hit: bool = o.get("on_open", "") == id or o.get("locked_clue", "") == id
		for h: Dictionary in o.get("hotspots", []):
			if h["clue"] == id:
				hit = true
		if hit and _object_in_world(oid):
			return {"kind": "object", "subject": str(o.get("title", "предмет")).to_lower(),
				"place": "%s — %s" % [o.get("title", "предмет"), _object_place(oid)]}
	for npc: String in d.get("dialogues", {}):
		if inv.state_of(npc) in ["dead", "missing"]:
			continue
		var ctx: Dictionary = inv.dialogue_ctx(npc)
		for t: Dictionary in inv.dialogue.topics(npc, ev, ctx):
			if id in t.get("gives", []):
				return {"kind": "topic", "subject": "разговор — " + _name(npc), "place": "спросите %s: «%s»" % [_name(npc), t["q"]]}
		var reacts: Dictionary = d["dialogues"][npc].get("reactions", {})
		for cid: String in reacts:
			if not ev.has(cid):
				continue
			var variants: Array = reacts[cid] if reacts[cid] is Array else [reacts[cid]]
			for v: Dictionary in variants:
				if id in v.get("gives", []) and inv.dialogue._ok(v, ev, ctx):
					return {"kind": "reaction", "subject": "реакция — " + _name(npc),
						"place": "предъявите «%s»: %s" % [ev.clue(cid)["title"], _name(npc)]}
	for cc: Dictionary in d.get("camera_clues", []):
		if cc["id"] == id and Db.parse_time(cc["windows"][0][0]) <= inv.clock:
			return {"kind": "camera", "subject": "записи камер", "place": "камера К%s, около %s" % [str(cc["camera"]).substr(3), str(cc["windows"][0][0]).substr(0, 5)]}
	return {}


func _name(npc: String) -> String:
	return Db.char_name(npc)


func _object_in_world(oid: String) -> bool:
	for it: Dictionary in inv.data.get("extra_items", []):
		if it["id"] == oid:
			return true
	if oid in inv.story.spawned:
		return true
	if inv.murders.murders.any(func(m: Dictionary) -> bool: return m["victim"] != "" and inv.murders.stage_done(m, "kill") and (MurderDirector.body_object_id(m) == oid or "obj_%s_steps" % m["prefix"] == oid)):
		return true
	for cid in inv.layout.carriage_ids:
		for it2: Dictionary in Db.layout(cid).get("interactables", []):
			if it2["id"] == oid:
				return true
	return oid == "obj_mimic_bag" and inv.hooks.villain == "mimic"


func _object_place(oid: String) -> String:
	for it: Dictionary in inv.data.get("extra_items", []):
		if it["id"] == oid:
			return inv.layout.carriage_name(it["carriage"]).to_lower()
	var def: Dictionary = inv.story.item_def(oid)
	if not def.is_empty():
		return inv.layout.carriage_name(def["carriage"]).to_lower()
	for cid in inv.layout.carriage_ids:
		for it2: Dictionary in Db.layout(cid).get("interactables", []):
			if it2["id"] == oid:
				return inv.layout.carriage_name(cid).to_lower()
	return "в поезде"
