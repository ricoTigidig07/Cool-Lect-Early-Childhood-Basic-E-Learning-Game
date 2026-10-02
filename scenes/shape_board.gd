extends Area2D

## A blueprint made of empty shape outlines. The player fills each spot with the
## matching shape block from the hotbar (hold the interact button).
## Each hole's Self Modulate is the color the piece becomes when it's built.
## Holes are the Sprite2D children of "Holes". Name them by shape:
## Circle, Square, Square2, Triangle ... (numbers are ignored).

signal started
signal board_completed

const HOLD_DURATION := 1.0
const EMPTY_COLOR := Color(1, 1, 1, 0.45)      # white outline on the blueprint
const HINT_COLOR := Color(1, 1, 1, 0.95)
const GLOW := Color(1.35, 1.25, 0.8, 1)

@onready var holes: Node2D = $Holes
@onready var hold_indicator: TextureProgressBar = $HoldIndicator

var is_started := false
var is_holding := false
var hold_progress := 0.0
var pending_hole: Sprite2D = null
var player_near := false
var glow_time := 0.0
## Colors of the blocks the player picked up, per shape, so each piece
## goes to the spot of the same color (the yellow circle becomes the sun).
var picked_tints := {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	hold_indicator.visible = false
	for hole in holes.get_children():
		# remember the real color, show a white outline until it's built
		hole.set_meta("color", hole.self_modulate)
		hole.self_modulate = Color.WHITE
		hole.modulate = EMPTY_COLOR
		hole.set_meta("filled", false)

## Called by the Builder when the player says "Yes".
func start() -> void:
	if is_started:
		return
	is_started = true
	started.emit()

# ---------- shapes ----------

func shape_of(hole: Node) -> String:
	return String(hole.name).rstrip("0123456789").to_lower()

func _empty_hole_for(shape: String) -> Sprite2D:
	var wanted_tint = null
	if picked_tints.get(shape, []).size() > 0:
		wanted_tint = picked_tints[shape][0]
	var first: Sprite2D = null
	for hole in holes.get_children():
		if not hole.get_meta("filled") and shape_of(hole) == shape:
			if wanted_tint != null and hole.get_meta("color").is_equal_approx(wanted_tint):
				return hole
			if first == null:
				first = hole
	return first

## Called by a shape block when the player picks it up.
func remember_tint(shape: String, tint: Color) -> void:
	if not picked_tints.has(shape):
		picked_tints[shape] = []
	picked_tints[shape].append(tint)

## True if the picture still has an empty hole for this shape.
func needs(shape: String) -> bool:
	return is_started and _empty_hole_for(shape) != null

## How many holes of each shape the picture has, e.g. {"square": 2, "triangle": 1}
func shape_counts() -> Dictionary:
	var counts := {}
	for hole in holes.get_children():
		var s := shape_of(hole)
		counts[s] = counts.get(s, 0) + 1
	return counts

## The shape of the first hole that is still empty ("" when finished).
func next_needed_shape() -> String:
	for hole in holes.get_children():
		if not hole.get_meta("filled"):
			return shape_of(hole)
	return ""

func is_complete() -> bool:
	return next_needed_shape() == ""

# ---------- player nearby ----------

func _on_body_entered(body: Node2D) -> void:
	if body is Player01:
		InteractionManager.register(self)
		player_near = true

func _on_body_exited(body: Node2D) -> void:
	if body is Player01:
		InteractionManager.unregister(self)
		player_near = false
		cancel_hold()

# ---------- holding ----------

func start_hold() -> void:
	if not is_started or is_complete():
		return
	var equipped := GameUIManager.get_equipped_item()
	pending_hole = _empty_hole_for(equipped)
	if pending_hole == null:
		if equipped != "":
			_wrong_shape_feedback()
		return
	is_holding = true
	hold_progress = 0.0
	hold_indicator.visible = true
	hold_indicator.value = 0

func cancel_hold() -> void:
	is_holding = false
	hold_progress = 0.0
	hold_indicator.visible = false

func _process(delta: float) -> void:
	if is_holding:
		hold_progress += delta / HOLD_DURATION
		hold_indicator.value = hold_progress * 100
		if hold_progress >= 1.0:
			is_holding = false
			hold_indicator.visible = false
			_place(pending_hole)
	_update_glow(delta)

## The empty holes that match your equipped shape pulse as a hint.
func _update_glow(delta: float) -> void:
	glow_time += delta
	var pulse := (sin(glow_time * 6.0) + 1.0) * 0.5
	var equipped := GameUIManager.get_equipped_item() if player_near and is_started else ""
	for hole in holes.get_children():
		if hole.get_meta("filled"):
			continue
		if equipped != "" and shape_of(hole) == equipped:
			hole.modulate = EMPTY_COLOR.lerp(HINT_COLOR, pulse)
		else:
			hole.modulate = EMPTY_COLOR

func _place(hole: Sprite2D) -> void:
	var shape := shape_of(hole)
	GameUIManager.consume_hotbar_item(shape)
	var tints: Array = picked_tints.get(shape, [])
	for i in tints.size():
		if hole.get_meta("color").is_equal_approx(tints[i]):
			tints.remove_at(i)
			break
	hole.set_meta("filled", true)
	hole.self_modulate = hole.get_meta("color")
	hole.modulate = Color.WHITE
	var base := hole.scale
	var t := create_tween()
	t.tween_property(hole, "scale", base * 1.3, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(hole, "scale", base, 0.1)
	if is_complete():
		_celebrate()

func _celebrate() -> void:
	GameUIManager.complete_mission_2()
	board_completed.emit()
	var t := create_tween()
	t.tween_interval(0.3)
	t.tween_property(holes, "scale", Vector2.ONE * 1.12, 0.12)
	t.tween_property(holes, "scale", Vector2.ONE, 0.15)
	for hole in holes.get_children():
		var w := create_tween()
		w.tween_interval(0.3)
		w.tween_property(hole, "modulate", GLOW, 0.15)
		w.tween_property(hole, "modulate", Color.WHITE, 0.3)

func _wrong_shape_feedback() -> void:
	var t := create_tween()
	var base_x := holes.position.x
	for dx in [2.0, -2.0, 1.0, -1.0, 0.0]:
		t.tween_property(holes, "position:x", base_x + dx, 0.04)
