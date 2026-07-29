extends Button

@onready var star_container = $StarContainer
@onready var label = $Label

const FILLED_STAR = preload("res://resources/filled_star.tres")
const BLANK_STAR = preload("res://resources/blank_star.tres")

var level_number: int
var subject: String

func setup(num: int, subj: String):
	level_number = num
	subject = subj
	label.text = str(num)
	
	var stars = GameManager.get_level_stars(subject, level_number)
	var unlocked = GameManager.is_level_unlocked(subject, level_number)
	
	disabled = not unlocked
	
	label.visible = unlocked
	star_container.visible = unlocked
	
	for i in range(3):
		var star_node = star_container.get_child(i)
		star_node.texture = FILLED_STAR if i < stars else BLANK_STAR
