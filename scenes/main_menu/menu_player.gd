extends Node2D
class_name MenuPlayer

## The player character on the main menu, playing by itself:
## picks a random floating object or animal, walks over, and collects / pets it.

@export var speed: float = 42.0

var sprite: AnimatedSprite2D
var target: Node2D
var state := "idle"
var wait := 1.0
var facing := "front"

const FRAMES := "res://resources/character_animation.tres"
const SHADOW_TEX := "res://assets/sprites/game/Sprout Lands - Sprites - premium pack/Objects/Items/item shadow.png"

func _ready() -> void:
	var shadow := Sprite2D.new()
	shadow.texture = load(SHADOW_TEX)
	shadow.offset = Vector2(0, -6)
	shadow.modulate = Color(0, 0, 0, 1)
	shadow.scale = Vector2(1.1, 1.0)
	add_child(shadow)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = load(FRAMES)
	sprite.offset = Vector2(0, -8)
	add_child(sprite)
	sprite.play(&"idle_front")

func _process(delta: float) -> void:
	match state:
		"idle":
			wait -= delta
			if wait <= 0.0:
				_choose_target()
		"walk":
			if not is_instance_valid(target) or not target.available:
				_go_idle(0.3)
				return
			var reach := 12.0 if target is MenuCritter else 5.0
			var to := target.position - position
			if to.length() <= reach:
				_interact()
			else:
				position += to.normalized() * speed * delta
				_play_walk(to)

func _choose_target() -> void:
	var options: Array = []
	for n in get_tree().get_nodes_in_group("menu_interactable"):
		if n.available and n != target:
			options.append(n)
	if options.is_empty():
		_go_idle(1.0)
		return
	# prefer something not too far so the walk stays short and lively
	options.sort_custom(func(a, b): return a.position.distance_to(position) < b.position.distance_to(position))
	target = options[randi() % mini(4, options.size())]
	state = "walk"

func _interact() -> void:
	state = "busy"
	var dir := target.position - position
	_face(dir)
	sprite.play(StringName("idle_" + facing))
	if target is MenuCritter:
		target.pet(position)
		await get_tree().create_timer(1.6).timeout
	else:
		target.collect_by(self)
		_star_pop()
		var t := create_tween()
		t.tween_property(sprite, "position:y", -5.0, 0.12)
		t.tween_property(sprite, "position:y", 0.0, 0.12)
		await get_tree().create_timer(0.7).timeout
	_go_idle(randf_range(0.4, 1.4))

## A little star floats up from the player when something is collected.
func _star_pop() -> void:
	var star := Sprite2D.new()
	star.texture = load("res://resources/filled_star.tres")
	star.position = Vector2(0, -30)
	star.scale = Vector2.ZERO
	star.z_index = 10
	add_child(star)
	var t := create_tween()
	t.tween_interval(0.35)
	t.tween_property(star, "scale", Vector2.ONE * 0.8, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(star, "position:y", -42.0, 0.6)
	t.tween_property(star, "modulate:a", 0.0, 0.25)
	t.tween_callback(star.queue_free)

func _go_idle(seconds: float) -> void:
	state = "idle"
	wait = seconds
	sprite.play(StringName("idle_" + facing))

func _face(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		facing = "right" if dir.x > 0 else "left"
	else:
		facing = "front" if dir.y > 0 else "back"

func _play_walk(dir: Vector2) -> void:
	_face(dir)
	var walk := {"right": "walk_right", "left": "walk_left", "front": "walk_down", "back": "walk_up"}
	var anim := StringName(walk[facing])
	if sprite.animation != anim:
		sprite.play(anim)
