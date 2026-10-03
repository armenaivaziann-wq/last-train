extends Node
## Валюты: монеты — обычные улучшения, кристаллы — косметика и редкие награды,
## репутация — открытие маршрутов. Покупки только за игровую валюту, без pay-to-win.

const CURRENCIES: PackedStringArray = ["coins", "crystals", "reputation"]


func _eco() -> Dictionary:
	return SaveManager.profile["economy"]


func amount(currency: String) -> int:
	return int(_eco().get(currency, 0))


func coins() -> int:
	return amount("coins")


func crystals() -> int:
	return amount("crystals")


func reputation() -> int:
	return amount("reputation")


func add(currency: String, value: int, save: bool = true) -> void:
	if not currency in CURRENCIES or value == 0:
		return
	_eco()[currency] = maxi(0, amount(currency) + value)
	if save:
		SaveManager.save_game()
	Events.profile_changed.emit()


func can_afford(currency: String, cost: int) -> bool:
	return amount(currency) >= cost


func spend(currency: String, cost: int) -> bool:
	if cost <= 0:
		return true
	if not can_afford(currency, cost):
		return false
	add(currency, -cost)
	return true


## Выдать пакет наград {"coins": 100, "crystals": 5, "reputation": 10}.
func grant(rewards: Dictionary) -> void:
	for currency: String in rewards:
		add(currency, int(rewards[currency]), false)
	SaveManager.save_game()
