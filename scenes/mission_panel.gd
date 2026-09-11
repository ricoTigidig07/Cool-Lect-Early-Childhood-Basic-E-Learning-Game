extends PanelContainer

@onready var label = $MarginContainer/Label

func set_mission(text: String) -> void:
	label.text = text

func clear_mission() -> void:
	label.text = ""
