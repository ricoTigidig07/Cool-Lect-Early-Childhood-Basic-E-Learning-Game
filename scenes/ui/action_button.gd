extends Control
## The big hand button (press and hold to pick up, tap to talk / use).
## Made for phones: any finger works, even while another finger is on the joystick,
## and the round touch area is bigger than the picture.
## Sends button_down / button_up like a normal Button, so the levels stay connected.

signal button_down
signal button_up

@onready var face: Control = $Face
@onready var press_anim: AnimationPlayer = $PressAnim
@onready var glow_anim: AnimationPlayer = $GlowAnim

const NO_TOUCH := -2
const MOUSE := -1
var _finger := NO_TOUCH

func _ready() -> void:
	set_ready(false)
	visibility_changed.connect(func(): if not is_visible_in_tree(): _cancel())

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel()
	elif what == NOTIFICATION_EXIT_TREE:
		_finger = NO_TOUCH

## The finger was lost (button hidden, app in the background): stop a hold, but don't
## count it as a tap.
func _cancel() -> void:
	if _finger == NO_TOUCH:
		return
	InteractionManager.pending_tap_target = null
	_release()

## Something to use is near: the button glows and looks fully awake.
func set_ready(on: bool) -> void:
	face.modulate.a = 1.0 if on else 0.75
	if on:
		glow_anim.play("pulse")
	else:
		glow_anim.play("off")

## Round touch area that fills the whole control (bigger than the button picture).
func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= size.x * 0.5

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _finger != NO_TOUCH and _finger != event.index:
			_release()          # the last finger's "up" was lost (e.g. a box opened under it): start fresh
		if event.pressed and _finger == NO_TOUCH:
			_press(event.index)
		elif not event.pressed and event.index == _finger:
			_release()
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return          # a phone finger pretending to be a mouse: the touch is already handled
		if event.pressed and _finger != NO_TOUCH:
			_release()          # the last "up" was lost: start fresh
		if event.pressed and _finger == NO_TOUCH:
			_press(MOUSE)
		elif not event.pressed and _finger == MOUSE:
			_release()
		accept_event()

func _press(finger: int) -> void:
	_finger = finger
	press_anim.play("press")
	button_down.emit()

func _release() -> void:
	if _finger == NO_TOUCH:
		return
	_finger = NO_TOUCH
	if press_anim and is_inside_tree():
		press_anim.play("release")
	button_up.emit()
