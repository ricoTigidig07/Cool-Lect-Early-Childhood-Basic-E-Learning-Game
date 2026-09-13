extends PanelContainer

@onready var slots_container = $MarginContainer/VBoxContainer

const SLOT_SCENE = preload("res://scenes/slot_container.tscn")

var item_icons: Dictionary = {
	"apple": preload("res://scenes/objects/icons/apple.tres")
}

var slot_instances: Dictionary = {}

func _ready() -> void:
	visible = false
	QuestManager.quest_updated.connect(_on_quest_updated)

func show_panel() -> void:
	print("ItemsPanel show_panel() called")
	_clear_slots()
	visible = true
	_sync_from_quest_manager()

func _sync_from_quest_manager() -> void:
	for item_type in QuestManager.target_counts.keys():
		var current = QuestManager.current_counts.get(item_type, 0)
		var target = QuestManager.target_counts[item_type]
		_on_quest_updated(item_type, current, target)

func hide_panel() -> void:
	visible = false

func _clear_slots() -> void:
	for child in slots_container.get_children():
		child.queue_free()
	slot_instances.clear()

func _on_quest_updated(item_type: String, current: int, target: int) -> void:
	if not slot_instances.has(item_type):
		_create_slot(item_type)
	var slot = slot_instances[item_type]
	slot.get_node("VBoxContainer/Label").text = "%d/%d" % [current, target]

func _create_slot(item_type: String) -> void:
	print("Creating slot for: ", item_type)
	var slot = SLOT_SCENE.instantiate()
	slots_container.add_child(slot)
	slot.get_node("VBoxContainer/TextureRect").texture = item_icons.get(item_type)
	slot_instances[item_type] = slot
