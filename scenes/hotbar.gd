extends PanelContainer

@onready var slots_container: HBoxContainer = $MarginContainer/HBoxContainer
@onready var selector: TextureRect = %Selector

const SELECTOR_SIZE := Vector2(70, 70)
var selected_slot: Button = null

var item_icons: Dictionary = {
	"seed": preload("res://scenes/objects/icons/seed_icon.tres"),
}

var slot_by_item: Dictionary = {}
var equipped_item: String = ""

func _ready() -> void:
	selector.size = SELECTOR_SIZE
	for slot in slots_container.get_children():
		slot.pressed.connect(_on_slot_pressed.bind(slot))
	await get_tree().process_frame
	_select_slot(slots_container.get_child(0))

func give_item(item_type: String, count: int) -> void:
	var slot = slot_by_item.get(item_type)
	if slot == null:
		slot = _find_empty_slot()
		if slot == null:
			return
		slot_by_item[item_type] = slot
	slot.get_node("TextureRect").texture = item_icons.get(item_type)
	slot.get_node("Label").text = str(count)
	if slot == selected_slot:
		_select_slot(slot)

func _find_empty_slot() -> Node:
	for child in slots_container.get_children():
		if child is Button and not slot_by_item.values().has(child):
			return child
	return null

func _on_slot_pressed(slot: Button) -> void:
	_select_slot(slot)

func _select_slot(slot: Button) -> void:
	selected_slot = slot
	var item_type = ""
	for key in slot_by_item.keys():
		if slot_by_item[key] == slot:
			item_type = key
			break
	equipped_item = item_type

	selector.visible = true
	var slot_center = slot.global_position + slot.size / 2.0
	selector.global_position = slot_center - SELECTOR_SIZE / 2.0

func consume_item(item_type: String) -> void:
	var slot = slot_by_item.get(item_type)
	if slot == null:
		return
	var current_count = int(slot.get_node("Label").text)
	current_count = max(current_count - 1, 0)
	if current_count == 0:
		slot.get_node("TextureRect").texture = null
		slot.get_node("Label").text = ""
		slot_by_item.erase(item_type)
	else:
		slot.get_node("Label").text = str(current_count)
