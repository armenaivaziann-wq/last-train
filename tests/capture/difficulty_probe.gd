extends "res://tests/test_levels.gd"
## Замер сложности авторских дел: решатель «как игрок» идёт по минутам и отмечает,
## когда против виновника набирается 3 доказанных основания, и какие улики называют
## виновника напрямую (одна улика — один подозреваемый, не вывод и не его собственная ложь).
## Запуск: Godot --headless --path . res://tests/capture/difficulty_probe.tscn


func _ready() -> void:
	SaveManager.enabled = false
	for lvl: String in ["level_01"] + AUTHORED:
		await _start_level(lvl, 7)
		var inv: InvestigationManager = _inv()
		var culprit: String = str(inv.data["culprit"])
		var refuted: Array = []
		for x: Dictionary in inv.data.get("deductions", []):
			refuted.append_array(x.get("refutes", []))
		var t3: float = -1.0
		var direct: Dictionary = {}
		while inv.clock < inv.arrival_time - 0.6:
			while _sweep():
				pass
			for id: String in inv.evidence.found:
				var c: Dictionary = inv.evidence.clue(id)
				if c.get("type") != "contradiction" and not id in refuted and c.get("points_to", []) == [culprit] and not direct.has(id):
					direct[id] = "%.1f" % (inv.clock - inv.start_time)
			if t3 < 0.0 and inv.proven_against(culprit, inv.evidence.found).size() >= 3:
				t3 = inv.clock - inv.start_time
			inv.advance(0.5)
		var sus: Array = inv.data["suspects"].filter(func(s: String) -> bool:
			return inv.evidence.found.any(func(id: String) -> bool: return s in inv.evidence.clue(id).get("points_to", [])))
		print("PROBE|%s|%s|%s|%s|%d|%d|%s|%s|%d" % [lvl, inv.data.get("title", ""), culprit, inv.data.get("monster", ""),
			int(inv.profile.get("level", 0)) if inv.profile.has("level") else 0, sus.size(), "%.1f" % t3,
			",".join(PackedStringArray(direct.keys().map(func(k: String) -> String: return "%s@%s" % [k, direct[k]]))), inv.data.get("puzzles", {}).size()])
		game.queue_free()
		game = null
		await wait_frames(2)
	get_tree().quit()
