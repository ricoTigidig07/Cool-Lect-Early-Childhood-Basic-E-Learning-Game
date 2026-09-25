extends Area2D

## A wooden board with two slots: capital on the left, small on the right.
## Each empty slot shows a faint shadow of the letter it needs.
## Hold with the right letter equipped to place it. When both are in,
## the board celebrates and moves on to the next letter in the sequence.

@export var target_letter: String = "A"
@export var letter_sequence: NodePath

@onready var board: Panel = $Board
@onready var capital_socket: Panel = $Board/CapitalSocket
@onready var small_socket: Panel = $Board/SmallSocket
@onready var capital_ghost: Sprite2D = $Board/CapitalSocket/Ghost
@onready var small_ghost: Sprite2D = $Board/SmallSocket/Ghost
@onready var capital_letter: Sprite2D = $Board/CapitalSocket/Letter
@onready var small_letter: Sprite2D = $Board/SmallSocket/Letter
@onready var progress_dots: HBoxContainer = $Board/ProgressDots
@onready var progress_label: Label = $Board/ProgressLabel
@onready var hold_indicator: TextureProgressBar = $HoldIndicator

const HOLD_DURATION := 1.0
const LETTER_ICON_PATH := "res://scenes/collectables/alphabets/"
const LETTER_SCALE := 0.46
const SLOT_FIT := 20.0
const DOT_EMPTY := Color(0.36, 0.22, 0.14, 1)
const MAX_DOTS := 8
const DOT_DONE := Color(0.55, 0.85, 0.35, 1)
const GLOW := Color(1.35, 1.25, 0.8, 1)

var placed_upper: bool = false
var placed_lower: bool = false
var is_holding: bool = false
var is_advancing: bool = false
var is_done: bool = false
var player_near: bool = false
var hold_progress: float = 0.0
var pending_letter: String = ""
var glow_time: float = 0.0
var dots: Array[Panel] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	hold_indicator.visible = false
	var seq = _seq()
	if seq and seq.current_letter() != "":
		target_letter = seq.current_letter()
	_build_dots()
	_reset_slots()

func _seq() -> Node:
	return get_node_or_null(letter_sequence)

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
	if is_advancing or is_done:
		return
	var equipped = GameUIManager.get_equipped_item()
	pending_letter = _needed_letter_for(equipped)
	if pending_letter == "":
		if equipped != "":
			_wrong_letter_feedback()
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
			_complete_hold()
	_update_glow(delta)

func _complete_hold() -> void:
	is_holding = false
	hold_indicator.visible = false
	_place_letter(pending_letter)

func _needed_letter_for(equipped: String) -> String:
	if equipped == target_letter and not placed_upper:
		return target_letter
	if equipped == target_letter.to_lower() and not placed_lower:
		return target_letter.to_lower()
	return ""

# ---------- hint glow: the slot that matches your equipped letter pulses ----------

func _update_glow(delta: float) -> void:
	glow_time += delta
	var pulse := (sin(glow_time * 6.0) + 1.0) * 0.5
	var equipped := ""
	if player_near and not is_advancing:
		equipped = GameUIManager.get_equipped_item()
	var cap_hint := equipped != "" and equipped == target_letter and not placed_upper
	var small_hint := equipped != "" and equipped == target_letter.to_lower() and not placed_lower
	capital_socket.self_modulate = Color.WHITE.lerp(GLOW, pulse) if cap_hint else Color.WHITE
	small_socket.self_modulate = Color.WHITE.lerp(GLOW, pulse) if small_hint else Color.WHITE

func _wrong_letter_feedback() -> void:
	var t := create_tween()
	var base_x := board.position.x
	for dx in [2.0, -2.0, 1.0, -1.0, 0.0]:
		t.tween_property(board, "position:x", base_x + dx, 0.04)
	for socket in [capital_socket, small_socket]:
		var ft := create_tween()
		ft.tween_property(socket, "modulate", Color(1, 0.6, 0.6), 0.08)
		ft.tween_property(socket, "modulate", Color.WHITE, 0.2)

# ---------- placing ----------

func _place_letter(letter: String) -> void:
	GameUIManager.consume_hotbar_item(letter)
	var is_capital := letter == target_letter
	var socket: Panel = capital_socket if is_capital else small_socket
	var sprite: Sprite2D = capital_letter if is_capital else small_letter
	var ghost: Sprite2D = capital_ghost if is_capital else small_ghost
	if is_capital:
		placed_upper = true
	else:
		placed_lower = true

	sprite.texture = _letter_icon(letter)
	var fit := _fit_scale(sprite.texture)
	sprite.visible = true
	ghost.visible = false
	sprite.scale = Vector2.ZERO
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector2.ONE * fit * 1.4, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "scale", Vector2.ONE * fit, 0.1)
	_bounce(socket, 1.12)

	if placed_upper and placed_lower:
		_pair_complete()

func _pair_complete() -> void:
	is_advancing = true
	var seq = _seq()
	var index: int = seq.current_index if seq else 0
	if dots.is_empty():
		progress_label.text = "%d / %d" % [index + 1, seq.letter_order.size() if seq else 0]
	elif index < dots.size():
		var dt := create_tween()
		dt.tween_interval(0.2)
		dt.tween_property(dots[index], "self_modulate", DOT_DONE, 0.15)
	# celebrate: board hops, both letters wiggle
	var t := create_tween()
	t.tween_interval(0.25)
	t.tween_callback(_bounce.bind(board, 1.1))
	for s in [capital_letter, small_letter]:
		var w := create_tween()
		w.tween_interval(0.25)
		w.tween_property(s, "rotation", 0.25, 0.08)
		w.tween_property(s, "rotation", -0.25, 0.08)
		w.tween_property(s, "rotation", 0.0, 0.08)
	await get_tree().create_timer(1.0).timeout
	_advance_letter()

func _advance_letter() -> void:
	var seq = _seq()
	if seq:
		seq.advance()
		if seq.is_complete():
			is_done = true
			is_advancing = false
			board.self_modulate = Color(1.15, 1.1, 0.8)
			GameUIManager.complete_mission_2()
			return
		target_letter = seq.current_letter()
	# shrink the old pair away, then show the next letter's shadows
	var t := create_tween().set_parallel(true)
	t.tween_property(capital_letter, "scale", Vector2.ZERO, 0.15)
	t.tween_property(small_letter, "scale", Vector2.ZERO, 0.15)
	await t.finished
	placed_upper = false
	placed_lower = false
	_reset_slots()
	for g in [capital_ghost, small_ghost]:
		g.modulate.a = 0.0
		create_tween().tween_property(g, "modulate:a", 0.28, 0.25)
	is_advancing = false

func _reset_slots() -> void:
	capital_letter.visible = false
	small_letter.visible = false
	capital_letter.rotation = 0.0
	small_letter.rotation = 0.0
	capital_ghost.visible = true
	small_ghost.visible = true
	capital_ghost.texture = _letter_icon(target_letter)
	small_ghost.texture = _letter_icon(target_letter.to_lower())
	capital_ghost.scale = Vector2.ONE * _fit_scale(capital_ghost.texture)
	small_ghost.scale = Vector2.ONE * _fit_scale(small_ghost.texture)

# ---------- helpers ----------

func _build_dots() -> void:
	var seq = _seq()
	var count: int = seq.letter_order.size() if seq else 0
	if count > MAX_DOTS:
		# too many letters for dots: show "done / total" instead
		progress_dots.visible = false
		progress_label.visible = true
		progress_label.text = "%d / %d" % [seq.current_index, count]
		return
	for i in count:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(4, 4)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.WHITE
		sb.set_corner_radius_all(2)
		dot.add_theme_stylebox_override("panel", sb)
		dot.self_modulate = DOT_EMPTY
		progress_dots.add_child(dot)
		dots.append(dot)

func _bounce(node: Control, amount: float) -> void:
	var t := create_tween()
	t.tween_property(node, "scale", Vector2.ONE * amount, 0.08)
	t.tween_property(node, "scale", Vector2.ONE, 0.12)

## Same scale for every letter so small letters look smaller than capitals,
## but shrink tall ones (b, d, f, h, k, l, ...) so they never spill out of the slot.
func _fit_scale(tex: Texture2D) -> float:
	if tex == null:
		return LETTER_SCALE
	var biggest: float = max(tex.get_width(), tex.get_height())
	return min(LETTER_SCALE, SLOT_FIT / biggest)

func _letter_icon(letter: String) -> Texture2D:
	var prefix = "capital_" if letter == letter.to_upper() else "small_"
	return load(LETTER_ICON_PATH + prefix + letter + ".tres")
