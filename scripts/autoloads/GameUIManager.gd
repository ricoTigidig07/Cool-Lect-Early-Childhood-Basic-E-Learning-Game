extends Node

var dialogue_panel: PanelContainer

func register_ui(panel: PanelContainer) -> void:
	dialogue_panel = panel

func show_dialogue(text: String) -> void:
	dialogue_panel.visible = true
	dialogue_panel.set_text(text)
