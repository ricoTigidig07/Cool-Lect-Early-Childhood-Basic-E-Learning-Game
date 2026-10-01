extends Node

## Emitted when the Teacher starts the lesson (the player said "Yes").
signal started

@export var letter_order: Array[String] = []

var current_index: int = 0
var is_started: bool = false

func start() -> void:
	if is_started:
		return
	is_started = true
	started.emit()

func is_collectible(letter: String) -> bool:
	if not is_started or current_index >= letter_order.size():
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
