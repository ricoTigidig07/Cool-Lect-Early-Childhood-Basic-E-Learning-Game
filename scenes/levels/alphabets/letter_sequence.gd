extends Node

@export var letter_order: Array[String] = []

var current_index: int = 0

func is_collectible(letter: String) -> bool:
	if current_index >= letter_order.size():
		return false
	return letter.to_upper() == letter_order[current_index]

func current_letter() -> String:
	if current_index < letter_order.size():
		return letter_order[current_index]
	return ""

func advance() -> void:
	current_index += 1

func is_complete() -> bool:
	return current_index >= letter_order.size()
