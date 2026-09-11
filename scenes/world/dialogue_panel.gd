extends TextureRect

@onready var label = $MarginContainer/VBoxContainer/Label
@onready var skip_button = $MarginContainer/VBoxContainer/ButtonArea/SkipButton
@onready var next_button = $MarginContainer/VBoxContainer/ButtonArea/NextButton
@onready var choices_container = $ChoicesContainer

const CHARS_PER_SECOND = 30.0
const MIN_FONT_SIZE = 16
const MAX_FONT_SIZE = 30
const LABEL_WRAP_WIDTH = 950.0
const LABEL_WRAP_HEIGHT = 190.0

var typing_timer: Timer
var full_text: String = ""
var pages: Array[String] = []
var current_page: int = 0

signal skipped
signal advanced
signal finished
signal choice_selected(choice_text: String)

func _ready() -> void:
	label.custom_minimum_size = Vector2(LABEL_WRAP_WIDTH, LABEL_WRAP_HEIGHT)

	typing_timer = Timer.new()
	typing_timer.wait_time = 1.0 / CHARS_PER_SECOND
	typing_timer.timeout.connect(_on_typing_tick)
	add_child(typing_timer)

	skip_button.pressed.connect(_on_skip_pressed)
	next_button.pressed.connect(_on_next_pressed)

	choices_container.visible = false

func set_text(text: String) -> void:
	show_pages([text])

func show_pages(new_pages: Array[String]) -> void:
	pages = new_pages
	current_page = 0
	_show_current_page()

func _show_current_page() -> void:
	var text = pages[current_page]
	full_text = text
	_apply_responsive_font_size(text)
	label.text = text
	label.visible_characters = 0
	choices_container.visible = false
	_clear_choices()
	skip_button.text = "SKIP"
	skip_button.visible = true
	next_button.visible = true
	typing_timer.start()

func _apply_responsive_font_size(text: String) -> void:
	var font = label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
		print("FONT IS NULL - using fallback")
	else:
		print("Font found: ", font)

	var wrap_width = LABEL_WRAP_WIDTH
	var available_height = LABEL_WRAP_HEIGHT

	var best_size = MIN_FONT_SIZE
	for size in range(MAX_FONT_SIZE, MIN_FONT_SIZE - 1, -1):
		var wrapped_size = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, wrap_width, size)
		print("Trying size=", size, " -> wrapped height=", wrapped_size.y, " (limit=", available_height, ")")
		if wrapped_size.y <= available_height:
			best_size = size
			print("PICKED size=", size)
			break
	label.add_theme_font_size_override("font_size", best_size)

func show_choices(choices: Array[String]) -> void:
	_clear_choices()
	for choice_text in choices:
		var btn = Button.new()
		btn.text = choice_text
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
		_on_page_typing_finished()

func _on_page_typing_finished() -> void:
	var is_last_page = current_page >= pages.size() - 1
	if is_last_page:
		next_button.visible = false
		skip_button.visible = false
		finished.emit()
	else:
		skip_button.text = "PREV"

func _on_skip_pressed() -> void:
	if label.visible_characters != -1 and label.visible_characters < full_text.length():
		label.visible_characters = -1
		typing_timer.stop()
		_on_page_typing_finished()
		skipped.emit()
	else:
		_go_to_previous_page()

func _go_to_previous_page() -> void:
	if current_page > 0:
		current_page -= 1
		_show_current_page()

func _on_next_pressed() -> void:
	if label.visible_characters != -1 and label.visible_characters < full_text.length():
		label.visible_characters = -1
		typing_timer.stop()
		_on_page_typing_finished()
		return

	if current_page < pages.size() - 1:
		current_page += 1
		_show_current_page()
		advanced.emit()

func _on_choice_pressed(choice_text: String) -> void:
	choices_container.visible = false
	choice_selected.emit(choice_text)
