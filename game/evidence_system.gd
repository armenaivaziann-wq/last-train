class_name EvidenceSystem
extends RefCounted
## Найденные улики и выводы. Игрок сам сопоставляет пары улик в журнале; вывод появляется,
## только если пара описана в данных дела. Ответ автоматически не раскрывается.

signal clue_added(clue_id: String)

var case_data: Dictionary
var found: Array[String] = []
var found_at: Dictionary = {}       # id → минута дела
var tried_pairs: Dictionary = {}    # "a|b" → результат
var statuses: Dictionary = {}       # id показания → "refuted" / "confirmed"
var links: Dictionary = {}          # id улики → id подозреваемого (гипотеза игрока)


func _init(data: Dictionary) -> void:
	case_data = data


func clue(id: String) -> Dictionary:
	return case_data["clues"].get(id, {})


func has(id: String) -> bool:
	return id in found


func add(id: String, minute: float) -> bool:
	if id == "" or has(id) or not case_data["clues"].has(id):
		return false
	found.append(id)
	found_at[id] = minute
	clue_added.emit(id)
	return true


## Улика потеряна (выпала из рук при поимке) — её можно найти снова там же.
func remove(id: String) -> void:
	found.erase(id)
	found_at.erase(id)
	statuses.erase(id)
	links.erase(id)


func is_key(id: String) -> bool:
	return id in case_data.get("key_clues", [])


func key_found_count() -> int:
	var n: int = 0
	for id in found:
		if is_key(id):
			n += 1
	return n


func found_of_type(type: String) -> Array[String]:
	var out: Array[String] = []
	for id in found:
		if clue(id).get("type") == type:
			out.append(id)
	return out


func concerning(suspect: String) -> Array[String]:
	var out: Array[String] = []
	for id in found:
		if suspect in clue(id).get("points_to", []):
			out.append(id)
	return out


## Сопоставить две улики. Возвращает id нового вывода, "" — связи нет, "known" — вывод уже есть.
func deduce(a: String, b: String, minute: float) -> String:
	if not has(a) or not has(b) or a == b:
		return ""
	var key: String = "|".join(PackedStringArray([a, b] if a < b else [b, a]))
	for d: Dictionary in case_data.get("deductions", []):
		var match_ab: bool = a in d["a"] and b in d["b"]
		var match_ba: bool = b in d["a"] and a in d["b"]
		if not (match_ab or match_ba):
			continue
		var result: String = d["result"]
		tried_pairs[key] = result
		if has(result):
			return "known"
		add(result, minute)
		for r: String in d.get("refutes", []):
			statuses[r] = "refuted"
		for r: String in d.get("confirms", []):
			if statuses.get(r, "") != "refuted":
				statuses[r] = "confirmed"
		return result
	tried_pairs[key] = ""
	return ""


## Статус для журнала: факт / вывод / показание (не подтверждено, подтверждено, опровергнуто).
func status(id: String) -> String:
	var t: String = clue(id).get("type", "")
	if t == "contradiction":
		return "deduction"
	if t != "testimony":
		return "fact"
	return statuses.get(id, "unconfirmed")


func link(clue_id: String, suspect: String) -> void:
	if suspect == "":
		links.erase(clue_id)
	else:
		links[clue_id] = suspect


func serialize() -> Dictionary:
	return {"found": found, "found_at": found_at, "tried": tried_pairs, "statuses": statuses, "links": links}


func restore(data: Dictionary) -> void:
	found.clear()
	for id in data.get("found", []):
		found.append(str(id))
	found_at = data.get("found_at", {})
	tried_pairs = data.get("tried", {})
	statuses = data.get("statuses", {})
	links = data.get("links", {})
