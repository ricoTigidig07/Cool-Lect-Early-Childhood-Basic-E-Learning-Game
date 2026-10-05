extends Node2D

## The "you got it!" burst shown above the player when an item is collected:
## a star pops up and sparkles fly out. Edit the look in collect_fx.tscn
## (AnimationPlayer → "pop"). It removes itself when the animation ends.

@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	anim.play("pop")
	anim.animation_finished.connect(func(_n): queue_free())
