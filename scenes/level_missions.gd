extends Node2D

@export var mission_text: MissionTextData

func _ready() -> void:
	if mission_text:
		GameUIManager.set_missions(mission_text.mission_1_text, mission_text.mission_2_text, mission_text.mission_3_text)
