extends CollectableComponent
class_name HotbarCollectable

## A pickup that goes into the Hotbar (stacking +1 each time)
## instead of reporting to QuestManager. Used by eggs in Numbers.

func _init() -> void:
	uses_hotbar = true      # goes into the bag

func _finish_collect() -> void:
	GameUIManager.give_hotbar_item(item_type, 1)
	collected.emit(collectable_name, item_type)
	queue_free()
