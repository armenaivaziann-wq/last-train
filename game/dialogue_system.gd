class_name DialogueSystem
extends RefCounted
## Диалоги: темы разговора по персонажам. Новые темы открываются найденными уликами
## (requires — все, requires_any — хотя бы одна). Ответы записываются в журнал.

var dialogues: Dictionary
var asked: Dictionary = {}  # персонаж → Array[id темы]
var log: Array = []         # [{who, q, a: Array}]


func _init(data: Dictionary) -> void:
	dialogues = data


func greet(who: String) -> String:
	return str(dialogues.get(who, {}).get("greet", "..."))


func _unlocked(topic: Dictionary, evidence: EvidenceSystem) -> bool:
	for req: String in topic.get("requires", []):
		if not evidence.has(req):
			return false
	var any: Array = topic.get("requires_any", [])
	if not any.is_empty():
		for req: String in any:
			if evidence.has(req):
				return true
		return false
	return true


func was_asked(who: String, topic_id: String) -> bool:
	return topic_id in asked.get(who, [])


## Доступные темы с флагом asked.
func topics(who: String, evidence: EvidenceSystem) -> Array:
	var out: Array = []
	for t: Dictionary in dialogues.get(who, {}).get("topics", []):
		if _unlocked(t, evidence):
			var d: Dictionary = t.duplicate()
			d["asked"] = was_asked(who, t["id"])
			out.append(d)
	return out


func has_new_topics(who: String, evidence: EvidenceSystem) -> bool:
	for t: Dictionary in topics(who, evidence):
		if not t["asked"]:
			return true
	return false


## Задать вопрос. Возвращает тему (с ответом и выдаваемыми уликами) или {}.
func ask(who: String, topic_id: String, evidence: EvidenceSystem) -> Dictionary:
	for t: Dictionary in topics(who, evidence):
		if t["id"] != topic_id:
			continue
		if not was_asked(who, topic_id):
			if not asked.has(who):
				asked[who] = []
			asked[who].append(topic_id)
			log.append({"who": who, "q": t["q"], "a": t["a"]})
		return t
	return {}


func serialize() -> Dictionary:
	return {"asked": asked, "log": log}


func restore(data: Dictionary) -> void:
	asked = data.get("asked", {})
	log = data.get("log", [])
