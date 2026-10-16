extends Area2D

## A pot for mixing paint. Hold the interact button with a paint bucket equipped
## to pour it in. Two colors that mix (red + yellow, blue + yellow ...) turn into
## a new bucket of paint in your hotbar.

signal mixed(first: String, second: String, result: String)

## The easel this pot mixes for. Empty = the "Easel" next to it.
## Only mixes the easel still needs are allowed, so paint is never wasted.
@export var easel: NodePath

const HOLD_DURATION := 0.8

@onready var paint: Sprite2D = $Paint
@onready var hold_indicator: TextureProgressBar = $HoldIndicator
@onready var bubble: Label = get_node_or_null("Bubble")

var contents: Array[String] = []
var is_holding := false
var hold_progress := 0.0
var pending_color := ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	hold_indicator.visible = false
	paint.visible = false
	if bubble:
		bubble.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body is Player01:
		InteractionManager.register(self)
		if bubble:
			bubble.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is Player01:
		InteractionManager.unregister(self)
		cancel_hold()
		if bubble:
			bubble.visible = false

func start_hold() -> void:
	var equipped := GameUIManager.get_equipped_item()
	if not PaintColors.is_paint(equipped):
		return
	if contents.is_empty():
		# the first color must be part of a mix the picture still needs
		if not _is_useful_first(equipped):
			_wrong_feedback("Not this color!")
			return
		if not _has_room_to_mix(equipped):
			_wrong_feedback("Paint first, then mix!")
			return
	else:
		# the second color must make a color the picture still needs
		var result := PaintColors.mix(contents[0], equipped)
		if result == "" or not _wanted_mixes().has(result):
			_wrong_feedback("Those don't mix!" if result == "" else "We don't need %s!" % result)
			return
		if not _has_room_after([equipped]):
			_wrong_feedback("Paint first, then mix!")
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
			_pour(pending_color)

func _pour(color: String) -> void:
	AudioManager.play_sfx("mix")
	GameUIManager.consume_hotbar_item(color)
	contents.append(color)
	paint.visible = true
	if contents.size() == 1:
		paint.self_modulate = PaintColors.color(color)
		_set_bubble("%s + ?" % color.capitalize())
		return
	var result := PaintColors.mix(contents[0], contents[1])
	_set_bubble("%s + %s = %s!" % [contents[0].capitalize(), contents[1].capitalize(), result.capitalize()])
	mixed.emit(contents[0], contents[1], result)
	contents.clear()
	# swirl the paint into the new color, then hand out the new bucket
	var t := create_tween()
	t.tween_property(paint, "self_modulate", PaintColors.color(result), 0.6)
	t.parallel().tween_property(paint, "rotation", TAU, 0.6)
	t.tween_callback(func():
		paint.rotation = 0.0
		PaintColors.register_icon(result)
		GameUIManager.give_hotbar_item(result, 1))
	t.tween_interval(0.8)
	t.tween_callback(func(): paint.visible = false)

func _easel() -> Node:
	var e = get_node_or_null(easel)
	if e == null:
		e = get_parent().get_node_or_null("Easel")
	return e

## Mixed colors the picture still needs and the player doesn't have yet.
func _wanted_mixes() -> Array[String]:
	var e = _easel()
	var out: Array[String] = []
	for result in PaintColors.RECIPES.keys():
		if e and not e.needs(result):
			continue
		if _holding(result):
			continue
		out.append(result)
	return out

func _is_useful_first(color: String) -> bool:
	for result in _wanted_mixes():
		if PaintColors.RECIPES[result].has(color):
			return true
	return false

func _holding(color: String) -> bool:
	var bar = GameUIManager.hotbar
	return bar != null and "slot_by_item" in bar and bar.slot_by_item.has(color)

## True if the hotbar will have a free slot for the new paint after pouring
## these colors (pouring the last bucket of a color frees its slot).
func _has_room_after(pouring: Array) -> bool:
	var bar = GameUIManager.hotbar
	if bar == null or not bar.has_method("_find_empty_slot"):
		return true
	if bar._find_empty_slot() != null:
		return true
	for c in pouring:
		var slot = bar.slot_by_item.get(c)
		if slot != null and int(slot.get_node("Label").text) <= 1:
			return true
	return false

## Checked before the first pour, so no paint is wasted when the hotbar is full.
func _has_room_to_mix(first: String) -> bool:
	for result in _wanted_mixes():
		var recipe: Array = PaintColors.RECIPES[result]
		if recipe.has(first):
			var partner: String = recipe[1] if recipe[0] == first else recipe[0]
			if _has_room_after([first, partner]):
				return true
	return false

func _set_bubble(text: String) -> void:
	if bubble:
		bubble.text = text

func _wrong_feedback(message: String = "Those don't mix!") -> void:
	AudioManager.play_sfx("wrong")
	var t := create_tween()
	var base_x := paint.position.x
	for dx in [2.0, -2.0, 1.0, -1.0, 0.0]:
		t.tween_property(paint, "position:x", base_x + dx, 0.04)
	_set_bubble(message)
