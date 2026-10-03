class_name SuspectManager
extends RefCounted
## Сведения о подозреваемых: знакомство, проверки, пометки игрока и задержания.

var suspects: PackedStringArray = []
var info: Dictionary = {}  # id → {met, docs, luggage, mark, wrongly_accused, detained}


func _init(ids: PackedStringArray) -> void:
	suspects = ids
	for id in ids:
		info[id] = {"met": false, "docs": false, "luggage": false, "mark": "", "wrongly_accused": false, "detained": false}


func get_info(id: String) -> Dictionary:
	return info.get(id, {})


func flag(id: String, key: String) -> bool:
	return bool(info.get(id, {}).get(key, false))


## Отметить проверку. Возвращает true, если это первая такая проверка (для статистики).
func set_flag(id: String, key: String, value: bool = true) -> bool:
	if not info.has(id):
		return false
	var was: bool = bool(info[id].get(key, false))
	info[id][key] = value
	return value and not was


## Пометка игрока: "suspect" (подозреваю), "trust" (доверяю) или "".
func set_mark(id: String, mark: String) -> void:
	if info.has(id):
		info[id]["mark"] = mark


func mark(id: String) -> String:
	return str(info.get(id, {}).get("mark", ""))


func checks_done(id: String) -> int:
	var n: int = 0
	for key in ["met", "docs", "luggage"]:
		if flag(id, key):
			n += 1
	return n


func serialize() -> Dictionary:
	return info.duplicate(true)


func restore(data: Dictionary) -> void:
	for id: String in data:
		if info.has(id):
			info[id].merge(data[id], true)
