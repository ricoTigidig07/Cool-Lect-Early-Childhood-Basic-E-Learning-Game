extends Control

@onready var base = $Base
@onready var knob = $Knob

var is_pressed = false
var knob_start_pos: Vector2
var max_distance = 40.0

var direction = Vector2.ZERO
var direction_name = ""

const DIRECTION_NAMES = ["right", "downright", "down", "downleft", "left", "upleft", "up", "upright"]

func _ready():
	knob_start_pos = knob.position

func _gui_input(event):
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			is_pressed = true
		else:
			is_pressed = false
			knob.position = knob_start_pos
			direction = Vector2.ZERO
			direction_name = ""

	if event is InputEventScreenDrag or (event is InputEventMouseMotion and is_pressed):
		var local_pos = event.position - (base.position + base.size / 2)
		
		if local_pos.length() < 15.0:
			knob.position = knob_start_pos
			direction = Vector2.ZERO
			direction_name = ""
			return
		
		var angle = local_pos.angle()
		var index = int(round(angle / (PI / 4))) % 8
		if index < 0:
			index += 8
		
		direction_name = DIRECTION_NAMES[index]
		var snapped_angle = index * (PI / 4)
		direction = Vector2(cos(snapped_angle), sin(snapped_angle))
		knob.position = knob_start_pos + (direction * max_distance)
