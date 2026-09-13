extends Sprite2D

@export var float_height: float = 4.0
@export var float_speed: float = 2.0
@export var shadow_min_scale: float = 0.6
@export var shadow_max_scale: float = 1.0

@onready var shadow: Sprite2D = get_parent().get_node("Shadow")

var base_y: float
var time_offset: float

func _ready() -> void:
	base_y = position.y
	time_offset = randf() * TAU  # desyncs multiple apples so they don't bob in unison

func _process(delta: float) -> void:
	var t = (Time.get_ticks_msec() / 1000.0) * float_speed + time_offset
	var bob = sin(t)

	position.y = base_y - (bob + 1.0) / 2.0 * float_height

	var height_factor = (bob + 1.0) / 2.0
	var shadow_scale = lerp(shadow_max_scale, shadow_min_scale, height_factor)
	shadow.scale = Vector2(shadow_scale, shadow_scale * 0.5)
	shadow.modulate.a = lerp(0.45, 0.2, height_factor)
