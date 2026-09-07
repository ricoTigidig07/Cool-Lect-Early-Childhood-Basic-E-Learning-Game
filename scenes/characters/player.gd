class_name Player01
extends CharacterBody2D

const SPEED = 50.0

@onready var animated_sprite = $AnimatedSprite2D2
@onready var camera = $Camera2D
@onready var joystick = get_node("../GameUI/JoystickControl")

var last_direction = "down"  # remembers facing direction for idle state

func _ready() -> void:
	camera.zoom = Vector2(3.7, 3.7)

func _physics_process(delta):
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction = input_direction
	var direction_name = ""
	
	if joystick.direction != Vector2.ZERO:
		direction = joystick.direction
		direction_name = joystick.direction_name
	
	velocity = direction * SPEED
	move_and_slide()
	update_animation(direction, direction_name)

const DIRECTION_TO_ANIM = {
	"up": "up",
	"down": "down",
	"left": "left",
	"right": "right",
	"upright": "right",
	"downright": "right",
	"upleft": "left",
	"downleft": "left",
}

const IDLE_MAP = {
	"up": "back",
	"down": "front",
	"left": "left",
	"right": "right",
}

func update_animation(direction: Vector2, joystick_name: String = ""):
	if direction == Vector2.ZERO:
		var idle_direction = IDLE_MAP.get(last_direction, "front")
		animated_sprite.play("idle_" + idle_direction)
		return
	
	var raw_direction = joystick_name
	if raw_direction == "":
		# keyboard fallback, cardinal only
		if abs(direction.x) > abs(direction.y):
			raw_direction = "right" if direction.x > 0 else "left"
		else:
			raw_direction = "down" if direction.y > 0 else "up"
	
	last_direction = DIRECTION_TO_ANIM.get(raw_direction, raw_direction)
	animated_sprite.play("walk_" + last_direction)


func _on_button_pressed() -> void:
	InteractionManager.interact()
