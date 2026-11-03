extends CanvasLayer

func _ready():
	GameUIManager.register_ui($DialoguePanel)
	GameUIManager.register_mission_panel($MissionPanel)
	GameUIManager.register_mission_complete_panel($MissionCompletePanel)
	GameUIManager.register_hotbar($Hotbar)
