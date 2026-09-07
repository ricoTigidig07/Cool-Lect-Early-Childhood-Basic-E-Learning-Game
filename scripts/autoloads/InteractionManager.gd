extends Node

var nearby_interactables: Array = []

func register(interactable: Node) -> void:
	if not nearby_interactables.has(interactable):
		nearby_interactables.append(interactable)

func unregister(interactable: Node) -> void:
	nearby_interactables.erase(interactable)

func interact() -> void:
	if nearby_interactables.is_empty():
		return
	# interact with the first (or closest, if we add distance checks later)
	var target = nearby_interactables[0]
	target.interact()
