extends Control

## Main menu: the player left the practice yard before it was finished.
## Banban asks if they want to continue it.

const PRACTICE := "res://scenes/welcome/practice/practice_yard.tscn"

@onready var title: Label = $Card/Margin/Box/Title
@onready var text: Label = $Card/Margin/Box/Text
@onready var yes_button: Button = $Card/Margin/Box/Buttons/Yes
@onready var no_button: Button = $Card/Margin/Box/Buttons/No
@onready var anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	title.text = Lang.line("Continue the practice?")
	text.text = Lang.line("You left the practice before it was done. Do you want to finish it now?")
	yes_button.text = Lang.line("Let's go!")
	no_button.text = Lang.line("No, thanks.")
	yes_button.pressed.connect(_on_yes)
	no_button.pressed.connect(_on_no)
	anim.play("open")
	anim.animation_finished.connect(func(n): if n == &"open": anim.play("bob"))
	AudioManager.play_sfx("pop")


func _on_yes() -> void:
	AudioManager.play_sfx("pop")
	get_tree().change_scene_to_file(PRACTICE)


func _on_no() -> void:
	AudioManager.play_sfx("pop")
	PlayerProfile.set_practice_pending(false)
	anim.play("close")
	await anim.animation_finished
	queue_free()
