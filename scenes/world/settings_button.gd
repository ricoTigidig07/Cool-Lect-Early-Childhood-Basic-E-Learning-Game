extends Button

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	var settings_panel = get_tree().get_first_node_in_group("ingame_settings")
	if settings_panel:
		settings_panel.visible = true
		get_tree().paused = true
	else:
		push_warning("SettingsButton: no node found in group 'ingame_settings'")
