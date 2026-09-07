extends AnimatedSprite2D

var animations = ["defaults", "Blinking", "Edadars"]
var is_near_merchant = false

func _ready():
	play("defaults")
	animation_finished.connect(_on_animation_finished)
	_schedule_next_animation()

func _schedule_next_animation():
	var wait_time = randf_range(2.0, 5.0)
	await get_tree().create_timer(wait_time).timeout
	if not is_near_merchant:
		_play_random_animation()
	_schedule_next_animation()

func _play_random_animation():
	var next_anim = animations[randi() % animations.size()]
	play(next_anim)

func _on_animation_finished():
	if not is_near_merchant:
		play("defaults")

func set_near_merchant(value: bool) -> void:
	is_near_merchant = value
	if not value:
		play("defaults")
