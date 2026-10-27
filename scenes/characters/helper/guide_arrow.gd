extends Node2D
class_name GuideArrow

## A little arrow that circles the player and points to where a
## helper said to go. It stays until that's done: the item is collected, the
## mission is started, or the player reaches the place.
## A helper adds it to the player (see helper_npc.gd).

@onready var pivot: Node2D = $Pivot
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var arrow: Sprite2D = $Pivot/Arrow

## The arrow circles around the whole player (a ring around the body) and points
## outward, toward the target, so it never covers the player.
## Pivot (y -6 from the player) is the center of that ring = the middle of the body.
## GuideArrow itself sits at the feet (y +2) so it's drawn on top of the player.
const RADIUS := Vector2(17, 17)

var target: Node2D = null
var is_done: Callable
var leaving := false

func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)

func point_to(new_target: Node2D, done_check: Callable) -> void:
	target = new_target
	is_done = done_check
	leaving = false
	visible = true
	_update_rotation()
	anim.play("appear")
	anim.queue("pulse")

func _process(_delta: float) -> void:
	if leaving:
		return
	if not GameManager.helper_hints or target == null or not is_instance_valid(target) or (is_done.is_valid() and is_done.call()):
		_leave()
		return
	_update_rotation()

func _update_rotation() -> void:
	if target == null or not is_instance_valid(target):
		return
	var to := target.global_position - pivot.global_position
	pivot.visible = to.length() > 10.0
	var ang := to.angle()
	arrow.position = Vector2(cos(ang) * RADIUS.x, sin(ang) * RADIUS.y)
	arrow.rotation = ang

func _leave() -> void:
	leaving = true
	target = null
	anim.play("disappear")

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"disappear" and leaving:
		queue_free()
