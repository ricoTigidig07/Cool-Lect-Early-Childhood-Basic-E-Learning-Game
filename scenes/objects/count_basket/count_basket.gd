extends Area2D
class_name CountBasket

## A basket with a number sign. The player drops items in one at a time
## (one hold = one item) and a big number pops up for each: 1... 2... 3...
## When the count matches the sign, the basket is full.
## Baskets stay locked until the level's NPC calls activate() on the
## "count_baskets" group (after the player says Yes).

signal filled

@export_range(1, 10) var target_count: int = 3
@export var accepted_item: String = "egg"
@export var item_texture: Texture2D
@export var item_scale: float = 0.6
@export var item_spacing: Vector2 = Vector2(9, -8)
@export var items_per_row: int = 5

@onready var number_icon: Sprite2D = $NumberIcon
@onready var item_anchor: Marker2D = $ItemAnchor
@onready var count_pop: Label = $CountPop
@onready var basket_sprite: Sprite2D = $Basket
@onready var hold_indicator: TextureProgressBar = $HoldIndicator

const HOLD_DURATION := 0.5
const NUMBER_ICON_PATH := "res://scenes/collectables/numbers/number_"
const POP_START_Y := -44.0

var current_count: int = 0
var is_full: bool = false
var is_active: bool = false
var is_holding: bool = false
var hold_progress: float = 0.0

var basket_base_x: float
var number_base_scale: Vector2
var pop_tween: Tween
var shake_tween: Tween

func _ready() -> void:
	add_to_group("count_baskets")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	hold_indicator.visible = false
	count_pop.visible = false
	basket_base_x = basket_sprite.position.x
	number_base_scale = number_icon.scale
	number_icon.texture = load(NUMBER_ICON_PATH + str(target_count) + ".tres")

func activate() -> void:
	is_active = true

func _on_body_entered(body: Node2D) -> void:
	if body is Player01:
		InteractionManager.register(self)

func _on_body_exited(body: Node2D) -> void:
	if body is Player01:
		InteractionManager.unregister(self)
		cancel_hold()

func start_hold() -> void:
	if not is_active:
		_show_pop("?", Color(1, 0.9, 0.5))
		return
	if GameUIManager.get_equipped_item() != accepted_item:
		return
	if is_full:
		_show_pop("Too many!", Color(0.9, 0.3, 0.3))
		_shake_basket()
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

func _complete_hold() -> void:
	cancel_hold()
	GameUIManager.consume_hotbar_item(accepted_item)
	current_count += 1
	_add_item_sprite(current_count - 1)
	_show_pop(str(current_count), Color(1, 1, 1))
	if current_count >= target_count:
		_on_filled()

func _add_item_sprite(index: int) -> void:
	var s := Sprite2D.new()
	s.texture = item_texture
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var col := index % items_per_row
	var row := index / items_per_row
	var in_row: int = mini(target_count - row * items_per_row, items_per_row)
	var row_width: float = (in_row - 1) * item_spacing.x
	s.position = Vector2(col * item_spacing.x - row_width / 2.0, row * item_spacing.y)
	item_anchor.add_child(s)
	s.scale = Vector2.ZERO
	var t := create_tween()
	t.tween_property(s, "scale", Vector2.ONE * item_scale * 1.3, 0.1)
	t.tween_property(s, "scale", Vector2.ONE * item_scale, 0.1)

func _show_pop(text: String, color: Color) -> void:
	if pop_tween:
		pop_tween.kill()
	count_pop.text = text
	count_pop.modulate = color
	count_pop.visible = true
	count_pop.position.y = POP_START_Y
	count_pop.pivot_offset = count_pop.size / 2.0
	count_pop.scale = Vector2(0.5, 0.5)
	pop_tween = create_tween()
	pop_tween.tween_property(count_pop, "scale", Vector2(1.3, 1.3), 0.12)
	pop_tween.tween_property(count_pop, "scale", Vector2.ONE, 0.1)
	pop_tween.parallel().tween_property(count_pop, "position:y", POP_START_Y - 10.0, 0.6)
	pop_tween.tween_property(count_pop, "modulate:a", 0.0, 0.3)
	pop_tween.tween_callback(func(): count_pop.visible = false)

func _shake_basket() -> void:
	if shake_tween:
		shake_tween.kill()
	basket_sprite.position.x = basket_base_x
	shake_tween = create_tween()
	for dx in [3.0, -3.0, 2.0, -2.0, 0.0]:
		shake_tween.tween_property(basket_sprite, "position:x", basket_base_x + dx, 0.05)

func _on_filled() -> void:
	is_full = true
	var t := create_tween()
	t.tween_property(number_icon, "scale", number_base_scale * 1.4, 0.12)
	t.tween_property(number_icon, "scale", number_base_scale, 0.12)
	basket_sprite.modulate = Color(0.85, 1.0, 0.85)
	filled.emit()
	if all_baskets_full():
		GameUIManager.complete_mission_2()

func all_baskets_full() -> bool:
	for basket in get_tree().get_nodes_in_group("count_baskets"):
		if not basket.is_full:
			return false
	return true
