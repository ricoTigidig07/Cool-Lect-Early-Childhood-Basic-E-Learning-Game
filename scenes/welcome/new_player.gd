extends Control

## First-time screen: asks the child's age (4 and up), then gives them a username.
## Page 1 (AgePage): – [age] + and Next.  Page 2 (NamePage): the username + Shuffle + Let's Play.

const MAIN_MENU := "res://scenes/main_menu.tscn"
const MIN_AGE := 4

@onready var age_page: Control = $AgePage
@onready var name_page: Control = $NamePage
@onready var age_label: Label = $AgePage/AgePicker/AgeLabel
@onready var minus_button: Button = $AgePage/AgePicker/MinusButton
@onready var plus_button: Button = $AgePage/AgePicker/PlusButton
@onready var next_button: Button = $AgePage/NextButton
@onready var username_label: Label = $NamePage/Username
@onready var shuffle_button: Button = $NamePage/ShuffleButton
@onready var play_button: Button = $NamePage/PlayButton
@onready var back_button: Button = $NamePage/BackButton

var chosen_age := MIN_AGE

func _ready() -> void:
	minus_button.pressed.connect(_change_age.bind(-1))
	plus_button.pressed.connect(_change_age.bind(1))
	next_button.pressed.connect(_on_age_chosen)
	shuffle_button.pressed.connect(_shuffle)
	play_button.pressed.connect(_on_play)
	back_button.pressed.connect(_show_page.bind(age_page))
	_update_age()
	_show_page(age_page)

func _change_age(step: int) -> void:
	chosen_age = max(MIN_AGE, chosen_age + step)
	_update_age()
	_pop(age_label)

func _update_age() -> void:
	age_label.text = str(chosen_age)
	minus_button.disabled = chosen_age <= MIN_AGE

func _on_age_chosen() -> void:
	_shuffle()
	_show_page(name_page)

func _shuffle() -> void:
	username_label.text = PlayerProfile.make_username()
	_pop(username_label)

func _on_play() -> void:
	PlayerProfile.create_profile(chosen_age, username_label.text)
	get_tree().change_scene_to_file(MAIN_MENU)

func _show_page(page: Control) -> void:
	age_page.visible = page == age_page
	name_page.visible = page == name_page

func _pop(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	var t := create_tween()
	t.tween_property(node, "scale", Vector2.ONE * 1.15, 0.08)
	t.tween_property(node, "scale", Vector2.ONE, 0.1)
