extends Node2D
class_name MenuCritter

## A chicken or cow that wanders around the main menu.
## The menu player can walk up and pet() it: it stops and shows hearts.

enum Kind { CHICKEN, COW }

@export var kind: Kind = Kind.CHICKEN
@export var wander_radius: float = 50.0
@export var speed: float = 14.0

var sprite: AnimatedSprite2D
var hearts: AnimatedSprite2D
var home: Vector2
var target: Vector2
var bounds: Rect2
var state := "idle"
var state_time := 0.0
var available := true

const CHICKEN_SCENE := "res://scenes/collectables/animals/chicken.tscn"
const COW_SHEET := "res://assets/sprites/game/Sprout Lands - Sprites - premium pack/Animals/Cow/Light cow animations.png"
const SHADOW_TEX := "res://assets/sprites/game/Sprout Lands - Sprites - premium pack/Objects/Items/item shadow.png"

func _ready() -> void:
	add_to_group("menu_interactable")
	home = position
	# Cows already have a shadow drawn into their sprite sheet; chickens need one.
	if kind == Kind.CHICKEN:
		var shadow := Sprite2D.new()
		shadow.texture = load(SHADOW_TEX)
		shadow.offset = Vector2(0, -6)
		shadow.modulate = Color(0, 0, 0, 1)
		shadow.scale = Vector2(0.8, 1.0)
		add_child(shadow)
	sprite = AnimatedSprite2D.new()
	add_child(sprite)
	if kind == Kind.CHICKEN:
		_setup_chicken()
	else:
		_setup_cow()
	_pick_idle()

func _setup_chicken() -> void:
	# Borrow the real chicken's animations so the menu matches the Animals level.
	var chicken := (load(CHICKEN_SCENE) as PackedScene).instantiate()
	sprite.sprite_frames = chicken.get_node("AnimatedSprite2D").sprite_frames
	sprite.offset = Vector2(0, -8)
	hearts = AnimatedSprite2D.new()
	hearts.sprite_frames = chicken.get_node("TamedAnimation").sprite_frames
	hearts.position = Vector2(0, -22)
	hearts.visible = false
	add_child(hearts)
	chicken.free()

func _setup_cow() -> void:
	var sheet: Texture2D = load(COW_SHEET)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_row(frames, &"idle", sheet, 0, 3, 4.0)
	_add_row(frames, &"walk", sheet, 1, 8, 8.0)
	_add_row(frames, &"love", sheet, 7, 6, 6.0)
	sprite.sprite_frames = frames
	sprite.offset = Vector2(0, -14)
	speed = 9.0

func _add_row(frames: SpriteFrames, anim: StringName, sheet: Texture2D, row: int, count: int, fps: float) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, true)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * 32, row * 32, 32, 32)
		frames.add_frame(anim, at)

func _anim(name: String) -> StringName:
	if kind == Kind.CHICKEN:
		return &"chicken_walk" if name == "walk" else &"chicken_idle"
	return StringName(name)

func _pick_idle() -> void:
	state = "idle"
	state_time = randf_range(1.2, 3.5)
	sprite.play(_anim("idle"))

func _pick_walk() -> void:
	state = "walk"
	var p := home + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * wander_radius
	if bounds.has_area():
		p = p.clamp(bounds.position, bounds.end)
	target = p
	state_time = 6.0
	sprite.play(_anim("walk"))

func _process(delta: float) -> void:
	if state == "petted":
		return
	state_time -= delta
	if state == "idle":
		if state_time <= 0.0:
			_pick_walk()
	elif state == "walk":
		var to := target - position
		if to.length() < 1.5 or state_time <= 0.0:
			_pick_idle()
		else:
			position += to.normalized() * speed * delta
			sprite.flip_h = to.x < 0

## Called by the menu player when it reaches this animal.
func pet(from: Vector2) -> void:
	available = false
	state = "petted"
	sprite.flip_h = from.x < position.x
	if kind == Kind.COW:
		sprite.play(&"love")
	else:
		sprite.play(&"chicken_idle")
		hearts.visible = true
		hearts.play(&"default")
	var t := create_tween()
	t.tween_property(sprite, "position:y", -4.0, 0.12)
	t.tween_property(sprite, "position:y", 0.0, 0.12)
	await get_tree().create_timer(1.6).timeout
	if hearts:
		hearts.visible = false
	_pick_idle()
	await get_tree().create_timer(3.0).timeout
	available = true
