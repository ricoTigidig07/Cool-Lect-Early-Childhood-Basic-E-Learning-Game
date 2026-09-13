extends Control

## Shown when all 3 missions for the level are complete.
## Stars are filled one-by-one based on how many missions were completed.

signal retry_pressed
signal next_level_pressed
signal level_select_pressed

@onready var card: PanelContainer = $Card
@onready var star_1: TextureRect = $StarContainer/Star1
@onready var star_2: TextureRect = $StarContainer/Star2
@onready var star_3: TextureRect = $aStarContainer/Star3
@onready var retry_button: Button = $Card/MarginContainer/VBoxContainer/ButtonContainer/RetryButton
@onready var next_button: Button = $Card/MarginContainer/VBoxContainer/ButtonContainer/NextButton
@onready var level_select_button: Button = $Card/MarginContainer/VBoxContainer/ButtonContainer/LevelSelectButton

const BLANK_STAR = preload("res://resources/blank_star.tres")
const FILLED_STAR = preload("res://resources/filled_star.tres")
const STAR_POP_DELAY := 0.15

var stars: Array[TextureRect]

func _ready() -> void:
	stars = [star_1, star_2, star_3]
	for star in stars:
		star.texture = BLANK_STAR
		star.pivot_offset = star.size / 2.0
		star.scale = Vector2.ONE

	visible = false
	modulate.a = 0.0
	card.scale = Vector2(0.85, 0.85)
	card.pivot_offset = card.size / 2.0

## Reveals the panel and pops the stars in one-by-one.
## star_count is how many of the 3 missions were completed (0-3).
func show_result(star_count: int) -> void:
	star_count = clampi(star_count, 0, 3)
	for star in stars:
		star.texture = BLANK_STAR
		star.scale = Vector2.ONE

	visible = true
	modulate.a = 0.0
	card.scale = Vector2(0.85, 0.85)

	var intro := create_tween()
	intro.set_parallel(true)
	intro.tween_property(self, "modulate:a", 1.0, 0.2)
	intro.tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await intro.finished

	await _pop_stars(star_count)

func hide_panel() -> void:
	visible = false

func _pop_stars(star_count: int) -> void:
	for i in range(star_count):
		var star := stars[i]
		star.texture = FILLED_STAR
		star.scale = Vector2.ZERO
		var pop := create_tween()
		pop.tween_property(star, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(star, "scale", Vector2.ONE, 0.1)
		await get_tree().create_timer(STAR_POP_DELAY).timeout

func _on_retry_button_pressed() -> void:
	retry_pressed.emit()


func _on_next_button_pressed() -> void:
	next_level_pressed.emit()


func _on_level_select_button_pressed() -> void:
	level_select_pressed.emit()
