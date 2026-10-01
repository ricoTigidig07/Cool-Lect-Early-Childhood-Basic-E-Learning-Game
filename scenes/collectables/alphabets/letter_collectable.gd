extends CollectableComponent
class_name LetterCollectible

@export var letter_sequence: NodePath

func _ready() -> void:
	super._ready()
	var seq = get_node_or_null(letter_sequence)
	# letters stay hidden until the Teacher starts the lesson
	if seq and seq.has_signal("started") and not seq.is_started:
		visible = false
		set_deferred("monitoring", false)
		seq.started.connect(_on_lesson_started, CONNECT_ONE_SHOT)

func _on_lesson_started() -> void:
	visible = true
	monitoring = true
	scale = Vector2.ZERO
	var t := create_tween()
	t.tween_interval(randf_range(0.0, 0.4))
	t.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Only the letter the lesson is on right now can be picked up.
func start_hold() -> void:
	var seq = get_node_or_null(letter_sequence)
	if seq and not seq.is_collectible(item_type):
		_shake_no()
		return
	super.start_hold()

func interact() -> void:
	var seq = get_node_or_null(letter_sequence)
	if seq and not seq.is_collectible(item_type):
		return
	super.interact()

func _shake_no() -> void:
	var sprite = get_node_or_null("Sprite2D")
	if sprite == null:
		return
	var t := create_tween()
	for angle in [14.0, -14.0, 9.0, -9.0, 0.0]:
		t.tween_property(sprite, "rotation_degrees", angle, 0.05)

func _finish_collect() -> void:
	GameUIManager.give_hotbar_item(item_type, 1)
	collected.emit(collectable_name, item_type)
	queue_free()
