extends Control

## Soft rotating rays behind the selected card.

@export var ray_count := 14
@export var speed := 0.08
@export var ray_color := Color(1, 1, 1, 0.35):
	set(v):
		ray_color = v
		queue_redraw()

var angle := 0.0

func _process(delta: float) -> void:
	angle += speed * delta
	queue_redraw()

func _draw() -> void:
	var c := size / 2.0
	var r := size.length()
	var step := TAU / ray_count
	for i in ray_count:
		var a := angle + i * step
		var pts := PackedVector2Array([c, c + Vector2.from_angle(a) * r, c + Vector2.from_angle(a + step * 0.5) * r])
		draw_colored_polygon(pts, Color(ray_color, 0.45))
