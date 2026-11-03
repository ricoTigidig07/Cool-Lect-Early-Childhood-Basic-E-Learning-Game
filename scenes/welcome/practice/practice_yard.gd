extends Node2D

## Practice yard for a new player, after Banban's tutorial (NewPlayer.tscn).
## Banban coaches the player through the real controls, one at a time:
##   1. walk to the shining star with the joystick
##   2. talk to Momo with the hand button
##   3. press and HOLD the hand button to pick up the apple
##   4. tap the apple in the item bar, then give it to Momo
## Then the main menu opens. Nothing is saved (no stars).
## A pointing paw shows what to touch (joystick, hand button, the apple in the item bar)
## and goes away once the player uses it; in the yard it points at Momo or the apple.
## Lines are in English here; Lang.line() shows them in Tagalog / Bisaya.

const MAIN_MENU := "res://scenes/main_menu.tscn"
const APPLE_ICON := preload("res://scenes/objects/icons/apple.tres")
const YARD := Rect2(0, 0, 432, 240)     # the meadow picture: the camera stays inside it
const GOAL_REACH := 14.0
const TAP_GUARD_MS := 300
const YES_GET := "Yes, I'll get it!"
const NOT_NOW := "Not now."

@onready var player: Player01 = $Player
@onready var momo = $Momo
@onready var banban: Node2D = $Banban
@onready var goal: Node2D = $Goal
@onready var apple: Area2D = $Apple
@onready var anim: AnimationPlayer = $YardAnim
@onready var pointer: Node2D = $Coach/Pointer
@onready var pointer_anim: AnimationPlayer = $Coach/Pointer/PawAnim
@onready var world_pointer: Node2D = $WorldPointer
@onready var joystick = $GameUI/JoystickControl
@onready var hand_button: Control = $GameUI/InteractionButton/Button

## What the paw helps with now: "", "joystick", "talk", "pick", "select", "give"
var coach := ""
var _walked := false          # the joystick (or keys) moved the player
var _pressed_at := -100.0     # last time the hand button was pressed (s)
const PRESS_HIDE := 4.0       # after a press the paw waits this long before showing again

var _tapped := false
var _tap_ok_at := 0


func _ready() -> void:
	GameManager.current_subject = ""       # not a subject level: no level tutorial, no stars
	QuestManager.reset()
	var cam: Camera2D = player.camera
	cam.limit_left = int(YARD.position.x)
	cam.limit_top = int(YARD.position.y)
	cam.limit_right = int(YARD.end.x)
	cam.limit_bottom = int(YARD.end.y)
	goal.visible = false
	apple.visible = false
	apple.set_deferred("monitoring", false)
	apple.collected.connect(func(_n, _t): _apple_picked = true)
	GameUIManager.dialogue_panel.gui_input.connect(_on_tap)
	hand_button.button_down.connect(func(): _pressed_at = _now())
	if GameUIManager.hotbar:
		GameUIManager.hotbar.item_icons["apple"] = APPLE_ICON
	GameUIManager.set_missions(Lang.line("Walk to the star"), Lang.line("Talk to Momo"), Lang.line("Give Momo the apple"))
	await get_tree().create_timer(0.8).timeout
	_run()


var _apple_picked := false

## The banner at the start (scenes/ui/ui_extras.gd).
func banner_text() -> Array:
	return [Lang.line("Practice"), Lang.line("Let's try it!")]

func _run() -> void:
	await _say(banban, ["Welcome to the practice yard!", "Let's try everything we learned."])
	# 1. the joystick
	goal.visible = true
	anim.play("goal_shine")
	await _say(banban, ["Use the joystick to walk to the shining star!"])
	coach = "joystick"
	while player.global_position.distance_to(goal.global_position) > GOAL_REACH:
		await get_tree().physics_frame
	coach = ""
	anim.play("goal_got")
	AudioManager.play_sfx("collect")
	GameUIManager.complete_mission_1()
	await anim.animation_finished
	# 2. the hand button: talk
	await _say(banban, ["Great walking!", "Now walk to Momo and tap the hand button to talk to him."])
	while true:
		coach = "talk"
		await momo.talked
		coach = ""
		var answer := await _say(momo, ["Hi! I'm Momo, the fruit merchant.", "Can you bring me that apple, please?"], [YES_GET, NOT_NOW])
		if answer == YES_GET:
			break
		await _say(momo, ["Okay! Talk to me again when you're ready."])
	GameUIManager.complete_mission_2()
	# 3. hold the hand button: pick up
	apple.visible = true
	apple.monitoring = true
	anim.play("apple_pop")
	await _say(banban, ["Walk to the apple. Then press and hold the hand button to pick it up."])
	coach = "pick"
	while not _apple_picked:
		await get_tree().process_frame
	coach = ""
	await get_tree().create_timer(0.4).timeout
	await _say(banban, ["You got the apple! It's in your item bar now.",
		"Tap the apple in your item bar to hold it.",
		"Then walk to Momo and tap the hand button to give it to him."])
	# 4. give it
	while true:
		coach = "select"
		await momo.talked
		coach = ""
		if GameUIManager.get_equipped_item() == "apple":
			break
		await _say(momo, ["Please hold the apple first! Tap it in your item bar."])
	GameUIManager.consume_hotbar_item("apple")
	AudioManager.play_sfx("collect")
	anim.play("momo_happy")
	await _say(momo, ["Yay! Thank you for the apple!", "Thank you, great helper!"])
	GameUIManager.complete_mission_3()
	await _say(banban, ["You did it! Now you know how to play.", "Let's start our adventure!"])
	get_tree().change_scene_to_file(MAIN_MENU)


## Someone talks (Banban or Momo). With answers: shows the buttons and returns the
## English answer; without: waits for a tap on the box. The player waits meanwhile.
func _say(who: Node, lines: Array[String], answers: Array[String] = []) -> String:
	player.controls_locked = true
	GameUIManager.level_over = true          # the hand button does nothing while talking
	GameUIManager.talk_speaker = who
	GameUIManager.show_dialogue(lines)
	await GameUIManager.dialogue_panel.finished
	var picked := ""
	if answers.is_empty():
		GameUIManager.dialogue_panel.continue_icon.visible = true
		_tapped = false
		_tap_ok_at = Time.get_ticks_msec() + TAP_GUARD_MS
		while not _tapped:
			await get_tree().process_frame
	else:
		GameUIManager.show_choices(answers)
		picked = await GameUIManager.dialogue_panel.choice_selected
	GameUIManager.hide_dialogue()
	GameUIManager.talk_speaker = null
	GameUIManager.level_over = false
	player.controls_locked = false
	return picked


# ---------- the pointing paw ----------

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _process(_delta: float) -> void:
	if player.velocity.length() > 5.0 and not player.controls_locked:
		_walked = true
	var ui_target: Control = null
	var world_target: Node2D = null
	var hold := false
	var talking: bool = GameUIManager.dialogue_panel.visible
	if not talking:
		match coach:
			"joystick":
				if not _walked:
					ui_target = joystick.get_node("Base")
			"talk", "give":
				if not momo.player_near():
					world_target = momo
				elif _now() - _pressed_at > PRESS_HIDE:
					ui_target = hand_button
			"pick":
				if apple.player_ref == null:
					world_target = apple
				elif _now() - _pressed_at > PRESS_HIDE:
					ui_target = hand_button
					hold = true
			"select":
				var bar = GameUIManager.hotbar
				if GameUIManager.get_equipped_item() == "apple":
					coach = "give"
				elif bar and bar.slot_by_item.has("apple"):
					ui_target = bar.slot_by_item["apple"]
	_point_ui(ui_target, hold)
	_point_world(world_target)

## The paw's fingertip touches the middle of this button (from below; from the left
## side for buttons on the right half of the screen, so it stays on screen).
func _point_ui(target: Control, hold: bool) -> void:
	if target == null or not target.is_visible_in_tree():
		pointer.visible = false
		return
	var r := target.get_global_rect()
	var right_side := r.get_center().x > get_viewport().get_visible_rect().size.x * 0.5
	pointer.scale = Vector2(-1, 1) if right_side else Vector2.ONE     # mirrored on the right
	pointer.position = r.get_center() + Vector2(-8 if right_side else 8, 10)
	var want := "hold" if hold else "tap"
	if not pointer.visible or pointer_anim.current_animation != want:
		pointer_anim.play(want)
	pointer.visible = true

func _point_world(target: Node2D) -> void:
	if target == null or not target.visible:
		world_pointer.visible = false
		return
	world_pointer.global_position = target.global_position + Vector2(4, -26)
	world_pointer.visible = true


func _on_tap(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if tap and Time.get_ticks_msec() >= _tap_ok_at:
		_tapped = true
