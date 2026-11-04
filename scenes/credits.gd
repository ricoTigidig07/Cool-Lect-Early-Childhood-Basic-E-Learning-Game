extends Control

## Main Menu > Credits.
## The "roll" animation scrolls the team up one by one, then shows everyone
## together. The credits song starts by itself (AudioManager, "credits" in the file name).

const MAIN_MENU := "res://scenes/main_menu.tscn"

const WHEEL_STEP := 60.0       # pixels one mouse wheel click scrolls

@onready var anim: AnimationPlayer = $AnimationPlayer

var _speed := 75.0             # pixels per second the credits roll (read from the animation)
var _dragging := false
var _roll_end := -1.0           # when the names stop moving (the team finale after that)


func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)
	# how fast the roll moves, so a drag of N pixels moves the credits N pixels
	var roll := anim.get_animation(&"roll")
	var t := roll.find_track(NodePath("Roll/Strip:position:y"), Animation.TYPE_VALUE)
	if t >= 0 and roll.track_get_key_count(t) >= 2:
		var dist := absf(float(roll.track_get_key_value(t, 0)) - float(roll.track_get_key_value(t, 1)))
		var time := roll.track_get_key_time(t, 1) - roll.track_get_key_time(t, 0)
		if dist > 0.0 and time > 0.0:
			_speed = dist / time
		_roll_end = roll.track_get_key_time(t, 1)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"roll":
		anim.play(&"idle")


# ---------- scrolling by hand (drag / swipe / mouse wheel) ----------

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_scroll_by(WHEEL_STEP)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_scroll_by(-WHEEL_STEP)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_set_dragging(mb.pressed)
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).index == 0:
		_set_dragging((event as InputEventScreenTouch).pressed)
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == 0:
		_scroll_by((event as InputEventScreenDrag).relative.y)
	elif event is InputEventMouseMotion and _dragging and event.device != InputEvent.DEVICE_ID_EMULATION:
		_scroll_by((event as InputEventMouseMotion).relative.y)


## Holding the finger / mouse stops the roll; letting go lets it roll on.
func _set_dragging(on: bool) -> void:
	_dragging = on
	if anim.current_animation == &"roll":
		anim.speed_scale = 0.0 if on else 1.0


## Moves the credits by `dy` pixels (finger down = back to the start, up = forward).
func _scroll_by(dy: float) -> void:
	if dy == 0.0:
		return
	var length := anim.get_animation(&"roll").length
	var at := anim.current_animation_position if anim.current_animation == &"roll" else length
	if _roll_end > 0.0 and at > _roll_end and dy > 0.0:
		at = _roll_end              # going back from the finale: start where the names stopped
	var to := clampf(at - dy / _speed, 0.0, length - 0.01)
	if anim.current_animation != &"roll":
		if to >= length - 0.02:
			return                  # already at the end
		anim.play(&"roll")
	anim.seek(to, true)
	anim.speed_scale = 0.0 if _dragging else 1.0


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
