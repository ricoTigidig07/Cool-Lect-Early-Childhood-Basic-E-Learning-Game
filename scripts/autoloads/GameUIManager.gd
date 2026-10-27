extends Node

var dialogue_panel: TextureRect

## True once the level is finishing (last mission done, or the player chose to stop):
## the interaction button does nothing, so the conversation can't start over.
var level_over := false
var result_shown := false

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
	# a conversation that was closed early must not answer later conversations
	for c in dialogue_panel.finished.get_connections():
		dialogue_panel.finished.disconnect(c["callable"])
	for c in dialogue_panel.choice_selected.get_connections():
		dialogue_panel.choice_selected.disconnect(c["callable"])

func connect_dialogue_finished(callback: Callable) -> void:
	dialogue_panel.finished.connect(callback, CONNECT_ONE_SHOT)

func connect_choice_selected(callback: Callable) -> void:
	dialogue_panel.choice_selected.connect(callback, CONNECT_ONE_SHOT)

func show_choices(choices: Array[String]) -> void:
	dialogue_panel.show_choices(choices)

var mission_panel: PanelContainer

func register_mission_panel(panel: PanelContainer) -> void:
	mission_panel = panel
	level_over = false          # a new level has started
	result_shown = false

func complete_mission_1() -> void:
	mission_panel.complete_mission_1()

func complete_mission_2() -> void:
	mission_panel.complete_mission_2()

func complete_mission_3() -> void:
	level_over = true
	mission_panel.complete_mission_3()

## The player chose to stop early: the Mission Complete screen comes next.
func end_level() -> void:
	level_over = true
	
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

func register_mission_complete_panel(panel: Control) -> void:
	mission_complete_panel = panel
	mission_complete_panel.retry_pressed.connect(_on_mission_complete_retry)
	mission_complete_panel.next_level_pressed.connect(_on_mission_complete_next)
	mission_complete_panel.level_select_pressed.connect(_on_mission_complete_level_select)

## Shows the Mission Complete screen, awarding a star per completed mission.
## Stars are saved to the subject and level the player is in (set by level_missions.gd).
func show_mission_complete() -> void:
	if result_shown:
		return
	result_shown = true
	level_over = true
	var stars = mission_panel.get_completed_count()
	GameManager.set_level_result(GameManager.current_subject, GameManager.current_level, stars)
	mission_complete_panel.show_result(stars)

func _on_mission_complete_retry() -> void:
	await _let_touch_finish()
	get_tree().reload_current_scene()

## Opens the next level of the same subject, or the level map if this was the last one.
func _on_mission_complete_next() -> void:
	await _let_touch_finish()
	var level_map = load("res://scenes/levels/level_map.gd")
	var next_path: String = level_map.LEVEL_SCENES.get(GameManager.current_subject, {}).get(GameManager.current_level + 1, "")
	if next_path != "" and ResourceLoader.exists(next_path):
		get_tree().change_scene_to_file(next_path)
	else:
		_on_mission_complete_level_select()

## Goes back to the level map of the subject you were playing
## (e.g. alphabets -> scenes/levels/alphabets/alphabets_level_select.tscn).
func _on_mission_complete_level_select() -> void:
	await _let_touch_finish()
	var subject := GameManager.current_subject
	if subject == "":
		subject = "fruits"
	get_tree().change_scene_to_file("res://scenes/levels/%s/%s_level_select.tscn" % [subject, subject])

## On phones the finger is still on the button for a moment after the tap:
## change the scene a little later so the button isn't removed while it is being touched.
func _let_touch_finish() -> void:
	await get_tree().create_timer(0.12).timeout

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
		
func get_item_icon(item_type: String) -> Texture2D:
	if hotbar:
		return hotbar.get_icon(item_type)
	return null
