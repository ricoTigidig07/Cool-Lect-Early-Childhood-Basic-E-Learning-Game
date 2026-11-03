extends Control

## General tutorial for a new player, right after picking the name.
## Banban (the player's bunny) says hi, asks two Yes / No questions and can show
## how to play: joystick, hand button, item bar and stars. Emits `done` at the end:
## done(true) = go and practice in the practice yard, done(false) = go to the main menu.
## Lines are in English here; Lang.line() shows them in Tagalog / Bisaya
## (scripts/lang/dialogue_tl.gd and dialogue_ceb.gd).

signal done(practice: bool)

const YES_READY := "Yes! Let's go!"
const NOT_YET := "Not yet."
const SHOW_ME := "Yes, show me!"
const NO_THANKS := "No, thanks."
const START := "Start!"
const LETS_GO := "Let's go!"
## How-to-play steps: [demo picture, line]
const STEPS := [
	["joystick", "Use the joystick to walk around."],
	["hand", "Tap the hand button to talk to friends and pick up things."],
	["items", "The things you pick up go to your item bar. Tap one to hold it."],
	["stars", "Finish the missions to earn stars. Can you get all 3 stars?"],
]
const TAP_GUARD_MS := 300

@onready var dialogue: TextureRect = $DialoguePanel
@onready var banban: Node2D = $Stage/Banban
@onready var banban_anim: AnimationPlayer = $BanbanAnim
@onready var demo: Control = $Demo
@onready var demo_anim: AnimationPlayer = $DemoAnim

var _tapped := false
var _tap_ok_at := 0


func _ready() -> void:
	dialogue.visible = false
	demo.visible = false
	dialogue.gui_input.connect(_on_tap)
	gui_input.connect(_on_tap)
	# the demo joystick / hand button are only pictures here
	for c in [$Demo/JoyDemo/Joystick, $Demo/HandDemo/ActionButton]:
		c.set_anchors_preset(Control.PRESET_TOP_LEFT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for n in c.find_children("*", "Control", true, false):
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Demo/JoyDemo/Joystick.position = Vector2(40, 30)
	$Demo/JoyDemo/Joystick.size = Vector2(470, 420)
	$Demo/HandDemo/ActionButton.position = Vector2(400, 40)
	$Demo/HandDemo/ActionButton.size = Vector2(260, 260)
	var hand_button := $Demo/HandDemo/ActionButton/Button
	if hand_button.has_method("set_ready"):
		hand_button.set_ready.call_deferred(true)


func start() -> void:
	visible = true
	GameUIManager.talk_speaker = banban
	banban_anim.play("idle")
	dialogue.visible = true
	await _say("Hi! I am Banban, your personal character!")
	await _say("I will be with you on every adventure.")
	var answer := await _ask("Are you ready to learn and play with me?", [YES_READY, NOT_YET])
	while answer != YES_READY:
		await _say("That's okay! I'll wait for you. Tell me when you're ready!")
		answer = await _ask("Are you ready now?", [YES_READY, NOT_YET])
	_hop()
	await _say("Yay! Let's have fun and learn together!")
	answer = await _ask("Do you want me to show you how to play?", [SHOW_ME, NO_THANKS])
	if answer == SHOW_ME:
		_hop()
		await _say("Great! Let me show you.")
		for step in STEPS:
			_show_demo(step[0])
			await _say(step[1])
		_show_demo("")
		_hop()
		await _ask("Now let's practice together!", [LETS_GO])
		_finish(true)
		return
	await _say("Okay! You can turn on the helper hints in Settings anytime.")
	_hop()
	await _ask("Let's start our adventure!", [START])
	_finish(false)


func _finish(practice: bool) -> void:
	GameUIManager.talk_speaker = null
	dialogue.visible = false
	done.emit(practice)


## One line; waits for a tap after it is typed.
func _say(english: String) -> void:
	var pages: Array[String] = [english]
	dialogue.show_pages(pages)
	await dialogue.finished
	dialogue.continue_icon.visible = true
	_tapped = false
	_tap_ok_at = Time.get_ticks_msec() + TAP_GUARD_MS
	while not _tapped:
		await get_tree().process_frame
	dialogue.continue_icon.visible = false


## A question with answer buttons (1 or 2). Returns the English answer.
func _ask(english: String, answers: Array[String]) -> String:
	var pages: Array[String] = [english]
	dialogue.show_pages(pages)
	await dialogue.finished
	var no_button: Button = dialogue.no_button
	no_button.visible = answers.size() > 1
	dialogue.show_choices(answers)
	var picked: String = await dialogue.choice_selected
	no_button.visible = true
	return picked


func _on_tap(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if tap and Time.get_ticks_msec() >= _tap_ok_at:
		_tapped = true


func _hop() -> void:
	banban_anim.play("hop")
	banban_anim.queue("idle")
	AudioManager.play_sfx("hop")


## Shows one how-to-play picture ("" hides the card).
func _show_demo(which: String) -> void:
	if which == "":
		demo_anim.play("hide_card")
		return
	for c in ["JoyDemo", "HandDemo", "ItemsDemo", "StarsDemo"]:
		demo.get_node(c).visible = false
	demo.get_node({"joystick": "JoyDemo", "hand": "HandDemo", "items": "ItemsDemo", "stars": "StarsDemo"}[which]).visible = true
	demo.visible = true
	demo_anim.play(which)
