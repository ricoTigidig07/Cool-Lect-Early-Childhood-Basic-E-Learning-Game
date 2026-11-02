extends Control

## Main Menu > Credits.
## The "roll" animation scrolls the team up one by one, then shows everyone
## together. The credits song starts by itself (AudioManager, "credits" in the file name).

const MAIN_MENU := "res://scenes/main_menu.tscn"

@onready var anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"roll":
		anim.play(&"idle")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
