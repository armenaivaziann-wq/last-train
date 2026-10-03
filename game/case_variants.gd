class_name CaseVariants
extends RefCounted
## Варианты статичного дела: разные места ключевых улик и последовательности событий.
## В данных дела раздел "variants": [{"id", "name", "set": {"путь.через.точки": значение}}].
## Вариант выбирается по seed попытки и согласованно меняет расписание, объекты, тексты улик
## и записи камер — логика дела остаётся честной (это проверяют тесты).


static func apply(d: Dictionary, seed_value: int) -> void:
	var variants: Array = d.get("variants", [])
	if variants.is_empty():
		return
	var v: Dictionary = variants[absi(seed_value) % variants.size()]
	d["variant"] = str(v.get("id", ""))
	var sets: Dictionary = v.get("set", {})
	for path: String in sets:
		set_path(d, path, sets[path])


static func set_path(root: Variant, path: String, value: Variant) -> void:
	var parts: PackedStringArray = path.split(".")
	var node: Variant = root
	for i in parts.size() - 1:
		node = _child(node, parts[i])
		if node == null:
			push_error("Вариант дела: нет пути " + path)
			return
	var last: String = parts[parts.size() - 1]
	if node is Array:
		node[int(last)] = value
	else:
		node[last] = value


static func _child(node: Variant, key: String) -> Variant:
	if node is Array:
		var i: int = int(key)
		return node[i] if i < node.size() else null
	if node is Dictionary:
		return node.get(key)
	return null
