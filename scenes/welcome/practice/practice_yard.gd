extends Node2D

## Practice yard for a new player, after Banban's tutorial (NewPlayer.tscn).
## Banban coaches the player through the real controls, one at a time:
##   1. walk to the shining star with the joystick
##   2. talk to Momo with the hand button
##   3. press and HOLD the hand button to pick up the apple
##   4. tap the apple in the item bar, then give it to Momo
## Then the main menu opens. Nothing is saved (no stars).
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
	while player.global_position.distance_to(goal.global_position) > GOAL_REACH:
		await get_tree().physics_frame
	anim.play("goal_got")
	AudioManager.play_sfx("collect")
	GameUIManager.complete_mission_1()
	await anim.animation_finished
	# 2. the hand button: talk
	await _say(banban, ["Great walking!", "Now walk to Momo and tap the hand button to talk to him."])
	while true:
		await momo.talked
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
	while not _apple_picked:
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	await _say(banban, ["You got the apple! It's in your item bar now.",
		"Tap the apple in your item bar to hold it.",
		"Then walk to Momo and tap the hand button to give it to him."])
	# 4. give it
	while true:
		await momo.talked
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


func _on_tap(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if tap and Time.get_ticks_msec() >= _tap_ok_at:
		_tapped = true
