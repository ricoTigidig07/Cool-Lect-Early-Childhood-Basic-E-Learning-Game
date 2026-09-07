extends Node

var dialogue_panel: PanelContainer

func register_ui(panel: PanelContainer) -> void:
	dialogue_panel = panel

func show_dialogue(text: String) -> void:
	dialogue_panel.visible = true
	dialogue_panel.set_text(text)

func hide_dialogue() -> void:
	dialogue_panel.visible = false

var mission_panel: MissionPanel

func register_mission_panel(panel) -> void:
	mission_panel = panel

func set_mission_text(text: String) -> void:
	mission_panel.set_mission(text)
