extends CollectableComponent
class_name Chicken

## A farm animal that wanders around. Hold the button next to it with the
## right food equipped (required_item) and it becomes your friend and follows you.
## Works for every animal: set anim_prefix to the animation names in its
## SpriteFrames ("duck" -> duck_idle, duck_walk, duck_look_around).

## Animation names: <anim_prefix>_idle, <anim_prefix>_walk, <anim_prefix>_look_around
@export var anim_prefix: String = "chicken"
## Picture of the animal (Items panel) and of its food (hotbar + thought bubble).
@export var icon: Texture2D
@export var food_icon: Texture2D

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
## Optional thought bubble with the food this animal wants (shown when the player is near).
@onready var want_bubble: Node2D = get_node_or_null("WantBubble")

var tamed := false

const SEPARATION_PUSH := 40.0
## Animals bump into things exactly like the player: they use the player's own collision
## shape and collision mask (walls, fences, houses, trees, rocks, water...).
## The player doesn't block them.
## A friend following the player that is stuck for this long pops up next to the player.
const STUCK_TIME := 2.0

var _shape: Shape2D = null          # the player's collision shape
var _shape_offset := Vector2.ZERO   # where it sits on the player
var _mask := 1
var _core := CircleShape2D.new()
var _stuck := 0.0

var state: State = State.WANDER_IDLE
var current_idle_anim: String = ""
var is_actively_following: bool = false
var spawn_point: Vector2
var wander_target: Vector2
var wander_timer: float = 0.0
var follow_target: Node2D = null

func _ready() -> void:
	super._ready()
	add_to_group("farm_animals")
	current_idle_anim = anim_prefix + "_idle"
	if want_bubble:
		want_bubble.visible = false
	spawn_point = global_position
	_pick_new_wander_target()
	_start_idle_pause()
	tamed_fx.visible = false
	separation_area.set_meta("owner_chicken", self)

func _physics_process(delta: float) -> void:
	if is_holding or is_collecting:
		sprite.play(anim_prefix + "_idle")
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
				sprite.play(anim_prefix + "_idle")

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
		_try_move(push.normalized() * SEPARATION_PUSH * delta)

func _move_toward(target: Vector2, speed: float, delta: float) -> void:
	var dir = (target - global_position).normalized()
	var want: Vector2 = dir * speed * delta
	var moved := _try_move(want)
	sprite.play(anim_prefix + "_walk")
	sprite.flip_h = dir.x < 0
	if moved.length() < want.length() * 0.3:
		if state == State.WANDER_MOVE:
			_start_idle_pause()        # bumped into something: stop, then pick another spot
			state = State.WANDER_IDLE
		else:
			_stuck += delta
			if _stuck > STUCK_TIME:
				_stuck = 0.0
				_pop_to_player()
	else:
		_stuck = 0.0

## Stuck behind something: appear right next to the player (a free spot), with a little hop.
func _pop_to_player() -> void:
	var player = _player()
	if player == null:
		return
	var base: Vector2 = player.global_position
	global_position = base + Vector2(0, 12)
	for off in [Vector2(0, 14), Vector2(-14, 8), Vector2(14, 8), Vector2(-16, 0), Vector2(16, 0),
			Vector2(0, -14), Vector2(-12, -10), Vector2(12, -10), Vector2(0, 24), Vector2(-24, 0), Vector2(24, 0)]:
		if _is_free(base + off):
			global_position = base + off
			break
	sprite.scale = Vector2(0.3, 0.3)
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.12)
	t.tween_property(sprite, "scale", Vector2.ONE, 0.1)
	AudioManager.play_sfx("hop")

## Moves as far as possible without going into anything solid; slides along walls.
## Returns how far it really moved.
func _try_move(motion: Vector2) -> Vector2:
	var start := global_position
	for m in [motion, Vector2(motion.x, 0), Vector2(0, motion.y)]:
		if m.length() < 0.001:
			continue
		var f := _free_fraction(m)
		if f > 0.0:
			global_position += m * f
			if f >= 0.999 or m != motion:
				break
	return global_position - start

func _player() -> Node2D:
	return get_tree().current_scene.get_node_or_null("Player") if get_tree().current_scene else null

## Copies the player's collision shape and mask (once).
func _query() -> PhysicsShapeQueryParameters2D:
	if _shape == null:
		_shape = CircleShape2D.new()
		(_shape as CircleShape2D).radius = 4.0
		var player = _player()
		if player:
			_mask = player.collision_mask
			for c in player.get_children():
				if c is CollisionShape2D and not c.disabled and c.shape:
					_shape = c.shape
					_shape_offset = c.position
					break
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _shape
	q.collision_mask = _mask
	q.collide_with_areas = false
	q.collide_with_bodies = true
	var player = _player()
	if player:
		q.exclude = [player.get_rid()]
	return q

func _is_free(at: Vector2) -> bool:
	var q := _query()
	q.transform = Transform2D(0, at + _shape_offset)
	return get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()

func _free_fraction(motion: Vector2) -> float:
	var q := _query()
	q.transform = Transform2D(0, global_position + _shape_offset)
	q.motion = motion
	var space := get_world_2d().direct_space_state
	# standing inside something (spawned on it): don't trap it, let it walk out
	var full := q.shape
	if full is CircleShape2D:
		_core.radius = maxf(1.0, full.radius - 1.5)
		q.shape = _core
		if not space.intersect_shape(q, 1).is_empty():
			return 1.0
		q.shape = full
	var r := space.cast_motion(q)
	return r[0] if r.size() > 0 else 1.0

func _pick_new_wander_target() -> void:
	var offset = Vector2(randf_range(-wander_radius, wander_radius), randf_range(-wander_radius, wander_radius))
	wander_target = spawn_point + offset

func _start_idle_pause() -> void:
	wander_timer = randf_range(wander_pause_min, wander_pause_max)
	current_idle_anim = anim_prefix + ("_look_around" if randf() < 0.3 else "_idle")

## Skips the fly-up/shake/shrink pickup animation entirely — taming should
## feel instant, not like the item is vanishing into an inventory.
func interact() -> void:
	if is_collecting:
		return
	is_collecting = true
	set_deferred("monitoring", false)
	InteractionManager.unregister(self)
	_finish_collect()

# ---------- player near: show which food this animal wants ----------

func _on_body_entered(body: Node2D) -> void:
	if tamed:
		return   # already your friend
	super._on_body_entered(body)
	if body is Player01 and want_bubble:
		want_bubble.visible = true

func _on_body_exited(body: Node2D) -> void:
	super._on_body_exited(body)
	if body is Player01 and want_bubble:
		want_bubble.visible = false

## Called by InteractionManager when the player holds the button with the wrong food.
func wrong_item_feedback() -> void:
	AudioManager.play_sfx("wrong")
	var t := create_tween()
	for dx in [2.0, -2.0, 1.0, -1.0, 0.0]:
		t.tween_property(sprite, "position:x", dx, 0.04)
	if want_bubble:
		want_bubble.visible = true
		var b := create_tween()
		b.tween_property(want_bubble, "scale", Vector2.ONE * 1.3, 0.1)
		b.tween_property(want_bubble, "scale", Vector2.ONE, 0.15)

func _finish_collect() -> void:
	tamed = true
	if want_bubble:
		want_bubble.visible = false
	if name_label:
		name_label.visible = false
	AudioManager.play_sfx("collect")
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
