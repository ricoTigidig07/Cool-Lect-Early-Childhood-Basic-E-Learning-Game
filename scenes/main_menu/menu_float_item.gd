extends Node2D
class_name MenuFloatItem

## A floating pickup on the main menu: a letter, number, fruit, egg or shape.
## When the menu player collects it, it flies up, spins, shrinks, then
## re-appears somewhere else as a different random object.

var sprite: Sprite2D
var shadow: Sprite2D
var available := true
var world: Node
var bob_offset := randf() * TAU

const SHADOW_TEX := "res://assets/sprites/game/Sprout Lands - Sprites - premium pack/Objects/Items/item shadow.png"

func _ready() -> void:
	add_to_group("menu_interactable")
	shadow = Sprite2D.new()
	shadow.texture = load(SHADOW_TEX)
	# the shadow art is a thin strip at the bottom of a 16x16 image; lift it so
	# it sits right under the object instead of 6 px below it
	shadow.offset = Vector2(0, -6)
	shadow.modulate = Color(0, 0, 0, 1)
	add_child(shadow)
	sprite = Sprite2D.new()
	add_child(sprite)
	_randomize_look()
	_pop_in()

func _randomize_look() -> void:
	var look: Dictionary = world.random_item_look()
	sprite.texture = look.texture
	sprite.scale = Vector2.ONE * look.scale

func _process(_delta: float) -> void:
	if not available:
		return
	var t := Time.get_ticks_msec() / 1000.0 * 2.2 + bob_offset
	sprite.position.y = -12.0 + sin(t) * 2.5
	shadow.scale = Vector2.ONE * (0.85 - sin(t) * 0.12)

func collect_by(player: Node2D) -> void:
	available = false
	shadow.visible = false
	var t := create_tween()
	t.tween_property(self, "position", player.position + Vector2(0, -16), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "rotation_degrees", 360.0, 0.3)
	t.tween_property(self, "scale", Vector2.ZERO, 0.2)
	await t.finished
	visible = false
	await get_tree().create_timer(randf_range(1.5, 3.0)).timeout
	position = world.random_free_spot()
	sprite.rotation = 0.0
	_randomize_look()
	visible = true
	shadow.visible = true
	_pop_in()

func _pop_in() -> void:
	scale = Vector2.ZERO
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE * 1.25, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, 0.1)
	await t.finished
	available = true
