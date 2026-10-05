extends CollectableComponent
class_name PaintBucket

## A bucket of paint. Hidden until the Painter starts the lesson.
## Paint the easel doesn't need (and can't be mixed into what it needs) wiggles.

@export var easel: NodePath
@export_enum("red", "orange", "yellow", "green", "blue", "purple", "pink", "brown", "black", "white", "grey") var paint_color: String = "red"

func _ready() -> void:
	item_type = paint_color
	collectable_name = paint_color.capitalize() + " paint"
	var paint = get_node_or_null("Sprite2D/Paint")
	if paint:
		paint.self_modulate = PaintColors.color(paint_color)
	super._ready()
	var e = get_node_or_null(easel)
	if e and not e.is_started:
		visible = false
		set_deferred("monitoring", false)
		e.started.connect(_on_lesson_started, CONNECT_ONE_SHOT)

func _on_lesson_started() -> void:
	visible = true
	monitoring = true
	scale = Vector2.ZERO
	var t := create_tween()
	t.tween_interval(randf_range(0.0, 0.4))
	t.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func start_hold() -> void:
	var e = get_node_or_null(easel)
	if e and not e.wants_paint(item_type):
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
	PaintColors.register_icon(item_type)
	GameUIManager.give_hotbar_item(item_type, 1)
	collected.emit(collectable_name, item_type)
	queue_free()
