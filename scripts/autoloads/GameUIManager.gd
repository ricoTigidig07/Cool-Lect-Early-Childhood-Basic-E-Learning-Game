extends Node

var dialogue_panel: TextureRect

func register_ui(panel: TextureRect) -> void:
	dialogue_panel = panel

func show_dialogue(text) -> void:
	dialogue_panel.visible = true
	if text is Array:
		var typed_pages: Array[String] = []
		for line in text:
			typed_pages.append(str(line))
		dialogue_panel.show_pages(typed_pages)
	else:
		dialogue_panel.set_text(text)

func hide_dialogue() -> void:
	dialogue_panel.visible = false

func connect_dialogue_finished(callback: Callable) -> void:
	dialogue_panel.finished.connect(callback, CONNECT_ONE_SHOT)

func connect_choice_selected(callback: Callable) -> void:
	dialogue_panel.choice_selected.connect(callback, CONNECT_ONE_SHOT)

func show_choices(choices: Array[String]) -> void:
	dialogue_panel.show_choices(choices)

var mission_panel: PanelContainer

func register_mission_panel(panel: PanelContainer) -> void:
	mission_panel = panel

func complete_mission_1() -> void:
	mission_panel.complete_mission_1()

func complete_mission_2() -> void:
	mission_panel.complete_mission_2()

func complete_mission_3() -> void:
	mission_panel.complete_mission_3()
	
var items_panel: PanelContainer

func register_items_panel(panel: PanelContainer) -> void:
	items_panel = panel

func show_items_panel() -> void:
	items_panel.show_panel()

func hide_items_panel() -> void:
	items_panel.hide_panel()

func set_missions(text_1: String, text_2: String, text_3: String) -> void:
	mission_panel.set_missions(text_1, text_2, text_3)

var mission_complete_panel: Control

# TODO: replace with real per-level subject/number once level select actually
# loads game scenes with that context. Hardcoded since "fruits" level 1 is the
# only level currently wired up end-to-end.
const CURRENT_SUBJECT := "fruits"
const CURRENT_LEVEL := 1
const LEVEL_SELECT_SCENE := "res://scenes/levels/fruits/fruits_level_select.tscn"

func register_mission_complete_panel(panel: Control) -> void:
	mission_complete_panel = panel
	mission_complete_panel.retry_pressed.connect(_on_mission_complete_retry)
	mission_complete_panel.next_level_pressed.connect(_on_mission_complete_next)
	mission_complete_panel.level_select_pressed.connect(_on_mission_complete_level_select)

## Shows the Mission Complete screen, awarding a star per completed mission.
func show_mission_complete() -> void:
	var stars = mission_panel.get_completed_count()
	GameManager.set_level_result(CURRENT_SUBJECT, CURRENT_LEVEL, stars)
	mission_complete_panel.show_result(stars)

func _on_mission_complete_retry() -> void:
	get_tree().reload_current_scene()

func _on_mission_complete_next() -> void:
	# TODO: point at the actual next level scene once Level 2 exists.
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)

func _on_mission_complete_level_select() -> void:
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)

var hotbar: PanelContainer

func register_hotbar(bar: PanelContainer) -> void:
	hotbar = bar

func give_hotbar_item(item_type: String, count: int) -> void:
	hotbar.give_item(item_type, count)

func get_equipped_item() -> String:
	if hotbar:
		return hotbar.equipped_item
	return ""

func consume_hotbar_item(item_type: String) -> void:
	if hotbar:
		hotbar.consume_item(item_type)
