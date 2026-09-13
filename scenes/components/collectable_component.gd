class_name CollectableComponent
extends Area2D

@export var collectable_name: String = ""
@export var item_type: String = ""

signal collected(collectable_name: String, item_type: String)

const HOLD_DURATION := 1.0

@onready var hold_indicator: TextureProgressBar = $HoldIndicator

var player_ref: Node2D = null
var is_collecting: bool = false
var is_holding: bool = false
var hold_progress: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	hold_indicator.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body is Player01:
		InteractionManager.register(self)
		player_ref = body

func _on_body_exited(body: Node2D) -> void:
	if body is Player01:
		InteractionManager.unregister(self)
		player_ref = null

func start_hold() -> void:
	if is_collecting:
		return
	is_holding = true
	hold_progress = 0.0
	hold_indicator.visible = true
	hold_indicator.value = 0

func cancel_hold() -> void:
	is_holding = false
	hold_progress = 0.0
	if hold_indicator:
		hold_indicator.visible = false

func _process(delta: float) -> void:
	if is_holding:
		hold_progress += delta / HOLD_DURATION
		hold_indicator.value = hold_progress * 100
		if hold_progress >= 1.0:
			_complete_hold()

func _complete_hold() -> void:
	is_holding = false
	if hold_indicator:
		hold_indicator.visible = false
	interact()

func interact() -> void:
	if is_collecting:
		return
	is_collecting = true
	set_deferred("monitoring", false)
	InteractionManager.unregister(self)

	var shadow = get_node_or_null("Shadow")
	if shadow:
		shadow.visible = false

	_play_pickup_animation()

func _play_pickup_animation() -> void:
	var above_player = global_position
	if player_ref:
		above_player = player_ref.global_position + Vector2(0, -20)

	var tween = create_tween()
	tween.tween_property(self, "global_position", above_player, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_play_shake)

func _play_shake() -> void:
	var shake_tween = create_tween()
	shake_tween.tween_property(self, "rotation_degrees", 15.0, 0.06)
	shake_tween.tween_property(self, "rotation_degrees", -15.0, 0.06)
	shake_tween.tween_property(self, "rotation_degrees", 10.0, 0.06)
	shake_tween.tween_property(self, "rotation_degrees", -10.0, 0.06)
	shake_tween.tween_property(self, "rotation_degrees", 0.0, 0.06)
	shake_tween.tween_callback(_play_shrink_down)

func _play_shrink_down() -> void:
	var shrink_tween = create_tween()
	shrink_tween.tween_property(self, "global_position:y", global_position.y + 20.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	shrink_tween.parallel().tween_property(self, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	shrink_tween.tween_callback(_finish_collect)

func _finish_collect() -> void:
	QuestManager.collect_item(collectable_name)
	collected.emit(collectable_name, item_type)
	queue_free()
