extends Control
## Big touch joystick for phones (also works with the mouse on a computer).
## The whole bottom-left area is the touch zone: put a finger anywhere there and the
## joystick appears right under it and stays fixed there while you drag to walk.
## Only the finger that started it can move it, so the hand button works at the same time.

@onready var base: Control = $Base
@onready var knob: Control = $Base/Knob
@onready var anim: AnimationPlayer = $Anim

## Where the knob may travel, compared to the base size (0.5 = the base edge).
const TRAVEL := 0.36
## Small moves near the middle don't walk (part of TRAVEL).
const DEAD_ZONE := 0.22
const DIRECTION_NAMES = ["right", "downright", "down", "downleft", "left", "upleft", "up", "upright"]

var direction := Vector2.ZERO
var direction_name := ""

const NO_TOUCH := -2
const MOUSE := -1
var _finger := NO_TOUCH
var _home := Vector2.ZERO
var _back: Tween

func _ready() -> void:
	_home = base.position
	visibility_changed.connect(func(): if not is_visible_in_tree(): _stop())

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		_stop()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _finger == NO_TOUCH:
			_start(event.index, event.position)
		elif not event.pressed and event.index == _finger:
			_stop()
		accept_event()
	elif event is InputEventScreenDrag:
		if event.index == _finger:
			_move(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return          # a phone finger pretending to be a mouse: the touch is already handled
		if event.pressed and _finger == NO_TOUCH:
			_start(MOUSE, event.position)
		elif not event.pressed and _finger == MOUSE:
			_stop()
		accept_event()
	elif event is InputEventMouseMotion and _finger == MOUSE and event.device != InputEvent.DEVICE_ID_EMULATION:
		_move(event.position)
		accept_event()

func _center() -> Vector2:
	return base.position + base.size * 0.5

func _travel() -> float:
	return base.size.x * TRAVEL

func _start(finger: int, at: Vector2) -> void:
	_finger = finger
	if _back:
		_back.kill()
	# the joystick sits fixed where the finger touched
	_place(at)
	anim.play("press")
	_move(at)

func _move(at: Vector2) -> void:
	var v := at - _center()
	var knob_v := v.limit_length(_travel())
	knob.position = base.size * 0.5 - knob.size * 0.5 + knob_v
	if v.length() < _travel() * DEAD_ZONE:
		direction = Vector2.ZERO
		direction_name = ""
		return
	direction = v.normalized()
	var index := wrapi(int(round(v.angle() / (PI / 4))), 0, 8)
	direction_name = DIRECTION_NAMES[index]

## Puts the joystick middle at this point (kept inside the touch zone).
func _place(center: Vector2) -> void:
	var r := base.size * 0.5
	center.x = clampf(center.x, r.x, size.x - r.x)
	center.y = clampf(center.y, r.y, size.y - r.y)
	base.position = center - r

func _stop() -> void:
	direction = Vector2.ZERO
	direction_name = ""
	if _finger == NO_TOUCH:
		return
	_finger = NO_TOUCH
	if not is_inside_tree():
		return
	anim.play("release")
	if _back:
		_back.kill()
	_back = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_back.set_parallel()
	_back.tween_property(knob, "position", base.size * 0.5 - knob.size * 0.5, 0.18)
	_back.tween_property(base, "position", _home, 0.25)
