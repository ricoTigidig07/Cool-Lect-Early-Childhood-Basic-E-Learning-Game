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
