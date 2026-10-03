extends Node
## Отладка: интервалы присутствия NPC в кадре каждой камеры (для настройки camera_clues).

func _ready() -> void:
	var c: Dictionary = Db.case_data("case_01")
	var tl := TrainLayout.build(PackedStringArray(c["carriages"]))
	var timeline := CaseTimeline.new(c, tl)
	var t0: float = Db.parse_time(c["history_start"])
	var t1: float = Db.parse_time(c["start"])
	for cam: Dictionary in tl.cameras:
		for npc in timeline.npc_ids():
			for iv: Array in timeline.presence(npc, cam["rect"], t0, t1, 1.0 / 60.0):
				print("%s %s %s - %s" % [cam["id"], npc, Db.format_time(iv[0], true), Db.format_time(iv[1], true)])
	get_tree().quit()
