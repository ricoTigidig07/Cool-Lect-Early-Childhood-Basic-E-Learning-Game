extends CanvasLayer

func _ready():
	GameUIManager.register_ui($DialoguePanel)
	GameUIManager.register_mission_panel($MissionPanel)
	GameUIManager.register_items_panel($ItemsPanel)
	GameUIManager.set_missions(
		"Talk to the Merchant!",
		"Collect apples for the Merchant!",
		"Deliver apples to the Merchant!"
)
