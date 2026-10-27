extends Button

@onready var sprite = $"../Sprite2D"

const HOVER_MULT = 1.1
const PRESS_OFFSET_Y = 4.0

var base_scale: Vector2
var base_position: Vector2

func _ready() -> void:
	base_scale = sprite.scale
	base_position = sprite.position
	# some scenes already connect these in the editor: only connect once
	for pair in [[mouse_entered, _on_mouse_entered], [mouse_exited, _on_mouse_exited],
			[button_down, _on_button_down], [button_up, _on_button_up]]:
		if not pair[0].is_connected(pair[1]):
			pair[0].connect(pair[1])

func _on_mouse_entered() -> void:
	sprite.scale = base_scale * HOVER_MULT

func _on_mouse_exited() -> void:
	sprite.scale = base_scale

func _on_button_down() -> void:
	sprite.position = base_position + Vector2(0, PRESS_OFFSET_Y)

func _on_button_up() -> void:
	sprite.position = base_position
	if get_global_rect().has_point(get_global_mouse_position()):
		sprite.scale = base_scale * HOVER_MULT
	else:
		sprite.scale = base_scale
