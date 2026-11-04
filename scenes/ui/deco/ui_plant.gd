@tool
extends Node2D

## A little plant growing on the wooden UI (grass, leaves, flowers, mushrooms).
## Put it as a child of a panel / button / sign and choose where it grows:
##  - at:    where on the parent (0,0 = top-left corner, 1,1 = bottom-right corner,
##           0.5,0 = middle of the top edge ...). It follows the parent when it changes size.
##  - nudge: extra pixels from there.
## The picture comes from "Mushrooms, Flowers, Stones.png" (Sprout Lands).
## It is a Node2D on purpose: containers (PanelContainer, HBox...) don't move it around.
## In the editor you can also just drag it (and scale it): "nudge" and "pixel_scale" follow.

const SHEET := preload("res://assets/sprites/game/Sprout Lands - Sprites - premium pack/Objects/Mushrooms, Flowers, Stones.png")
## name: [column, row, lowest drawn pixel + 1]  (16 x 16 cells)
const PLANTS := {
	"grass": [2, 2, 15], "grass_big": [3, 2, 15], "leaves": [0, 2, 13], "leaves_two": [1, 2, 15],
	"flower_yellow": [1, 3, 15], "flower_yellow_big": [2, 3, 15], "flower_pink": [5, 3, 13],
	"flower_pink_small": [4, 3, 12], "tulip_pink": [8, 3, 14], "flower_white": [10, 3, 13],
	"flower_purple": [1, 4, 16], "flower_blue": [5, 4, 14], "flower_blue_small": [4, 4, 13],
	"flower_blue_tall": [9, 4, 13], "mushroom_red": [1, 0, 15], "mushrooms_red": [2, 0, 15],
	"mushroom_purple": [3, 0, 14], "mushrooms_purple": [4, 0, 15],
}

@export_enum("grass", "grass_big", "leaves", "leaves_two", "flower_yellow", "flower_yellow_big",
		"flower_pink", "flower_pink_small", "tulip_pink", "flower_white", "flower_purple",
		"flower_blue", "flower_blue_small", "flower_blue_tall", "mushroom_red", "mushrooms_red",
		"mushroom_purple", "mushrooms_purple") var plant: String = "grass":
	set(v):
		plant = v
		_refresh()
@export var at := Vector2(0, 0):
	set(v):
		at = v
		_place()
@export var nudge := Vector2.ZERO:
	set(v):
		nudge = v
		_place()

var _placing := false
@export var pixel_scale := 3.0:
	set(v):
		pixel_scale = v
		_refresh()
@export var flip := false:
	set(v):
		flip = v
		_refresh()
## Sways gently in the wind (not for mushrooms).
@export var sway := true

@onready var pic: Sprite2D = $Pic
@onready var anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_refresh()
	var parent := get_parent() as Control
	if parent and not parent.resized.is_connected(_place):
		parent.resized.connect(_place)
	_place()
	if Engine.is_editor_hint():
		set_notify_local_transform(true)    # dragged in the editor -> remember where
		return
	if sway and not plant.begins_with("mushroom"):
		anim.play(&"sway")
		anim.seek(randf() * anim.current_animation_length, true)
		anim.speed_scale = randf_range(0.8, 1.2)


func _refresh() -> void:
	if not is_node_ready():
		return
	var p: Array = PLANTS.get(plant, PLANTS["grass"])
	var tex := AtlasTexture.new()
	tex.atlas = SHEET
	tex.region = Rect2(p[0] * 16, p[1] * 16, 16, 16)
	pic.texture = tex
	pic.centered = false
	pic.offset = Vector2(-8, -p[2])        # the plant's base sits on this node
	pic.flip_h = flip
	_placing = true
	scale = Vector2.ONE * pixel_scale
	_placing = false


func _place() -> void:
	var parent := get_parent() as Control
	if parent:
		_placing = true
		position = parent.size * at + nudge
		_placing = false


## Editor only: when the plant is dragged or scaled by hand, keep that spot and size.
func _notification(what: int) -> void:
	if what != NOTIFICATION_LOCAL_TRANSFORM_CHANGED or _placing or not Engine.is_editor_hint():
		return
	var parent := get_parent() as Control
	if parent:
		nudge = (position - parent.size * at).round()
	if not is_equal_approx(scale.x, pixel_scale):
		pixel_scale = snappedf(scale.x, 0.1)
