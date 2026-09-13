extends Node

signal quest_updated(item_type: String, current: int, target: int)
signal quest_completed()

var active := false
var target_counts: Dictionary = {}
var current_counts: Dictionary = {}

func start_quest(targets: Dictionary) -> void:
	target_counts = targets.duplicate()
	current_counts.clear()
	active = true
	for item_type in target_counts.keys():
		current_counts[item_type] = 0
		quest_updated.emit(item_type, 0, target_counts[item_type])

func collect_item(item_type: String) -> void:
	if not active or not target_counts.has(item_type):
		return
	current_counts[item_type] = min(current_counts[item_type] + 1, target_counts[item_type])
	quest_updated.emit(item_type, current_counts[item_type], target_counts[item_type])
	if _is_quest_complete():
		active = false
		quest_completed.emit()

func _is_quest_complete() -> bool:
	for item_type in target_counts.keys():
		if current_counts[item_type] < target_counts[item_type]:
			return false
	return true
