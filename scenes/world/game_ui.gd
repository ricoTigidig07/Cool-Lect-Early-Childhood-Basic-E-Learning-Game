extends CanvasLayer

func _ready():
	GameUIManager.register_ui($DialoguePanel)
	GameUIManager.register_mission_panel($MissionPanel)
	GameUIManager.set_mission_text("Talk to the Merchant!")
