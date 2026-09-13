extends PanelContainer

@onready var star_1 = $MarginContainer/VBoxContainer/Mission1/StarIcon1
@onready var star_2 = $MarginContainer/VBoxContainer/Mission2/StarIcon2
@onready var star_3 = $MarginContainer/VBoxContainer/Mission3/StarIcon3

@onready var label_1 = $MarginContainer/VBoxContainer/Mission1/Label
@onready var label_2 = $MarginContainer/VBoxContainer/Mission2/Label
@onready var label_3 = $MarginContainer/VBoxContainer/Mission3/Label

const BLANK_STAR = preload("res://resources/blank_star.tres")
const FILLED_STAR = preload("res://resources/filled_star.tres")

const FONT_SIZE_ACTIVE = 16
const FONT_SIZE_DEFAULT = 12
const OUTLINE_SIZE_ON = 6
const OUTLINE_SIZE_OFF = 0

var labels: Array
var stars: Array
var current_mission := 1
var completed_missions: Array[bool] = [false, false, false]

func _ready() -> void:
	labels = [label_1, label_2, label_3]
	stars = [star_1, star_2, star_3]
	for star in stars:
		star.texture = BLANK_STAR
	_refresh_styles()

func set_missions(text_1: String, text_2: String, text_3: String) -> void:
	label_1.text = text_1
	label_2.text = text_2
	label_3.text = text_3

func complete_mission_1() -> void:
	_complete_mission(0, star_1)

func complete_mission_2() -> void:
	_complete_mission(1, star_2)

func complete_mission_3() -> void:
	_complete_mission(2, star_3)

func _complete_mission(index: int, star: TextureRect) -> void:
	star.texture = FILLED_STAR
	completed_missions[index] = true
	current_mission = index + 2
	_refresh_styles()

func _refresh_styles() -> void:
	for i in range(labels.size()):
		var mission_num = i + 1
		var label = labels[i]
		if completed_missions[i]:
			_apply_completed_style(label)
		elif mission_num == current_mission:
			_apply_active_style(label)
		else:
			_apply_locked_style(label)

func _apply_active_style(label: Label) -> void:
	label.add_theme_font_size_override("font_size", FONT_SIZE_ACTIVE)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE_ON)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.modulate = Color(1, 1, 1, 1)

func _apply_locked_style(label: Label) -> void:
	label.add_theme_font_size_override("font_size", FONT_SIZE_DEFAULT)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE_OFF)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.modulate = Color(1, 1, 1, 0.3)

func _apply_completed_style(label: Label) -> void:
	label.add_theme_font_size_override("font_size", FONT_SIZE_ACTIVE)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE_ON)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_color_override("font_color", Color.GREEN)
	label.modulate = Color(1.0, 1.0, 1.0, 0.573)
	
## How many of the 3 missions are complete (0-3). Used to award stars
## on the Mission Complete screen.
func get_completed_count() -> int:
	var count := 0
	for is_done in completed_missions:
		if is_done:
			count += 1
	return count
