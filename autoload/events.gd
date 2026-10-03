extends Node
## Шина сквозных событий. Только то, что слушают несколько несвязанных систем
## (задания, достижения, звук, уведомления). Остальное — прямые вызовы и сигналы узлов.

## Найдена улика или сделан вывод (id из данных дела).
signal clue_found(clue_id: String)
## Прирост игровой статистики (для заданий и достижений): clues, docs, luggage, talks...
signal stat_added(stat: String, amount: int)
## Всплывающее уведомление в HUD.
signal toast(text: String, icon: String)
## Дело завершено (result — словарь итогов, см. InvestigationManager.finish).
signal case_finished(result: Dictionary)
## Изменилась валюта или прогресс — интерфейсы обновляют счётчики.
signal profile_changed


func add_stat(stat: String, amount: int = 1) -> void:
	stat_added.emit(stat, amount)


func notify(text: String, icon: String = "") -> void:
	toast.emit(text, icon)
