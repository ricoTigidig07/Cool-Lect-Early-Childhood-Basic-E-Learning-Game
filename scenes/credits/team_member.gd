@tool
extends Node2D

## One Cool-LecT team member for the credits: an 8-frame sprite sheet
## (48 x 40 per frame) and a dancing name board under the feet.
## The node's position is where the feet stand.

@export var sheet: Texture2D:
	set(v):
		sheet = v
		_apply()
@export var nickname := "NAME":
	set(v):
		nickname = v
		_apply()
## How big the pixel art is drawn (the board keeps its own size).
@export var sprite_scale := 5.0:
	set(v):
		sprite_scale = v
		_apply()
## 1 = normal speed. Lower for a slow, sleepy loop.
@export var speed := 1.0:
	set(v):
		speed = v
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_inside_tree():
		return
	$Sprite2D.texture = sheet
	$Sprite2D.scale = Vector2(sprite_scale, sprite_scale)
	$Board/Panel/Name.text = nickname
	$AnimationPlayer.speed_scale = speed
