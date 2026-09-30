extends Node2D

@export var mission_text: MissionTextData
## Which subject and level this scene is (used to save stars and open the next level).
@export_enum("fruits", "numbers", "alphabets", "animals", "shapes", "colors") var subject := "fruits"
@export var level := 1

func _ready() -> void:
	GameManager.set_current_level(subject, level)
	QuestManager.reset()
	if mission_text:
		GameUIManager.set_missions(mission_text.mission_1_text, mission_text.mission_2_text, mission_text.mission_3_text)
