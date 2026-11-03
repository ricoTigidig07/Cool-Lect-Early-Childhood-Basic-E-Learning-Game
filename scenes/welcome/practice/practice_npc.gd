extends StaticBody2D

## Momo in the practice yard: no quest of his own. Tapping the hand button near him
## sends `talked`; practice_yard.gd decides what he says.

signal talked

## Which voice reads his lines and the name on the dialogue box (same as the real Momo).
var voice_id := "merchant"
var display_name := "Momo"

@onready var interaction_area: Area2D = $InteractionArea


func _ready() -> void:
	interaction_area.body_entered.connect(func(b: Node2D):
		if b is Player01:
			InteractionManager.register(self))
	interaction_area.body_exited.connect(func(b: Node2D):
		if b is Player01:
			InteractionManager.unregister(self))


func interact() -> void:
	talked.emit()


## The player is standing next to him.
func player_near() -> bool:
	for b in interaction_area.get_overlapping_bodies():
		if b is Player01:
			return true
	return false
