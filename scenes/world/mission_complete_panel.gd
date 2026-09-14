extends Control

## Shown when all 3 missions for the level are complete.
## Stars are filled based on how many missions were completed.

signal retry_pressed
signal next_level_pressed
signal level_select_pressed

@onready var card: PanelContainer = $Card
@onready var star_1: TextureRect = $Star1
@onready var star_2: TextureRect = $Star2
@onready var star_3: TextureRect = $Star3
@onready var retry_button: Button = $ButtonContainer/RetryButton
@onready var next_button: Button = $ButtonContainer/NextButton
@onready var level_select_button: Button = $ButtonContainer/LevelSelectButton

const BLANK_STAR = preload("res://resources/blank_star.tres")
const FILLED_STAR = preload("res://resources/filled_star.tres")

var stars: Array[TextureRect]

func _ready() -> void:
	stars = [star_1, star_2, star_3]
	for star in stars:
		star.texture = BLANK_STAR

	visible = false

## Reveals the panel and fills in stars based on missions completed.
## star_count is how many of the 3 missions were completed (0-3).
## Reveals the panel and fills in stars based on missions completed.
## star_count is how many of the 3 missions were completed (0-3).
func show_result(star_count: int) -> void:
	star_count = clampi(star_count, 0, 3)
	for i in range(stars.size()):
		stars[i].texture = FILLED_STAR if i < star_count else BLANK_STAR

	visible = true
	$AnimationPlayer.play("mission_complete_anim")  # use your actual animation name

func hide_panel() -> void:
	visible = false

func _on_retry_button_pressed() -> void:
	retry_pressed.emit()

func _on_next_button_pressed() -> void:
	next_level_pressed.emit()

func _on_level_select_button_pressed() -> void:
	level_select_pressed.emit()
