extends Node
## Сколько укрытий в составе каждого дела (по вагонам).
func _ready() -> void:
	for l: Dictionary in Db.levels():
		var cid: String = str(l.get("case", "gen"))
		if cid == "gen":
			cid = "case_01"
		var d: Dictionary = Db.resolve_case(cid, 7)
		var lay := TrainLayout.build(PackedStringArray(d["carriages"]))
		var hs: Array[Dictionary] = HideSpots.build(lay, d)
		var per: Dictionary = {}
		for h in hs:
			per[h["carriage"]] = per.get(h["carriage"], []) + [h["label"]]
		print("HIDE|", l["id"], "|", per)
	get_tree().quit()
