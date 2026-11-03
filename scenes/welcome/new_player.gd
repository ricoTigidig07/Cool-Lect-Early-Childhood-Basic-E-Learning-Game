extends Control

## First-time screen: the language, the child's age (4 and up), then a username.
## Page 1 (LanguagePage): English / Tagalog / Bisaya.  Page 2 (AgePage): – [age] + and Next.
## Page 3 (NamePage): the username + Shuffle + Let's Play.
## Page 4 (TutorialPage): Banban, the player's bunny, says hi and shows how to play,
## then the practice yard (try the controls for real) or the main menu opens.

const MAIN_MENU := "res://scenes/main_menu.tscn"
const PRACTICE_YARD := "res://scenes/welcome/practice/practice_yard.tscn"
const MIN_AGE := 4
const KEYBOARD_GAP := 16.0      # space between the name box and the phone keyboard

@onready var language_page: Control = $LanguagePage
@onready var age_page: Control = $AgePage
@onready var name_page: Control = $NamePage
@onready var age_label: Label = $AgePage/Center/AgePicker/AgeLabel
@onready var minus_button: Button = $AgePage/Center/AgePicker/MinusButton
@onready var plus_button: Button = $AgePage/Center/AgePicker/PlusButton
@onready var next_button: Button = $AgePage/Center/NextButton
@onready var username_label: LineEdit = $NamePage/Center/Username
@onready var shuffle_button: Button = $NamePage/Center/ShuffleButton
@onready var play_button: Button = $NamePage/Center/PlayButton
@onready var back_button: Button = $NamePage/BackButton
@onready var name_box: Control = $NamePage/Center
@onready var tutorial_page: Control = $TutorialPage

var chosen_age := MIN_AGE
var keyboard_lift := 0.0        # how far the name page is moved up for the keyboard

func _ready() -> void:
	minus_button.pressed.connect(_change_age.bind(-1))
	plus_button.pressed.connect(_change_age.bind(1))
	next_button.pressed.connect(_on_age_chosen)
	shuffle_button.pressed.connect(_shuffle)
	play_button.pressed.connect(_on_play)
	back_button.pressed.connect(func():
		username_label.unedit()
		_show_page(age_page))
	for pair in [["English", "en"], ["Tagalog", "tl"], ["Bisaya", "ceb"]]:
		get_node("LanguagePage/Center/" + pair[0]).pressed.connect(_on_language_chosen.bind(pair[1]))
	$AgePage/BackButton.pressed.connect(func(): _show_page(language_page))
	_update_age()
	_show_page(language_page)
	username_label.text_changed.connect(_on_name_typed)
	username_label.text_submitted.connect(func(_t): _on_play())

## Phones: the on-screen keyboard covers the bottom of the screen,
## so slide the name page up until the name box sits just above it.
func _process(delta: float) -> void:
	var target := 0.0
	if name_page.visible and username_label.has_focus():
		var kb_px := float(DisplayServer.virtual_keyboard_get_height())
		if kb_px > 0.0:
			var view_h := get_viewport_rect().size.y
			var kb_h := kb_px * view_h / float(DisplayServer.window_get_size().y)
			var box_bottom := username_label.get_global_rect().end.y + keyboard_lift
			target = max(0.0, box_bottom + KEYBOARD_GAP - (view_h - kb_h))
	keyboard_lift = lerp(keyboard_lift, target, min(1.0, delta * 12.0))
	name_box.position.y = -360.0 + (name_box.get_parent_area_size().y / 2.0) - keyboard_lift

func _on_language_chosen(code: String) -> void:
	Lang.set_language(code)
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
	await get_tree().process_frame
	# start typing right away: pops up the virtual keyboard on phones/tablets
	username_label.grab_focus()
	username_label.edit()

func _shuffle() -> void:
	username_label.text = PlayerProfile.make_username()
	_pop(username_label)

func _on_play() -> void:
	if tutorial_page.visible:
		return          # already started (Enter + button)
	var name_text := username_label.text.strip_edges()
	if name_text == "":
		_pop(username_label)
		return
	username_label.unedit()          # hides the virtual keyboard
	PlayerProfile.create_profile(chosen_age, name_text)
	_show_page(tutorial_page)
	tutorial_page.start()
	var practice: bool = await tutorial_page.done
	get_tree().change_scene_to_file(PRACTICE_YARD if practice else MAIN_MENU)

func _show_page(page: Control) -> void:
	language_page.visible = page == language_page
	age_page.visible = page == age_page
	name_page.visible = page == name_page
	tutorial_page.visible = page == tutorial_page

func _pop(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	var t := create_tween()
	t.tween_property(node, "scale", Vector2.ONE * 1.15, 0.08)
	t.tween_property(node, "scale", Vector2.ONE, 0.1)
	
func _on_name_typed(new_text: String) -> void:
	var clean := ""
	for c in new_text:
		if c.is_valid_identifier() or c.is_valid_int():
			clean += c
	if clean != new_text:
		var caret := username_label.caret_column
		username_label.text = clean
		username_label.caret_column = min(caret, clean.length())
