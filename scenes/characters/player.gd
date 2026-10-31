class_name Player01
extends CharacterBody2D

const SPEED = 70.0

@onready var animated_sprite = $AnimatedSprite2D2
@onready var camera = $Camera2D
@onready var joystick = get_node_or_null("../GameUI/JoystickControl")
@onready var shadow = $Shadow
@onready var reactions: AnimationPlayer = get_node_or_null("Reactions")
@onready var lively_light: ColorRect = get_node_or_null("LightFilter/Lively")

const BOB_SPEED = 6.5
const SHADOW_MIN_SCALE = 0.75
const SHADOW_MAX_SCALE = 1.0

var last_direction = "down"  # remembers facing direction for idle state
var bob_time: float = 0.0

## Walking by itself (e.g. to stand next to an NPC when talking): the points to walk through.
var auto_path := PackedVector2Array()
## True while a conversation is open: the joystick / keys don't move the player.
var controls_locked := false
signal auto_walk_done

## Walks through these points by itself, then sends auto_walk_done.
func walk_path(points: PackedVector2Array) -> void:
	auto_path = points
	if auto_path.is_empty():
		auto_walk_done.emit()

func _ready() -> void:
	camera.zoom = Vector2(3.7, 3.7)
	# Colors levels teach real colors: keep the bright, happy light but no warm color shift.
	if lively_light and GameManager.current_subject == "colors":
		lively_light.material.set_shader_parameter("warmth", Vector3.ONE)
		lively_light.material.set_shader_parameter("saturation", 1.1)

## Tells the light which part of the world is on screen, so cloud shadows stay on the ground.
func _process(_delta: float) -> void:
	if lively_light:
		var to_world := get_viewport().get_canvas_transform().affine_inverse()
		lively_light.material.set_shader_parameter("view_origin", to_world.origin)
		lively_light.material.set_shader_parameter("view_size", get_viewport().get_visible_rect().size * to_world.get_scale())

func _physics_process(delta):
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction = input_direction
	var direction_name = ""
	
	if joystick and joystick.direction != Vector2.ZERO:
		direction = joystick.direction
		direction_name = joystick.direction_name
	if controls_locked:
		direction = Vector2.ZERO
		direction_name = ""
	if not auto_path.is_empty():
		var to: Vector2 = auto_path[0] - global_position
		if to.length() < 1.5:
			global_position = auto_path[0]
			auto_path.remove_at(0)
			direction = Vector2.ZERO
			if auto_path.is_empty():
				auto_walk_done.emit()
		else:
			direction = to.normalized() * minf(1.0, to.length() / (SPEED * delta))
			direction_name = ""
	
	velocity = direction * SPEED
	move_and_slide()
	update_animation(direction, direction_name)
	update_shadow(direction, delta)

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

func update_shadow(direction: Vector2, delta: float) -> void:
	if direction == Vector2.ZERO:
		bob_time = 0.0
		if shadow:
			shadow.scale = Vector2(SHADOW_MAX_SCALE, SHADOW_MAX_SCALE * 0.5)
		return
	
	bob_time += delta * BOB_SPEED
	var bob = abs(sin(bob_time))
	
	if shadow:
		var shadow_scale = lerp(SHADOW_MAX_SCALE, SHADOW_MIN_SCALE, bob)
		shadow.scale = Vector2(shadow_scale, shadow_scale * 0.5)

# ---------- reactions (same feel as the main menu player) ----------

## Turns the player to look at something (e.g. the item being picked up).
func face_toward(target_position: Vector2) -> void:
	var dir := target_position - global_position
	if dir.length() < 1.0:
		return
	if abs(dir.x) > abs(dir.y):
		last_direction = "right" if dir.x > 0 else "left"
	else:
		last_direction = "down" if dir.y > 0 else "up"

## Happy hop + a star floating up when something is collected.
## Edit it in player.tscn → Reactions → "collect".
func celebrate() -> void:
	AudioManager.play_sfx("hop")
	if reactions:
		reactions.stop()
		reactions.play("collect")

func _on_button_button_up() -> void:
	InteractionManager.button_up()

func _on_button_button_down() -> void:
	InteractionManager.button_down()
