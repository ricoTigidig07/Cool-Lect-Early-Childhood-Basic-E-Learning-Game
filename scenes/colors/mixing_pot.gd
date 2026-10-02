extends Area2D

## A pot for mixing paint. Hold the interact button with a paint bucket equipped
## to pour it in. Two colors that mix (red + yellow, blue + yellow ...) turn into
## a new bucket of paint in your hotbar.

signal mixed(first: String, second: String, result: String)

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
	# the second color must make something with the first one
	if contents.size() == 1 and PaintColors.mix(contents[0], equipped) == "":
		_wrong_feedback()
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

func _set_bubble(text: String) -> void:
	if bubble:
		bubble.text = text

func _wrong_feedback() -> void:
	var t := create_tween()
	var base_x := paint.position.x
	for dx in [2.0, -2.0, 1.0, -1.0, 0.0]:
		t.tween_property(paint, "position:x", base_x + dx, 0.04)
	_set_bubble("Those don't mix!")
