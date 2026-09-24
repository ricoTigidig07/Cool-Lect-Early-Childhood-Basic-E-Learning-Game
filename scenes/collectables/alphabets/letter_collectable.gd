extends CollectableComponent
class_name LetterCollectible

@export var letter_sequence: NodePath

func interact() -> void:
	var seq = get_node_or_null(letter_sequence)
	if seq and not seq.is_collectible(item_type):
		return
	super.interact()

func _finish_collect() -> void:
	GameUIManager.give_hotbar_item(item_type, 1)
	collected.emit(collectable_name, item_type)
	queue_free()
