extends TextureRect

@onready var label = $MarginContainer/VBoxContainer/Label
@onready var skip_button = $MarginContainer/VBoxContainer/ButtonArea/SkipButton
@onready var next_button = $MarginContainer/VBoxContainer/ButtonArea/NextButton
@onready var choices_container = $ChoicesContainer

const CHARS_PER_SECOND = 30.0

var typing_timer: Timer
var full_text: String = ""

signal skipped
signal advanced
signal choice_selected(choice_text: String)

func _ready() -> void:
	typing_timer = Timer.new()
	typing_timer.wait_time = 1.0 / CHARS_PER_SECOND
	typing_timer.timeout.connect(_on_typing_tick)
	add_child(typing_timer)

	skip_button.pressed.connect(_on_skip_pressed)
	next_button.pressed.connect(_on_next_pressed)

	choices_container.visible = false

func set_text(text: String) -> void:
	full_text = text
	label.text = text
	label.visible_characters = 0
	choices_container.visible = false
	_clear_choices()
	typing_timer.start()

func show_choices(choices: Array[String]) -> void:
	_clear_choices()
	for choice_text in choices:
		var btn = Button.new()
		btn.text = choice_text
		btn.pressed.connect(_on_choice_pressed.bind(choice_text))
		choices_container.add_child(btn)
	choices_container.visible = true

func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()

func _on_typing_tick() -> void:
	label.visible_characters += 1
	if label.visible_characters >= full_text.length():
		typing_timer.stop()

func _on_skip_pressed() -> void:
	label.visible_characters = -1
	typing_timer.stop()
	skipped.emit()

func _on_next_pressed() -> void:
	advanced.emit()

func _on_choice_pressed(choice_text: String) -> void:
	choices_container.visible = false
	choice_selected.emit(choice_text)
