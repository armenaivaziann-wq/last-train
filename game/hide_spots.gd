class_name HideSpots
extends RefCounted
## Укрытия в поезде: где герой может спрятаться от охотника (и подслушать разговор).
## Строятся из раскладки вагонов без ручной разметки: под нижними полками купе, под
## столиками и за стойками ресторанов, за ящиками багажного вагона, за шкафами архива.
## В тамбурах укрытий нет — там не спрячешься. Каждое укрытие проверяется на достижимость
## (TrainValidator), лишние близкие отбрасываются. Дело может добавить свои ("hide_spots")
## или отключить укрытия ("hide_spots_off": true).

const PROPS: Dictionary = {
	"round_table": ["Под столиком", Vector2(0, -16)],
	"bar_counter": ["За стойкой", Vector2(-18, 10)],
	"tea_counter": ["За стойкой", Vector2(-18, 10)],
	"herb_counter": ["За травяной стойкой", Vector2(-18, 10)],
	"crate_stack": ["За ящиками", Vector2(0, 22)],
	"coffin": ["За длинным ящиком", Vector2(0, 18)],
	"file_cabinet": ["За картотекой", Vector2(0, 20)],
	"mail_desk": ["Под почтовым столом", Vector2(0, 18)],
	"telegraph_desk": ["Под столом телеграфиста", Vector2(0, 18)],
	"grand_piano": ["Под роялем", Vector2(0, 22)],
	"piano": ["За пианино", Vector2(0, 22)],
	"luggage_rack": ["За багажной стойкой", Vector2(0, 20)],
	"titan": ["За титаном", Vector2(0, 20)],
	"armchair": ["За креслом", Vector2(0, -12)],
}
## Именованные точки вагонов, за которыми можно спрятаться.
const SPOT_LABELS: Dictionary = {
	"bg_crates1": "За ящиками", "bg_crates2": "За ящиками", "bg_coffin": "За длинным ящиком",
	"bg_corner": "В углу за сеткой", "sl_end_corner": "В нише у умывальника", "end_corner": "В тёмном углу",
}
const BAY_PREFIXES: PackedStringArray = ["bay", "sl", "rb"]
const BAY_LABELS: Dictionary = {"bay": "Под полкой", "sl": "Под полкой купе", "rb": "Под столом"}
const MIN_GAP: float = 70.0
const PER_CARRIAGE: int = 4
const REACH: float = 24.0


## Список укрытий: [{id, carriage, pos (мир), label}].
static func build(layout: TrainLayout, case_data: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if case_data.get("hide_spots_off", false):
		return out
	var cand: Array[Dictionary] = []
	for cid in layout.carriage_ids:
		var x0: float = layout.offsets[cid]
		if layout.widths[cid] < 200.0:
			continue  # тамбур: прятаться негде
		# Нижние полки купе: одна на отсек.
		var bays: Dictionary = {}
		var spots: Dictionary = Db.layout(cid).get("spots", {})
		for sid: String in spots:
			var s: Dictionary = spots[sid]
			var spos := Vector2(x0 + float(s["pos"][0]), float(s["pos"][1]))
			if SPOT_LABELS.has(sid):
				cand.append({"carriage": cid, "pos": spos, "label": str(SPOT_LABELS[sid])})
				continue
			var bay: String = sid.get_slice("_", 0)
			var prefix: String = bay.rstrip("0123456789")
			if not prefix in BAY_PREFIXES or bay == prefix or str(s.get("pose", "")) != "sit" or bays.has(bay):
				continue
			bays[bay] = true
			cand.append({"carriage": cid, "pos": spos + Vector2(0, 6), "label": str(BAY_LABELS[prefix])})
		for p: Dictionary in Db.layout(cid).get("props", []):
			var kind: String = str(p.get("sprite", ""))
			if not PROPS.has(kind):
				continue
			var off: Vector2 = PROPS[kind][1]
			cand.append({"carriage": cid, "pos": Vector2(x0 + float(p["pos"][0]), float(p["pos"][1])) + off, "label": str(PROPS[kind][0])})
	for h: Dictionary in case_data.get("hide_spots", []):
		cand.append({"carriage": h["carriage"], "pos": Vector2(layout.offsets[h["carriage"]] + float(h["pos"][0]), float(h["pos"][1])), "label": str(h.get("label", "Укрытие")), "forced": true})
	var v := TrainValidator.new(layout)
	var ps: Dictionary = case_data.get("player_start", {})
	var start: Vector2 = Vector2(layout.offsets.get(ps.get("carriage", layout.carriage_ids[0]), 0.0) + float(ps.get("pos", [100, 160])[0]), float(ps.get("pos", [100, 160])[1]))
	v.flood(start)
	var per: Dictionary = {}
	for c: Dictionary in cand:
		if not v.can_reach(c["pos"], REACH):
			continue
		if not c.get("forced", false):
			if int(per.get(c["carriage"], 0)) >= PER_CARRIAGE:
				continue
			if out.any(func(o: Dictionary) -> bool: return (o["pos"] as Vector2).distance_to(c["pos"]) < MIN_GAP):
				continue
		per[c["carriage"]] = int(per.get(c["carriage"], 0)) + 1
		c["id"] = "hide_%d" % out.size()
		out.append(c)
	return out


## Ближайшее к точке укрытие (или {}).
static func nearest(spots: Array, p: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var bd: float = INF
	for s: Dictionary in spots:
		var d: float = (s["pos"] as Vector2).distance_to(p)
		if d < bd:
			bd = d
			best = s
	return best
