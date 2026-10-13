class_name Interactable
extends Node2D
## Точка взаимодействия: объект, багаж, пассажир, пульт камер, дверь или укрытие.
## Игрок выбирает ближайшую точку перед собой; подпись показывается на контекстной кнопке.

enum Kind { OBJECT, LUGGAGE, NPC, MONITOR, DOOR, HIDE }

@export var interact_id: String = ""
@export var label: String = "Осмотреть"
@export var kind: Kind = Kind.OBJECT
## Владелец (для багажа и пассажиров).
@export var owner_id: String = ""
@export var radius: float = 26.0
## Нельзя осмотреть в темноте туннеля без фонарика.
@export var needs_light: bool = true

var enabled: bool = true
## Был ли объект уже осмотрен (маркер становится тусклее).
var inspected: bool = false


func _ready() -> void:
	add_to_group(&"interactables")


func interact_position() -> Vector2:
	return global_position


func icon_name() -> String:
	match kind:
		Kind.NPC:
			return "talk"
		Kind.LUGGAGE:
			return "suitcase"
		Kind.MONITOR:
			return "cctv"
		Kind.DOOR:
			return "lock"
		Kind.HIDE:
			return "eye"
	return "magnifier"
