extends Control

## Draws the roller-blind that the subject selector comes down on:
## see-through tinted fabric with slats, two ladder cords, a wooden
## bottom rod and a pull ring. The tint follows the selected subject.

@export var tint := Color(0.97, 0.62, 0.3):
	set(v):
		tint = v
		queue_redraw()
@export var fabric_alpha := 0.42
@export var slat_gap := 42.0
@export var rod_height := 22.0

func _draw() -> void:
	var rod_y := size.y - rod_height - 20.0
	# fabric
	draw_rect(Rect2(0, 0, size.x, rod_y), Color(tint.lerp(Color.WHITE, 0.35), fabric_alpha))
	# slats: a soft shadow line with a light highlight under it
	var y := slat_gap
	while y < rod_y - 4.0:
		draw_rect(Rect2(0, y, size.x, 3), Color(tint.darkened(0.25), 0.35))
		draw_rect(Rect2(0, y + 3, size.x, 2), Color(1, 1, 1, 0.25))
		y += slat_gap
	# ladder cords
	for x in [size.x * 0.16, size.x * 0.84]:
		draw_rect(Rect2(x - 1.5, 0, 3, rod_y), Color(1, 1, 1, 0.45))
	# wooden bottom rod
	var rod := Rect2(-6, rod_y, size.x + 12, rod_height)
	draw_rect(rod, Color(0.55, 0.36, 0.24))
	draw_rect(Rect2(rod.position.x, rod_y, rod.size.x, 5), Color(0.7, 0.5, 0.34))
	draw_rect(Rect2(rod.position.x, rod_y + rod_height - 5, rod.size.x, 5), Color(0.42, 0.26, 0.17))
	# pull cord + ring
	var cx := size.x / 2.0
	draw_rect(Rect2(cx - 1.5, rod_y + rod_height, 3, 10), Color(0.42, 0.26, 0.17))
	draw_arc(Vector2(cx, rod_y + rod_height + 18), 8.0, 0, TAU, 20, Color(0.55, 0.36, 0.24), 4.0)
