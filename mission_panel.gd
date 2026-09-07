class_name MissionPanel
extends PanelContainer

@onready var label: Label = $MissionLabel

func set_mission(text: String) -> void:
	label.text = text

func clear_mission() -> void:
	label.text = ""
