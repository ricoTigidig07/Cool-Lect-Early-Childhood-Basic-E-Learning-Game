extends Node2D

## Makes the menu meadow cover the whole screen on any phone / tablet shape.
## The picture is 432 x 240 pixels; it is scaled up until it fills the screen
## (a little of the edges may be cut on very wide or tall screens, never empty bars).

const ART_SIZE := Vector2(432, 240)

func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var screen := get_viewport().get_visible_rect().size
	var k: float = max(screen.x / ART_SIZE.x, screen.y / ART_SIZE.y)
	scale = Vector2(k, k)
	position = (screen - ART_SIZE * k) / 2.0
