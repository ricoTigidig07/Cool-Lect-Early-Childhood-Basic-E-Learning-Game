extends Control

func _on_fruits_card_pressed():
	get_tree().change_scene_to_file("res://scenes/levels/fruits/fruits_level_select.tscn")

func _on_numbers_card_pressed():
	get_tree().change_scene_to_file("res://scenes/levels/numbers/numbers_level_select.tscn")

func _on_alphabets_card_pressed():
	get_tree().change_scene_to_file("res://scenes/levels/alphabets/alphabets_level_select.tscn")

func _on_animals_card_pressed():
	get_tree().change_scene_to_file("res://scenes/levels/animals/animals_level_select.tscn")

func _on_shapes_card_pressed():
	get_tree().change_scene_to_file("res://scenes/levels/shapes/shapes_level_select.tscn")

func _on_colors_card_pressed():
	get_tree().change_scene_to_file("res://scenes/levels/colors/colors_level_select.tscn")
