class_name StoryDirector
extends RefCounted
## Сюжетные события авторского дела ("story_events"). Каждое срабатывает ровно один раз,
## по логическому условию сценария, а не по таймеру в кадре:
##   {"at": "+4.0"}                         — через N игровых минут после начала дела;
##   {"tunnel": 0, "stage": "tunnel_out"}   — на стадии туннеля №i (туннели планирует MurderDirector);
##   {"clue": "id"}                         — когда игрок нашёл улику (например, вскрыл чемодан).
## Эффекты:
##   state {npc, state}        — спокоен / испуган / болен / спит / пропал / спасён...
##   give {clues}, toast {text, icon}, sound {name}, banner {title, text}
##   item {id, carriage, pos, sprite, label} / remove_item {id} — предметы в мире
##   voice {text, carriage, x, y, sound} — голос с направлением
## Эффекты, влияющие на прошлое мира (маршрут, тёмная зона, запись камеры), считаются при
## планировании и допустимы только у событий с известным временем — так записи камер и
## хронология совпадают:
##   excursion {npc, spot, act, stay, delay}, dark {carriage, minutes}, camera {id, npc, ...}

var inv: InvestigationManager
var events: Array = []        # [{id, t (или -1), clue, effects}]
var done: Array = []          # id сработавших событий
var spawned: Array = []       # id предметов, появившихся по событиям


func plan(investigation: InvestigationManager) -> void:
	inv = investigation
	for ev: Dictionary in inv.data.get("story_events", []):
		var tr: Dictionary = ev.get("trigger", {})
		var t: float = -1.0
		if tr.has("at"):
			t = inv.start_time + float(str(tr["at"]).trim_prefix("+"))
		elif tr.has("tunnel"):
			var i: int = int(tr["tunnel"])
			if i < inv.murders.murders.size():
				t = float(inv.murders.murders[i]["t"][str(tr.get("stage", "tunnel_in"))])
			else:
				continue
		var e := {"id": str(ev["id"]), "t": t, "clue": str(tr.get("clue", "")), "effects": ev.get("effects", [])}
		events.append(e)
		if t >= 0.0:
			_plan_world(e)
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["t"] < b["t"])


## Эффекты, меняющие хронологию (выполняются один раз при планировании, детерминированно).
func _plan_world(e: Dictionary) -> void:
	var t: float = e["t"]
	for fx: Dictionary in e["effects"]:
		match str(fx["type"]):
			"excursion":
				var at: float = t + float(fx.get("delay", 0.0))
				var spot: String = str(fx["spot"])
				var npc: String = str(fx["npc"])
				var depart: float = at - inv.timeline.travel_minutes(npc, at - 0.6, spot) - 0.05
				inv.timeline.add_excursion(npc, maxf(depart, t), spot, str(fx.get("act", "idle")), at + float(fx.get("stay", 1.5)))
			"dark":
				if not inv.data.has("dark_zones"):
					inv.data["dark_zones"] = []
				inv.data["dark_zones"].append({"carriage": fx["carriage"], "from": CaseBuilder.fmt(t), "to": CaseBuilder.fmt(t + float(fx.get("minutes", 1.0)))})
			"camera":
				var at2: float = t + float(fx.get("delay", 0.0))
				var npc2: String = str(fx["npc"])
				var cam: String = CaseBuilder.camera_at(inv.layout, inv.timeline.position_at(npc2, at2))
				var w: Array = CaseBuilder.window(inv.layout, inv.timeline, cam, npc2, at2, float(fx.get("before", 0.2)), float(fx.get("after", 0.6)))
				if w.is_empty():
					push_error("Событие %s: %s не в кадре" % [e["id"], npc2])
					continue
				inv.data["camera_clues"].append({"id": fx["id"], "camera": cam, "npc": npc2, "windows": [w]})
				inv.data["clues"][fx["id"]] = {"type": "camera", "title": str(fx["title"]).replace("{cam}", "К" + cam.substr(3)),
					"text": str(fx["text"]).replace("{cam}", "К" + cam.substr(3)).replace("{time}", Db.format_time(at2)),
					"points_to": fx.get("points_to", []), "time": Db.format_time(at2)}
				if fx.get("key", false):
					inv.data["key_clues"].append(fx["id"])


## События, время которых наступило (по порядку), — каждое один раз.
func due(clock: float) -> Array:
	var out: Array = []
	for e: Dictionary in events:
		if e["t"] >= 0.0 and clock >= e["t"] and not e["id"] in done:
			done.append(e["id"])
			out.append(e)
	return out


## События по найденной улике.
func on_clue(clue_id: String) -> Array:
	var out: Array = []
	for e: Dictionary in events:
		if e["clue"] == clue_id and not e["id"] in done:
			done.append(e["id"])
			out.append(e)
	return out


func happened(event_id: String) -> bool:
	return event_id in done


## Определение предмета, который появляется по событию (для восстановления после загрузки).
func item_def(item_id: String) -> Dictionary:
	for e: Dictionary in events:
		for fx: Dictionary in e["effects"]:
			if fx["type"] == "item" and fx["id"] == item_id:
				return fx
	return {}


func serialize() -> Dictionary:
	return {"done": done, "spawned": spawned}


func restore(s: Dictionary) -> void:
	done = s.get("done", []).duplicate()
	spawned = s.get("spawned", []).duplicate()
