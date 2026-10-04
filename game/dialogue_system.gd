class_name DialogueSystem
extends RefCounted
## Диалоги. Реплики зависят от хода дела:
##   • темы открываются найденными уликами (requires — все, requires_any — хотя бы одна),
##     событиями (requires_event), состоянием собеседника (requires_state) и закрываются
##     уликами, после которых вопрос не имеет смысла (hide_if);
##   • приветствие меняется по ситуации ("greets": [{text, условия}], "wrong_greet" — после
##     ошибочного обвинения этого человека);
##   • реакции на предъявленные улики ("reactions": {улика: ответ или [варианты с условиями]}),
##     например: сначала «выходил на минуту», а после следа на тележке — признание.
## Ответы записываются в журнал.

const DEFAULT_REACTION: String = "Не понимаю, при чём тут это."

var dialogues: Dictionary
var asked: Dictionary = {}  # персонаж → Array[id темы]
var log: Array = []         # [{who, q, a: Array}]


func _init(data: Dictionary) -> void:
	dialogues = data


func _ok(cond: Dictionary, evidence: EvidenceSystem, ctx: Dictionary) -> bool:
	for req: String in cond.get("requires", []):
		if not evidence.has(req):
			return false
	var any: Array = cond.get("requires_any", [])
	if not any.is_empty():
		var hit: bool = false
		for req: String in any:
			if evidence.has(req):
				hit = true
		if not hit:
			return false
	for ev: String in cond.get("requires_event", []):
		if not ev in ctx.get("events", []):
			return false
	var states: Array = cond.get("requires_state", [])
	if not states.is_empty() and not str(ctx.get("state", "calm")) in states:
		return false
	for h: String in cond.get("hide_if", []):
		if evidence.has(h):
			return false
	return true


func greet(who: String, evidence: EvidenceSystem = null, ctx: Dictionary = {}) -> String:
	var d: Dictionary = dialogues.get(who, {})
	if ctx.get("wrong", false) and d.has("wrong_greet"):
		return str(d["wrong_greet"])
	var text: String = str(d.get("greet", "..."))
	if evidence:
		for g: Dictionary in d.get("greets", []):
			if _ok(g, evidence, ctx):
				text = str(g["text"])
	return text


func was_asked(who: String, topic_id: String) -> bool:
	return topic_id in asked.get(who, [])


## Доступные темы с флагом asked.
func topics(who: String, evidence: EvidenceSystem, ctx: Dictionary = {}) -> Array:
	var out: Array = []
	for t: Dictionary in dialogues.get(who, {}).get("topics", []):
		if _ok(t, evidence, ctx):
			var d: Dictionary = t.duplicate()
			d["asked"] = was_asked(who, t["id"])
			out.append(d)
	return out


func has_new_topics(who: String, evidence: EvidenceSystem, ctx: Dictionary = {}) -> bool:
	for t: Dictionary in topics(who, evidence, ctx):
		if not t["asked"]:
			return true
	return false


## Задать вопрос. Повторный вопрос — повторный ответ ("a_repeat", если есть).
func ask(who: String, topic_id: String, evidence: EvidenceSystem, ctx: Dictionary = {}) -> Dictionary:
	for t: Dictionary in topics(who, evidence, ctx):
		if t["id"] != topic_id:
			continue
		if not was_asked(who, topic_id):
			if not asked.has(who):
				asked[who] = []
			asked[who].append(topic_id)
			log.append({"who": who, "q": t["q"], "a": t["a"]})
		elif t.has("a_repeat"):
			var r: Dictionary = t.duplicate()
			r["a"] = t["a_repeat"]
			return r
		return t
	return {}


## Реакция на предъявленную улику: последний подходящий вариант из данных или вежливое недоумение.
func reaction(who: String, clue_id: String, evidence: EvidenceSystem, ctx: Dictionary = {}) -> Dictionary:
	var d: Dictionary = dialogues.get(who, {})
	var r: Variant = d.get("reactions", {}).get(clue_id)
	var chosen: Dictionary = {}
	if r is Dictionary:
		chosen = r if _ok(r, evidence, ctx) else {}
	elif r is Array:
		for v: Dictionary in r:
			if _ok(v, evidence, ctx):
				chosen = v
	if chosen.is_empty():
		return {"a": [str(d.get("default_reaction", DEFAULT_REACTION))], "known": false}
	var out: Dictionary = chosen.duplicate()
	out["known"] = true
	log.append({"who": who, "q": "Предъявлено: " + str(evidence.clue(clue_id).get("title", clue_id)), "a": chosen["a"]})
	return out


func serialize() -> Dictionary:
	return {"asked": asked, "log": log}


func restore(data: Dictionary) -> void:
	asked = data.get("asked", {})
	log = data.get("log", [])
