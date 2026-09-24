extends Area2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var door_body: StaticBody2D = $DoorBody

var is_open: bool = false
var players_inside: int = 0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	sprite.frame = 0

func _on_body_entered(body: Node2D) -> void:
	if body is Player01:
		players_inside += 1
		_open_door()

func _on_body_exited(body: Node2D) -> void:
	if body is Player01:
		players_inside = max(players_inside - 1, 0)
		if players_inside == 0:
			_close_door()

func _open_door() -> void:
	if is_open:
		return
	is_open = true
	sprite.play("open")
	door_body.set_deferred("collision_layer", 0)

func _close_door() -> void:
	if not is_open:
		return
	is_open = false
	sprite.play_backwards("open")
	door_body.set_deferred("collision_layer", 1)
