extends Button

@onready var sprite = $"../Sprite2D"

const HOVER_MULT = 1.1
const PRESS_OFFSET_Y = 4.0

var base_scale: Vector2
var base_position: Vector2

func _ready() -> void:
	base_scale = sprite.scale
	base_position = sprite.position
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

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
