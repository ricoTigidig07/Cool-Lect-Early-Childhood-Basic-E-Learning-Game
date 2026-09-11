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

func set_mission_text(text: String) -> void:
	mission_panel.set_mission(text)
