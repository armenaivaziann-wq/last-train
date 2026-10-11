class_name AdsService
extends RefCounted
## Реклама за награду. Пока заглушка: «просмотр» сразу успешен. Чтобы подключить рекламный
## SDK, замените тело show_rewarded(): показать ролик и вызвать on_done(true) только после
## полного просмотра (on_done(false) — если пропущен или не загрузился).

static var simulate_success: bool = true


static func show_rewarded(on_done: Callable) -> void:
	on_done.call(simulate_success)
