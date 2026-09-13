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
