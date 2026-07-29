extends Control

const LevelNodeScene = preload("res://scenes/levels/level_node.tscn")
const SUBJECT = "shapes"
const TOTAL_LEVELS = 15
@onready var node_container = $NodeContainer

const COLUMNS = 5
const H_SPACING = 210
const V_SPACING = 200

func _ready():
	var screen_size = size
	var rows = ceil(float(TOTAL_LEVELS) / COLUMNS)
	
	var grid_width = (COLUMNS - 1) * H_SPACING
	var grid_height = (rows - 1) * V_SPACING
	
	var start_x = (screen_size.x - grid_width) / 2.0
	var start_y = (screen_size.y - grid_height) / 2.0
	
	for i in range(1, TOTAL_LEVELS + 1):
		var node = LevelNodeScene.instantiate()
		node_container.add_child(node)
		
		var button = node.get_node("GridContainer/Button")
		button.setup(i, SUBJECT)
		
		var col = (i - 1) % COLUMNS
		var row = (i - 1) / COLUMNS
		var x = start_x + col * H_SPACING
		var y = start_y + row * V_SPACING  # removed the random offset
		node.position = Vector2(x, y)
