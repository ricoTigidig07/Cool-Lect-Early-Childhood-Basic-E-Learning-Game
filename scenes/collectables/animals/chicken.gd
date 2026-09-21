extends CollectableComponent
class_name Chicken

@export var wander_radius: float = 40.0
@export var wander_pause_min: float = 1.0
@export var wander_pause_max: float = 2.5
@export var wander_speed: float = 30.0
@export var follow_speed: float = 30.0
@export var follow_distance: float = 28.0
@export var follow_stop_distance: float = 5.0

enum State { WANDER_IDLE, WANDER_MOVE, FOLLOW }

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var tamed_fx: AnimatedSprite2D = $TamedAnimation
@onready var separation_area: Area2D = $SeparationArea

const SEPARATION_PUSH := 40.0

var state: State = State.WANDER_IDLE
var current_idle_anim: String = "chicken_idle"
var is_actively_following: bool = false
var spawn_point: Vector2
var wander_target: Vector2
var wander_timer: float = 0.0
var follow_target: Node2D = null

func _ready() -> void:
	super._ready()
	spawn_point = global_position
	_pick_new_wander_target()
	_start_idle_pause()
	tamed_fx.visible = false
	separation_area.set_meta("owner_chicken", self)

func _physics_process(delta: float) -> void:
	if is_holding or is_collecting:
		sprite.play("chicken_idle")
		return

	_apply_separation(delta)

	match state:
		State.WANDER_IDLE:
			sprite.play(current_idle_anim)
			wander_timer -= delta
			if wander_timer <= 0.0:
				_pick_new_wander_target()
				state = State.WANDER_MOVE
		State.WANDER_MOVE:
			_move_toward(wander_target, wander_speed, delta)
			if global_position.distance_to(wander_target) < 4.0:
				_start_idle_pause()
				state = State.WANDER_IDLE
		State.FOLLOW:
			if follow_target == null:
				return
			var target_pos = follow_target.global_position + Vector2(0, 16)
			var dist = global_position.distance_to(target_pos)
			if dist > follow_distance:
				is_actively_following = true
			elif dist < follow_stop_distance:
				is_actively_following = false
			if is_actively_following:
				_move_toward(target_pos, follow_speed, delta)
			else:
				sprite.play("chicken_idle")

func _apply_separation(delta: float) -> void:
	var push = Vector2.ZERO
	for other_area in separation_area.get_overlapping_areas():
		if not other_area.has_meta("owner_chicken"):
			continue
		var other = other_area.get_meta("owner_chicken")
		if other == self:
			continue
		var away = global_position - other.global_position
		if away.length() > 0.001:
			push += away.normalized() / away.length()
	if push != Vector2.ZERO:
		global_position += push.normalized() * SEPARATION_PUSH * delta

func _move_toward(target: Vector2, speed: float, delta: float) -> void:
	var dir = (target - global_position).normalized()
	global_position += dir * speed * delta
	sprite.play("chicken_walk")
	sprite.flip_h = dir.x < 0

func _pick_new_wander_target() -> void:
	var offset = Vector2(randf_range(-wander_radius, wander_radius), randf_range(-wander_radius, wander_radius))
	wander_target = spawn_point + offset

func _start_idle_pause() -> void:
	wander_timer = randf_range(wander_pause_min, wander_pause_max)
	current_idle_anim = "chicken_look_around" if randf() < 0.3 else "chicken_idle"

## Skips the fly-up/shake/shrink pickup animation entirely — taming should
## feel instant, not like the item is vanishing into an inventory.
func interact() -> void:
	if is_collecting:
		return
	is_collecting = true
	set_deferred("monitoring", false)
	InteractionManager.unregister(self)
	_finish_collect()

func _finish_collect() -> void:
	QuestManager.collect_item(item_type)
	collected.emit(collectable_name, item_type)
	scale = Vector2.ONE
	if required_item != "":
		GameUIManager.consume_hotbar_item(required_item)
	is_collecting = false
	state = State.FOLLOW
	follow_target = player_ref
	set_deferred("monitoring", true)
	_play_tamed_fx()

func _play_tamed_fx() -> void:
	tamed_fx.visible = true
	tamed_fx.play("default")
	tamed_fx.animation_finished.connect(func(): tamed_fx.visible = false, CONNECT_ONE_SHOT)
	
func get_owner_chicken() -> Chicken:
	return self
