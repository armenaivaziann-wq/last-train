extends Node
## Сохранение профиля в user://last_train_save.json: валюта, прогрессия, коллекции,
## задания, настройки и снимок незавершённого дела. Менеджеры хранят свои разделы
## прямо в `profile` и вызывают save_game() после изменений.

const SAVE_PATH: String = "user://last_train_save.json"
const VERSION: int = 1

## Отключается в тестах, чтобы не трогать сохранение игрока.
var enabled: bool = true
var save_path: String = SAVE_PATH
var profile: Dictionary = {}
## Дело, которое надо запустить в game.tscn (выставляет меню перед сменой сцены).
var pending_case: String = ""
var pending_resume: bool = false


func _ready() -> void:
	load_game()


func default_profile() -> Dictionary:
	return {
		"version": VERSION,
		"economy": {"coins": 150, "crystals": 15, "reputation": 0},
		"carriages": ["passenger", "restaurant"],
		"equipment": {"magnifier": 1, "notebook": 1, "cameras": 1, "flashlight": 0, "recorder": 0, "badge": 0},
		"cosmetics": {"owned": ["detective", "lens_silver"], "outfit": "detective", "lens": "lens_silver"},
		"bestiary": {},
		"met": [],
		"archive": [],
		"stats": {},
		"quests": {"day": "", "daily": [], "week": "", "weekly": [], "claimed_achievements": [], "claimed_events": []},
		"settings": {"music": 0.7, "sfx": 0.9, "ambient": 0.7, "vibration": true},
		"case_progress": {},
	}


func load_game() -> void:
	profile = default_profile()
	if not enabled or not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_merge(profile, parsed)


func save_game() -> void:
	if not enabled:
		return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось записать сохранение: " + save_path)
		return
	file.store_string(JSON.stringify(profile, "\t"))


func reset_profile() -> void:
	profile = default_profile()
	save_game()
	Events.profile_changed.emit()


## Подмешивает сохранённые значения поверх значений по умолчанию (новые поля не теряются).
func _merge(base: Dictionary, loaded: Dictionary) -> void:
	for key: String in loaded:
		if base.has(key) and base[key] is Dictionary and loaded[key] is Dictionary:
			_merge(base[key], loaded[key])
		else:
			base[key] = loaded[key]


func section(key: String) -> Dictionary:
	return profile[key]


func setting(key: String) -> Variant:
	return profile["settings"].get(key)


func set_setting(key: String, value: Variant) -> void:
	profile["settings"][key] = value
	save_game()


# --- незавершённое дело --------------------------------------------------------------------
func has_case_progress() -> bool:
	var cp: Dictionary = profile.get("case_progress", {})
	return not cp.is_empty() and Db.has_case(str(cp.get("case_id", "")))


func store_case_progress(snapshot: Dictionary) -> void:
	profile["case_progress"] = snapshot
	save_game()


func clear_case_progress() -> void:
	profile["case_progress"] = {}
	save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()
