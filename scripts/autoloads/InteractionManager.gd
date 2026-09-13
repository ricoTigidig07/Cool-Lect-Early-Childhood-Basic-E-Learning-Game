extends Node

var nearby_interactables: Array = []
var pending_tap_target: Node = null

func register(interactable: Node) -> void:
	if not nearby_interactables.has(interactable):
		nearby_interactables.append(interactable)

func unregister(interactable: Node) -> void:
	nearby_interactables.erase(interactable)
	if interactable.has_method("cancel_hold"):
		interactable.cancel_hold()
	if pending_tap_target == interactable:
		pending_tap_target = null

func get_current_target() -> Node:
	if nearby_interactables.is_empty():
		return null
	return nearby_interactables[0]

func button_down() -> void:
	var target = get_current_target()
	if target == null:
		return
	if target.has_method("start_hold"):
		target.start_hold()
	else:
		pending_tap_target = target

func button_up() -> void:
	var target = get_current_target()
	if target and target.has_method("cancel_hold"):
		target.cancel_hold()
	if pending_tap_target != null:
		pending_tap_target.interact()
		pending_tap_target = null
