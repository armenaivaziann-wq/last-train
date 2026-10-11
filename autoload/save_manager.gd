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
## Уровень кампании ("level_01"... или "daily") и seed попытки (−1 — выбрать новый).
var pending_level: String = ""
var pending_seed: int = -1


## Подготовить запуск уровня кампании (новая попытка — новый seed, вариант дела меняется).
func prepare_level(level_id: String) -> void:
	var lvl: Dictionary = Db.level(level_id)
	pending_level = level_id
	pending_case = Db.level_case_ref(lvl)
	pending_seed = randi() % 1000000
	pending_resume = false
	clear_case_progress()


## Дело дня: одинаковый seed для всех в этот день, злодей — из открытых уровней.
func prepare_daily() -> void:
	var day: String = Time.get_date_string_from_system()
	var seed_value: int = absi(hash("daily:" + day)) % 1000000
	var unlocked: int = int(profile["campaign"]["unlocked"])
	var pool: Array = Db.levels().slice(0, maxi(1, mini(unlocked, Db.levels().size())))
	var lvl: Dictionary = pool[seed_value % pool.size()]
	pending_level = "daily"
	pending_case = "gen:" + str(lvl["villain"])
	pending_seed = seed_value
	pending_resume = false
	clear_case_progress()


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
		"settings": {"music": 0.7, "sfx": 0.9, "ambient": 0.7, "vibration": true, "difficulty": "normal"},
		"case_progress": {},
		# Билеты (жизни): старые профили получают полные 5 при слиянии с этими значениями.
		"tickets": {"count": 5, "ts": 0, "full": false},
		# Кампания: доступ к сюжетным делам не зависит от монет и репутации.
		"campaign": {"unlocked": 1, "stars": {}, "best_time": {}, "rewarded_stars": {}, "attempts": {},
			"disguises": {}, "daily": {"day": "", "best_stars": 0}},
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
		_migrate(parsed)
		_merge(profile, parsed)


## Миграции старых сохранений (до слияния со значениями по умолчанию).
func _migrate(loaded: Dictionary) -> void:
	# Сложность появилась позже: у игроков со старым прогрессом — Лёгкий, чтобы не сломать им игру.
	if loaded.has("settings") and loaded["settings"] is Dictionary and not loaded["settings"].has("difficulty"):
		loaded["settings"]["difficulty"] = "easy"


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
	var cid: String = str(cp.get("case_id", ""))
	return not cp.is_empty() and (cid.begins_with("gen:") or Db.has_case(cid))


func store_case_progress(snapshot: Dictionary) -> void:
	profile["case_progress"] = snapshot
	save_game()


func clear_case_progress() -> void:
	profile["case_progress"] = {}
	save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()
