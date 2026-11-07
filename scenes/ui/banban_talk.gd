extends Node

## Banban tells the story of the level and reads the missions (scenes/mission_panel.gd asks).
## The camera zooms in on him, the rest of the game screen hides, and the dialogue box
## shows his lines (tap to go on). Then everything goes back.
## The lines are in scripts/lang/banban_story.gd (English) and dialogue_tl / dialogue_ceb.gd.

const STORY := preload("res://scripts/lang/banban_story.gd")
const ZOOM := 6.5
const ZOOM_TIME := 0.45
## Where Banban stands on the screen while talking (above the dialogue box).
const ON_SCREEN := Vector2(640, 250)
## What stays on the screen while he talks (the rest of the game UI hides).
const KEEP := ["DialoguePanel", "MissionPanel", "BanbanTalk", "TalkMode", "MissionCompletePanel",
		"SettingsPanel", "Selector", "Tutorial"]
const TAP_GUARD_MS := 350

var _hidden: Array[CanvasItem] = []
var _cam_saved := {}
var _tapped := false
var _tap_ok_at := 0


func _ready() -> void:
	add_to_group("banban_talk")


## The pages Banban says for mission i (0, 1, 2) of this level.
func pages_for(i: int, mission_english: String) -> Array[String]:
	var subject: String = GameManager.current_subject
	var level: int = max(GameManager.current_level, 1)
	var out: Array[String] = []
	if STORY.STORY.has(subject):
		var lines: Dictionary = STORY.STORY[subject]
		if i == 0:
			out.append(lines["intro"][min(level, lines["intro"].size()) - 1])
		else:
			var pool: Array = lines["mid"] if i == 1 else lines["end"]
			out.append(pool[(level - 1) % pool.size()])
	var tier: int = clampi((level - 1) / 5, 0, 2)
	out.append(STORY.LEAD[i][tier] + mission_english)
	return out


## Zoom in on Banban, say the lines, wait for a tap, zoom out.
func say(i: int, mission_english: String) -> void:
	var player := get_tree().current_scene.get_node_or_null("Player") if get_tree().current_scene else null
	var panel = GameUIManager.dialogue_panel
	if player == null or panel == null:
		return
	var was_over: bool = GameUIManager.level_over
	GameUIManager.level_over = true          # the hand button does nothing while he talks
	GameUIManager.talking = true
	player.controls_locked = true
	if "last_direction" in player:
		player.last_direction = "down"       # looks at us
	_hide_hud()
	_zoom_in(player)
	await get_tree().create_timer(ZOOM_TIME).timeout
	GameUIManager.talk_speaker = player       # name "Banban", his face and his voice
	GameUIManager._show_words(pages_for(i, mission_english))
	await panel.finished
	panel.continue_icon.visible = true
	_tapped = false
	_tap_ok_at = Time.get_ticks_msec() + TAP_GUARD_MS
	panel.gui_input.connect(_on_tap)
	while not _tapped and is_inside_tree():
		await get_tree().process_frame
	panel.gui_input.disconnect(_on_tap)
	GameUIManager.hide_dialogue()
	GameUIManager.talk_speaker = null
	_zoom_out(player)
	_show_hud()
	await get_tree().create_timer(ZOOM_TIME).timeout
	if is_instance_valid(player):
		player.controls_locked = false
	GameUIManager.talking = false
	GameUIManager.level_over = was_over


func _on_tap(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if tap and Time.get_ticks_msec() >= _tap_ok_at:
		_tapped = true

# ---------- camera ----------

func _zoom_in(player: Node2D) -> void:
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam == null:
		return
	_cam_saved = {"zoom": cam.zoom, "offset": cam.offset, "smooth": cam.position_smoothing_enabled,
		"limits": [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom]}
	cam.limit_left = -10000000
	cam.limit_top = -10000000
	cam.limit_right = 10000000
	cam.limit_bottom = 10000000
	cam.position_smoothing_enabled = false
	var screen_center: Vector2 = get_viewport().get_visible_rect().size / 2.0
	var head := Vector2(0, -8)                # look at his head, not his feet
	var offset: Vector2 = head - (ON_SCREEN - screen_center) / ZOOM
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "zoom", Vector2(ZOOM, ZOOM), ZOOM_TIME)
	tw.tween_property(cam, "offset", offset, ZOOM_TIME)

func _zoom_out(player: Node2D) -> void:
	if not is_instance_valid(player) or _cam_saved.is_empty():
		return
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam == null:
		return
	var saved := _cam_saved
	_cam_saved = {}
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "zoom", saved["zoom"], ZOOM_TIME)
	tw.tween_property(cam, "offset", saved["offset"], ZOOM_TIME)
	tw.chain().tween_callback(func():
		cam.limit_left = saved["limits"][0]
		cam.limit_top = saved["limits"][1]
		cam.limit_right = saved["limits"][2]
		cam.limit_bottom = saved["limits"][3]
		cam.position_smoothing_enabled = saved["smooth"])

# ---------- the rest of the screen ----------

func _hide_hud() -> void:
	_hidden.clear()
	for c in get_parent().get_children():
		if c is CanvasItem and c.visible and not (String(c.name) in KEEP):
			c.visible = false
			_hidden.append(c)

func _show_hud() -> void:
	for c in _hidden:
		if is_instance_valid(c):
			c.visible = true
	_hidden.clear()
