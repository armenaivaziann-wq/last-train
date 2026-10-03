class_name TrainLayout
extends RefCounted
## Раскладка поезда из данных (data/layout/*.json) без создания узлов: смещения вагонов,
## мировые координаты точек NPC, слотов багажа и областей камер. Используется и игрой,
## и хронологией дела, и тестами — геометрия берётся из одного источника.

const HEIGHT: float = 208.0

var carriage_ids: PackedStringArray = []
var offsets: Dictionary = {}       # id вагона → X начала
var widths: Dictionary = {}
var spots: Dictionary = {}         # id точки → {pos: Vector2, facing, pose, via (X или NAN)}
var slots: Dictionary = {}         # "вагон:слот" → Vector2
var cameras: Array[Dictionary] = []  # {id, name, rect: Rect2}
var corridor_y: float = 166.0
var width: float = 0.0


static func build(ids: PackedStringArray) -> TrainLayout:
	var tl := TrainLayout.new()
	tl.carriage_ids = ids
	var x: float = 0.0
	for cid in ids:
		var data: Dictionary = Db.layout(cid)
		tl.offsets[cid] = x
		var w: float = float(data["size"][0])
		tl.widths[cid] = w
		tl.corridor_y = float(data.get("corridor_y", tl.corridor_y))
		var spots_data: Dictionary = data.get("spots", {})
		for sid: String in spots_data:
			var s: Dictionary = spots_data[sid]
			var via: float = NAN
			if s.has("via"):
				via = float(s["via"]) + x
			tl.spots[sid] = {
				"pos": Vector2(float(s["pos"][0]) + x, float(s["pos"][1])),
				"facing": str(s.get("facing", "down")),
				"pose": str(s.get("pose", "stand")),
				"via": via,
				"carriage": cid,
			}
		var slot_data: Dictionary = data.get("luggage_slots", {})
		for slot_id: String in slot_data:
			tl.slots["%s:%s" % [cid, slot_id]] = Vector2(float(slot_data[slot_id][0]) + x, float(slot_data[slot_id][1]))
		for cam: Dictionary in data.get("cameras", []):
			var r: Array = cam["rect"]
			tl.cameras.append({"id": cam["id"], "name": cam["name"], "rect": Rect2(float(r[0]) + x, float(r[1]), float(r[2]), float(r[3]))})
		x += w
	tl.width = x
	return tl


func camera(id: String) -> Dictionary:
	for cam in cameras:
		if cam["id"] == id:
			return cam
	return {}


## В каком вагоне находится точка мира (по X).
func carriage_at(x: float) -> String:
	for cid in carriage_ids:
		if x >= offsets[cid] and x < offsets[cid] + widths[cid]:
			return cid
	return carriage_ids[0] if x < 0.0 else carriage_ids[carriage_ids.size() - 1]


func carriage_name(cid: String) -> String:
	return str(Db.layout(cid).get("name", cid))
