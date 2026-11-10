extends PanelContainer

@onready var star_1 = $MarginContainer/VBoxContainer/Mission1/StarIcon1
@onready var star_2 = $MarginContainer/VBoxContainer/Mission2/StarIcon2
@onready var star_3 = $MarginContainer/VBoxContainer/Mission3/StarIcon3

@onready var label_1 = $MarginContainer/VBoxContainer/Mission1/Label
@onready var label_2 = $MarginContainer/VBoxContainer/Mission2/Label
@onready var label_3 = $MarginContainer/VBoxContainer/Mission3/Label

const BLANK_STAR = preload("res://resources/blank_star.tres")
const FILLED_STAR = preload("res://resources/filled_star.tres")

const COLOR_ACTIVE := Color(0.36, 0.22, 0.15, 1.0)     # dark brown, what to do now
const COLOR_LOCKED := Color(0.36, 0.22, 0.15, 0.4)     # faded brown, comes later
const COLOR_DONE := Color(0.27, 0.5, 0.2, 1.0)         # green, finished

var labels: Array
var stars: Array
var current_mission := 1
var completed_missions: Array[bool] = [false, false, false]
## The missions in English (the labels show them in the chosen language).
var english := ["", "", ""]

## Banban tells each mission when it becomes the one to do (the first right after the
## level banner, the next one when the last is done): scenes/ui/banban_talk.gd.
const NEXT_DELAY := 1.2          # seconds after a mission is done before he reads the next
var _announcing := false
var _said: Array[bool] = [false, false, false]

func _ready() -> void:
	labels = [label_1, label_2, label_3]
	stars = [star_1, star_2, star_3]
	for star in stars:
		star.texture = BLANK_STAR
	_refresh_styles()
	Lang.changed.connect(_apply_language)

func set_missions(text_1: String, text_2: String, text_3: String) -> void:
	english = [text_1, text_2, text_3]
	_apply_language()

## The labels in the chosen language (also when it is changed in the Settings).
func _apply_language() -> void:
	$MarginContainer/VBoxContainer/Header.text = Lang.line("MISSIONS")
	for i in labels.size():
		labels[i].text = Lang.line(english[i])

func complete_mission_1() -> void:
	_complete_mission(0, star_1)

func complete_mission_2() -> void:
	_complete_mission(1, star_2)

func complete_mission_3() -> void:
	_complete_mission(2, star_3)

func _complete_mission(index: int, star: TextureRect) -> void:
	if completed_missions[index]:
		return            # already done (e.g. talking to the NPC again): no second star pop
	AudioManager.play_sfx("mission")
	star.texture = FILLED_STAR
	completed_missions[index] = true
	current_mission = index + 2
	_refresh_styles()
	_pop(star)
	if index < 2:
		await get_tree().create_timer(NEXT_DELAY).timeout
		announce_current()

# ---------- Banban reads the missions ----------

## Called by the level banner when it has finished showing (scenes/ui/ui_extras.gd).
func start_announcing() -> void:
	_announcing = GameManager.current_subject != ""     # not in the practice yard (it has its own talk)
	announce_current()

## Banban says the mission to do now (once each).
func announce_current() -> void:
	var i := current_mission - 1
	if not _announcing or i < 0 or i > 2 or _said[i] or completed_missions[i]:
		return
	_said[i] = true
	# wait while someone is talking, the menu is open or the level is ending
	while _busy():
		await get_tree().create_timer(0.3).timeout
	if completed_missions[i] or not is_inside_tree():
		return
	var row: Control = labels[i].get_parent()
	row.pivot_offset = row.size * 0.5
	var t := create_tween()
	t.tween_property(row, "scale", Vector2.ONE * 1.08, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(row, "scale", Vector2.ONE, 0.2)
	var talk := get_tree().get_first_node_in_group("banban_talk")
	if talk:
		await talk.say(i, english[i])

func _busy() -> bool:
	var panel = GameUIManager.dialogue_panel
	var tm = GameUIManager.talk_mode
	return get_tree().paused or GameUIManager.level_over or GameUIManager.talking \
		or (panel != null and is_instance_valid(panel) and panel.visible) \
		or (tm != null and is_instance_valid(tm) and tm.has_method("is_busy") and tm.is_busy())

func _pop(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	node.scale = Vector2(0.4, 0.4)
	var t := create_tween()
	t.tween_property(node, "scale", Vector2(1.5, 1.5), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE, 0.15)

func _refresh_styles() -> void:
	for i in range(labels.size()):
		var label: Label = labels[i]
		var star: TextureRect = stars[i]
		if completed_missions[i]:
			label.add_theme_color_override("font_color", COLOR_DONE)
			star.modulate = Color.WHITE
		elif i + 1 == current_mission:
			label.add_theme_color_override("font_color", COLOR_ACTIVE)
			star.modulate = Color.WHITE
		else:
			label.add_theme_color_override("font_color", COLOR_LOCKED)
			star.modulate = Color(1, 1, 1, 0.45)

## The mission NPC's symbol (the same picture as on the sign above their head),
## shown after "Talk to ..." (mission 1) and "Go back to ..." (mission 3).
func set_npc_symbol(tex: Texture2D) -> void:
	for label in [label_1, label_3]:
		var spot: TextureRect = label.get_parent().get_node_or_null("NpcSymbol")
		if spot:
			spot.texture = tex
			spot.visible = tex != null

## How many of the 3 missions are complete (0-3). Used to award stars
## on the Mission Complete screen.
func get_completed_count() -> int:
	var count := 0
	for is_done in completed_missions:
		if is_done:
			count += 1
	return count
