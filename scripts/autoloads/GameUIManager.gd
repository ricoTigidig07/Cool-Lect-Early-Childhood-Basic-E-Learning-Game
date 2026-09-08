extends Node

var dialogue_panel: TextureRect

func register_ui(panel: TextureRect) -> void:
	dialogue_panel = panel

func show_dialogue(text: String) -> void:
	dialogue_panel.visible = true
	dialogue_panel.set_text(text)

func hide_dialogue() -> void:
	dialogue_panel.visible = false
