class_name CaseGenerator
extends RefCounted
## Генератор дел кампании (временная заглушка — полная версия собирается на этапе 3).


static func generate(_ref: String, _seed_value: int) -> Dictionary:
	return Db.case_data("case_01").duplicate(true)
