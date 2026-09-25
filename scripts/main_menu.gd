extends Control

## Main menu.
## All animations live in the AnimationPlayer nodes (edit them in the Animation panel):
##   AnimationPlayer: intro, open_subjects, close_subjects
##   IdleAnimation:   idle_loop  (title wave + Play button breathing, autoplays)
## The living background is scenes/main_menu/menu_background.tscn.

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var subject_selector: Control = $SubjectSelector

func _ready() -> void:
	for b in [$ButtonRow/CharactersButton, $ButtonRow/SettingsButton, $ButtonRow/CreditsButton]:
		b.pivot_offset = b.size / 2.0
		b.mouse_entered.connect(_squish.bind(b, 1.06))
		b.mouse_exited.connect(_squish.bind(b, 1.0))
		b.button_down.connect(_squish.bind(b, 0.94))
	anim.play("intro")

func _squish(b: Button, amount: float) -> void:
	create_tween().tween_property(b, "scale", Vector2.ONE * amount, 0.08)

func _on_play_button_pressed() -> void:
	# fades the menu out and calls SubjectSelector.open() (the blind drops down)
	anim.play("open_subjects")

func _on_subject_selector_closed() -> void:
	anim.play("close_subjects")

func _on_characters_button_pressed():
	get_tree().change_scene_to_file("res://scenes/character_selector.tscn")

func _on_settings_button_pressed():
	get_tree().change_scene_to_file("res://scenes/settings.tscn")

func _on_credits_button_pressed():
	get_tree().change_scene_to_file("res://scenes/credits.tscn")
