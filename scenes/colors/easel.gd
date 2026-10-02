extends Area2D

## An easel with an uncolored picture. Each paintable part is a Sprite2D child
## of "Picture", named after the color it should become: Red, Green, Red2 ...
## (numbers are ignored). Sprites named "Outline..." are never painted.
## Hold the interact button with a paint bucket equipped to paint every part of that color.

signal started
signal painting_completed

## What the picture is, used in the dialogue: "apple", "banana", ...
@export var picture_name: String = "apple"
## What each color is for, used in the dialogue, e.g. {"red": "apple", "green": "leaf"}
@export var part_names: Dictionary = {}

const HOLD_DURATION := 1.0
const UNPAINTED := Color(1, 1, 1, 0.55)
const HINT := Color(1, 1, 1, 1)

@onready var picture: Node2D = $Picture
@onready var hold_indicator: TextureProgressBar = $HoldIndicator

var is_started := false
var is_holding := false
var hold_progress := 0.0
var pending_color := ""
var player_near := false
var glow_time := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	hold_indicator.visible = false
	for part in parts():
		part.set_meta("painted", false)
		part.self_modulate = Color.WHITE
		part.modulate = UNPAINTED

## Called by the Painter when the player says "Yes".
func start() -> void:
	if is_started:
		return
	is_started = true
	started.emit()

# ---------- parts and colors ----------

func parts() -> Array:
	var out := []
	for child in picture.get_children():
		if child is Sprite2D and not String(child.name).begins_with("Outline"):
			out.append(child)
	return out

func color_of(part: Node) -> String:
	return String(part.name).rstrip("0123456789").to_lower()

## Every color the picture uses, in order: ["red", "green"]
func needed_colors() -> Array[String]:
	var out: Array[String] = []
	for part in parts():
		var c := color_of(part)
		if not out.has(c):
			out.append(c)
	return out

## True if some part still needs this color.
func needs(color: String) -> bool:
	if not is_started:
		return false
	for part in parts():
		if not part.get_meta("painted") and color_of(part) == color:
			return true
	return false

## True if this paint is useful: the picture needs it, or it can be mixed
## into a color the picture needs (only when there's a MixingPot).
func wants_paint(color: String) -> bool:
	if needs(color):
		return true
	if not is_started or not get_parent().has_node("MixingPot"):
		return false
	for part in parts():
		if part.get_meta("painted"):
			continue
		var recipe: Array = PaintColors.RECIPES.get(color_of(part), [])
		if recipe.has(color):
			return true
	return false

## The first color still missing ("" when finished).
func next_needed_color() -> String:
	for part in parts():
		if not part.get_meta("painted"):
			return color_of(part)
	return ""

func is_complete() -> bool:
	return next_needed_color() == ""

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

# ---------- painting ----------

func start_hold() -> void:
	if not is_started or is_complete():
		return
	var equipped := GameUIManager.get_equipped_item()
	if not needs(equipped):
		if equipped != "":
			_wrong_paint_feedback()
		return
	pending_color = equipped
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
			_paint(pending_color)
	_update_glow(delta)

## The parts that the equipped paint would color pulse as a hint.
func _update_glow(delta: float) -> void:
	glow_time += delta
	var pulse := (sin(glow_time * 6.0) + 1.0) * 0.5
	var equipped := GameUIManager.get_equipped_item() if player_near and is_started else ""
	for part in parts():
		if part.get_meta("painted"):
			continue
		if equipped != "" and color_of(part) == equipped:
			part.modulate = UNPAINTED.lerp(HINT, pulse)
		else:
			part.modulate = UNPAINTED

func _paint(color: String) -> void:
	GameUIManager.consume_hotbar_item(color)
	for part in parts():
		if part.get_meta("painted") or color_of(part) != color:
			continue
		part.set_meta("painted", true)
		var t := create_tween().set_parallel(true)
		t.tween_property(part, "self_modulate", PaintColors.color(color), 0.35)
		t.tween_property(part, "modulate", Color.WHITE, 0.35)
	var bounce := create_tween()
	bounce.tween_property(picture, "scale", Vector2.ONE * 1.08, 0.1)
	bounce.tween_property(picture, "scale", Vector2.ONE, 0.12)
	if is_complete():
		_celebrate()

func _celebrate() -> void:
	GameUIManager.complete_mission_2()
	painting_completed.emit()
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_property(picture, "scale", Vector2.ONE * 1.12, 0.12)
	t.tween_property(picture, "scale", Vector2.ONE, 0.15)

func _wrong_paint_feedback() -> void:
	var t := create_tween()
	var base_x := picture.position.x
	for dx in [2.0, -2.0, 1.0, -1.0, 0.0]:
		t.tween_property(picture, "position:x", base_x + dx, 0.04)
