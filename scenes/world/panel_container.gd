extends PanelContainer

@onready var label = $Label

const CHARS_PER_SECOND = 30.0

var typing_timer: Timer
var full_text: String = ""

func _ready() -> void:
	typing_timer = Timer.new()
	typing_timer.wait_time = 1.0 / CHARS_PER_SECOND
	typing_timer.timeout.connect(_on_typing_tick)
	add_child(typing_timer)

func set_text(text: String) -> void:
	full_text = text
	label.text = text
	label.visible_characters = 0
	typing_timer.start()

func _on_typing_tick() -> void:
	label.visible_characters += 1
	if label.visible_characters >= full_text.length():
		typing_timer.stop()

func skip_typing() -> void:
	label.visible_characters = -1
	typing_timer.stop()
