extends Control

func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://scenes/subject_selector.tscn")

func _on_characters_button_pressed():
	get_tree().change_scene_to_file("res://scenes/character_selector.tscn")

func _on_settings_button_pressed():
	get_tree().change_scene_to_file("res://scenes/settings.tscn")

func _on_credits_button_pressed():
	get_tree().change_scene_to_file("res://scenes/credits.tscn")
