class_name CollectableComponent
extends Area2D

@export var collectable_name: String = ""
@export var item_type: String = ""
@export var required_item: String = ""

signal collected(collectable_name: String, item_type: String)

const HOLD_DURATION := 1.0

@onready var hold_indicator: TextureProgressBar = $HoldIndicator
const NAME_LABEL_SCENE := preload("res://scenes/components/name_label.tscn")
## Name shown above the item when the player is near. Empty = use Collectable Name.
@export var display_name: String = ""

@onready var name_label: Label = get_node_or_null("NameLabel")

var player_ref: Node2D = null
## The player who picked this up (player_ref is cleared when the area stops monitoring).
var collector: Node2D = null
var is_collecting: bool = false
var is_holding: bool = false
var hold_progress: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	hold_indicator.visible = false
	if name_label == null:
		name_label = NAME_LABEL_SCENE.instantiate()
		add_child(name_label)
	if display_name != "":
		name_label.text = display_name
	elif name_label.text == "" or name_label.text == "Name":
		name_label.text = collectable_name.substr(0, 1).to_upper() + collectable_name.substr(1)
	name_label.visible = false
	if item_type == "fruits":
		_hide_until_quest()

## Fruits stay hidden until the player says "Yes" to Momo.
func _hide_until_quest() -> void:
	visible = false
	set_deferred("monitoring", false)
	QuestManager.quest_started.connect(_on_quest_started, CONNECT_ONE_SHOT)

func _on_quest_started() -> void:
	visible = true
	monitoring = true
	scale = Vector2.ZERO
	var t := create_tween()
	t.tween_interval(randf_range(0.0, 0.4))
	t.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_body_entered(body: Node2D) -> void:
	if body is Player01:
		InteractionManager.register(self)
		player_ref = body
		name_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is Player01:
		InteractionManager.unregister(self)
		player_ref = null
		name_label.visible = false

func start_hold() -> void:
	if is_collecting:
		return
	if player_ref and player_ref.has_method("face_toward"):
		player_ref.face_toward(global_position)
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
	collector = player_ref
	set_deferred("monitoring", false)
	InteractionManager.unregister(self)
	name_label.visible = false
	
	var shadow = get_node_or_null("Shadow")
	if shadow:
		shadow.visible = false

	if name_label:
		name_label.visible = false

	_play_pickup_animation()

const COLLECT_FX := preload("res://scenes/components/collect_fx.tscn")

## Pickup animation (same feel as the main menu): the item squashes, hops in an
## arc over the player's head while spinning, bursts into a star + sparkles,
## then drops into the player, who does a happy little hop.
func _play_pickup_animation() -> void:
	var start := global_position
	var target := start + Vector2(0, -20)
	if collector:
		target = collector.global_position + Vector2(0, -24)
	var peak := (start + target) / 2.0 + Vector2(0, -28)
	z_index = 50
	_player_hop()    
	var t := create_tween()
	# 1. squash and stretch, getting ready to jump
	t.tween_property(self, "scale", Vector2(1.3, 0.7), 0.07)
	t.tween_property(self, "scale", Vector2(0.8, 1.25), 0.07)
	# 2. hop along an arc to above the player's head, spinning
	t.tween_method(_move_on_arc.bind(start, peak, target), 0.0, 1.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "rotation_degrees", 360.0, 0.38)
	t.parallel().tween_property(self, "scale", Vector2.ONE * 1.35, 0.38)
	# 3. star + sparkles, a little bounce in the air
	t.tween_callback(_burst.bind(target))
	t.tween_property(self, "scale", Vector2.ONE, 0.07)
	t.tween_property(self, "scale", Vector2.ONE * 1.2, 0.07)
	t.tween_interval(0.12)
	# 4. drop into the player
	t.tween_property(self, "global_position", target + Vector2(0, 18), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "scale", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(_finish_collect)

## Moves along a curve from a to c, bending towards b (a smooth jump arc).
func _move_on_arc(progress: float, a: Vector2, b: Vector2, c: Vector2) -> void:
	global_position = a.lerp(b, progress).lerp(b.lerp(c, progress), progress)

func _burst(at: Vector2) -> void:
	var fx := COLLECT_FX.instantiate()
	var holder: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	holder.add_child(fx)
	fx.global_position = at

func _player_hop() -> void:
	if collector == null or not is_instance_valid(collector):
		return
	if collector.has_method("celebrate"):
		collector.celebrate()
		return
	var body = collector.get_node_or_null("AnimatedSprite2D2")
	if body == null:
		return
	var t := body.create_tween()
	t.tween_property(body, "position:y", -11.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(body, "position:y", -6.0, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _finish_collect() -> void:
	QuestManager.collect_item(collectable_name)
	collected.emit(collectable_name, item_type)
	queue_free()
