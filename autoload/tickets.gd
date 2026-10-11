class_name Tickets
extends RefCounted
## Билеты (жизни). У игрока до 5 билетов; билет тратится, только когда дело проиграно (монстр
## сбежал по дедлайну или после второй ошибки обвинения). Вход в дело и победа билет не тратят.
## Восстановление: 1 билет каждые 30 минут реального времени, до 5. Считается по сохранённой
## метке времени (в профиле), а не по кадрам — поэтому идёт и при закрытой игре.
## Защита от перевода часов: если время устройства меньше прошлой метки — билеты не начисляются,
## метка сдвигается на «сейчас» (отсчёт начинается заново).
## «Дело дня» и обучающее первое дело билетов не требуют. «Полная версия» — бесконечные билеты.

const MAX: int = 5
const REGEN_SECONDS: int = 1800
const REFILL_CRYSTALS: int = 20
const FREE_LEVELS: PackedStringArray = ["level_01", "daily", ""]

## Подмена часов в тестах (секунды Unix). −1 — системное время.
static var clock_override: int = -1


static func now() -> int:
	return clock_override if clock_override >= 0 else int(Time.get_unix_time_from_system())


static func _data() -> Dictionary:
	if not SaveManager.profile.has("tickets"):
		SaveManager.profile["tickets"] = {"count": MAX, "ts": now(), "full": false}
	return SaveManager.profile["tickets"]


static func full_version() -> bool:
	return bool(_data().get("full", false))


## Пересчитать восстановление и вернуть текущее число билетов.
static func count() -> int:
	refresh()
	return int(_data()["count"])


static func refresh() -> void:
	var d: Dictionary = _data()
	var t: int = now()
	var ts: int = int(d.get("ts", t))
	if t < ts:
		# Часы перевели назад: не начисляем, отсчёт — с текущего момента.
		d["ts"] = t
		return
	if int(d["count"]) >= MAX:
		d["ts"] = t
		return
	var gained: int = (t - ts) / REGEN_SECONDS
	if gained > 0:
		var before: int = int(d["count"])
		d["count"] = mini(MAX, before + gained)
		d["ts"] = t if int(d["count"]) >= MAX else ts + gained * REGEN_SECONDS
		if int(d["count"]) >= MAX and before < MAX:
			_on_full()


## Секунд до следующего билета (0 — билетов полно).
static func seconds_to_next() -> int:
	refresh()
	var d: Dictionary = _data()
	if int(d["count"]) >= MAX:
		return 0
	return maxi(0, REGEN_SECONDS - (now() - int(d["ts"])))


static func format_wait(seconds: int) -> String:
	return "%02d:%02d:%02d" % [seconds / 3600, (seconds % 3600) / 60, seconds % 60]


static func required(level_id: String) -> bool:
	return not level_id in FREE_LEVELS and not full_version()


static func can_start(level_id: String) -> bool:
	return not required(level_id) or count() > 0


## Проигранное дело: монстр сбежал. Возвращает true, если билет списан.
static func spend_for_loss(level_id: String) -> bool:
	if not required(level_id):
		return false
	refresh()
	var d: Dictionary = _data()
	if int(d["count"]) <= 0:
		return false
	if int(d["count"]) >= MAX:
		d["ts"] = now()   # отсчёт восстановления начинается с первой потери
	d["count"] = int(d["count"]) - 1
	SaveManager.save_game()
	return true


static func add(n: int) -> void:
	var d: Dictionary = _data()
	d["count"] = mini(MAX, int(d["count"]) + n)
	if int(d["count"]) >= MAX:
		d["ts"] = now()
	SaveManager.save_game()


## Восполнить все билеты за кристаллы.
static func refill_for_crystals() -> bool:
	if not EconomyManager.spend("crystals", REFILL_CRYSTALS):
		return false
	add(MAX)
	return true


static func unlock_full_version() -> void:
	_data()["full"] = true
	SaveManager.save_game()


## Хук локального уведомления «Билеты восстановлены». Уведомлений в проекте пока нет:
## при подключении плагина уведомлений планировать его здесь (на момент seconds_to_next()).
static func _on_full() -> void:
	pass
