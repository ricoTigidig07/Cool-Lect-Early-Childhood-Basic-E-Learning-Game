extends Node2D

@onready var border = $AvatarPanel
@onready var portrait = $AvatarPanel/AnimatedSprite2D

func set_talking(is_talking: bool) -> void:
	if is_talking:
		portrait.play("merchant_talking")
	else:
		portrait.play("merchant_defaults")
