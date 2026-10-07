extends CollectableComponent
class_name ShapeCollectible

## A shape block the player can pick up. item_type is the shape: "circle", "square", ...
## Hidden until the Builder starts the lesson. Shapes the picture doesn't need wiggle.

@export var shape_board: NodePath
## The shape's color (the shapes picture is white so it can be any color).
@export var tint: Color = Color.WHITE

func _ready() -> void:
	super._ready()
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.self_modulate = tint
	var board = get_node_or_null(shape_board)
	if board and not board.is_started:
		visible = false
		set_deferred("monitoring", false)
		board.started.connect(_on_lesson_started, CONNECT_ONE_SHOT)

func _on_lesson_started() -> void:
	visible = true
	monitoring = true
	scale = Vector2.ZERO
	var t := create_tween()
	t.tween_interval(randf_range(0.0, 0.4))
	t.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func start_hold() -> void:
	var board = get_node_or_null(shape_board)
	if board and not board.needs(item_type):
		_shake_no()
		return
	# hotbar full (5 slots): place some shapes first, so this one isn't lost
	var bar = GameUIManager.hotbar
	if bar and not bar.slot_by_item.has(item_type) and bar._find_empty_slot() == null:
		_shake_no()
		return
	super.start_hold()

func _shake_no() -> void:
	var sprite = get_node_or_null("Sprite2D")
	if sprite == null:
		return
	var t := create_tween()
	for angle in [14.0, -14.0, 9.0, -9.0, 0.0]:
		t.tween_property(sprite, "rotation_degrees", angle, 0.05)

func _finish_collect() -> void:
	# let the hotbar show this shape's picture, in its color
	var hotbar = GameUIManager.hotbar
	var sprite = get_node_or_null("Sprite2D")
	if hotbar and sprite and not hotbar.item_icons.has(item_type):
		hotbar.item_icons[item_type] = _tinted_icon(sprite.texture)
	var board = get_node_or_null(shape_board)
	if board and board.has_method("remember_tint"):
		board.remember_tint(item_type, tint)
	GameUIManager.give_hotbar_item(item_type, 1)
	collected.emit(collectable_name, item_type)
	queue_free()

func _tinted_icon(tex: Texture2D) -> Texture2D:
	if tex == null or tint == Color.WHITE:
		return tex
	var img := tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			img.set_pixel(x, y, img.get_pixel(x, y) * tint)
	return ImageTexture.create_from_image(img)
