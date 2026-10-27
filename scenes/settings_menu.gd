extends Control

## Main Menu > Settings.
##  - Music and Sounds volume (tap the icon to mute, - / + to change, 5 steps)
##  - Helper hints On / Off
##  - Reset all stars (for grown-ups):
##       1. hold the button for 3 seconds (the ring fills up)
##       2. type RESET in the box, then press Erase
## Everything is saved on this device.

const MAIN_MENU := "res://scenes/main_menu.tscn"
const STEPS := 5
const RESET_HOLD_TIME := 3.0
const RING_FRAMES := 37
const RESET_WORD := "RESET"

@export var pip_on: Texture2D
@export var pip_off: Texture2D
@export var music_icon: Texture2D
@export var music_off_icon: Texture2D
@export var sound_icon: Texture2D
@export var sound_off_icon: Texture2D
@export var check_icon: Texture2D
@export var x_icon: Texture2D

@onready var back_button: Button = $BackButton
@onready var box: VBoxContainer = $Card/MarginContainer/VBoxContainer
@onready var music_mute: Button = box.get_node("MusicRow/Mute")
@onready var music_minus: Button = box.get_node("MusicRow/Minus")
@onready var music_plus: Button = box.get_node("MusicRow/Plus")
@onready var music_pips: HBoxContainer = box.get_node("MusicRow/Pips")
@onready var sound_mute: Button = box.get_node("SoundRow/Mute")
@onready var sound_minus: Button = box.get_node("SoundRow/Minus")
@onready var sound_plus: Button = box.get_node("SoundRow/Plus")
@onready var sound_pips: HBoxContainer = box.get_node("SoundRow/Pips")
@onready var hints_button: Button = box.get_node("HintsRow/Toggle")
@onready var reset_button: Button = box.get_node("ResetRow/ResetButton")
@onready var reset_ring: TextureRect = box.get_node("ResetRow/Ring")
@onready var reset_window: Control = $ResetWindow
@onready var reset_text: Label = $ResetWindow/Box/MarginContainer/VBoxContainer/Text
@onready var reset_input: LineEdit = $ResetWindow/Box/MarginContainer/VBoxContainer/Input
@onready var erase_button: Button = $ResetWindow/Box/MarginContainer/VBoxContainer/Buttons/Erase
@onready var cancel_button: Button = $ResetWindow/Box/MarginContainer/VBoxContainer/Buttons/Cancel
@onready var anim: AnimationPlayer = $AnimationPlayer

var ring_atlas: AtlasTexture
var reset_holding := false
var reset_time := 0.0

func _ready() -> void:
	ring_atlas = (reset_ring.texture as AtlasTexture).duplicate()
	reset_ring.texture = ring_atlas
	back_button.pressed.connect(func(): get_tree().change_scene_to_file(MAIN_MENU))
	music_mute.pressed.connect(_on_mute.bind("music"))
	sound_mute.pressed.connect(_on_mute.bind("sfx"))
	music_minus.pressed.connect(_on_step.bind("music", -1))
	music_plus.pressed.connect(_on_step.bind("music", 1))
	sound_minus.pressed.connect(_on_step.bind("sfx", -1))
	sound_plus.pressed.connect(_on_step.bind("sfx", 1))
	hints_button.pressed.connect(_on_hints_pressed)
	reset_button.button_down.connect(_on_reset_down)
	reset_button.button_up.connect(_cancel_hold)
	reset_input.text_changed.connect(_on_reset_text_changed)
	reset_input.text_submitted.connect(func(_t): _on_erase_pressed())
	erase_button.pressed.connect(_on_erase_pressed)
	cancel_button.pressed.connect(_close_reset_window)
	reset_window.visible = false
	_refresh()
	anim.play("open")

# ---------- volume (saved by AudioManager) ----------

func _step_of(which: String) -> int:
	var v: float = AudioManager.music_volume if which == "music" else AudioManager.sfx_volume
	var on: bool = AudioManager.music_on if which == "music" else AudioManager.sfx_on
	return 0 if not on else int(round(v * STEPS))

func _on_step(which: String, delta: int) -> void:
	_set_step(which, clamp(_step_of(which) + delta, 0, STEPS))
	if which == "sfx":
		AudioManager.play_sfx("pop")   # hear how loud it is

func _on_mute(which: String) -> void:
	if _step_of(which) > 0:
		_set_step(which, 0)
	else:
		var v: float = AudioManager.music_volume if which == "music" else AudioManager.sfx_volume
		_set_step(which, max(1, int(round(v * STEPS))))

func _set_step(which: String, step: int) -> void:
	if which == "music":
		if step > 0:
			AudioManager.set_music_volume(float(step) / STEPS)
		AudioManager.set_music_on(step > 0)
	else:
		if step > 0:
			AudioManager.set_sfx_volume(float(step) / STEPS)
		AudioManager.set_sfx_on(step > 0)
	_refresh()

# ---------- helper hints ----------

func _on_hints_pressed() -> void:
	GameManager.set_helper_hints(not GameManager.helper_hints)
	_refresh()

# ---------- reset all stars: hold 3 s, then type RESET ----------

func _on_reset_down() -> void:
	reset_holding = true
	reset_time = 0.0

func _cancel_hold() -> void:
	reset_holding = false
	reset_time = 0.0
	ring_atlas.region.position.x = 0

func _process(delta: float) -> void:
	if not reset_holding:
		return
	reset_time += delta
	var frame := int(clamp(reset_time / RESET_HOLD_TIME, 0.0, 1.0) * (RING_FRAMES - 1))
	ring_atlas.region.position.x = frame * 16
	if reset_time >= RESET_HOLD_TIME:
		_cancel_hold()
		_open_reset_window()

func _open_reset_window() -> void:
	reset_text.text = "This erases ALL stars in every subject.\nType %s to be sure:" % RESET_WORD
	reset_input.text = ""
	erase_button.disabled = true
	reset_window.visible = true
	anim.play("reset_window")
	reset_input.grab_focus()

func _on_reset_text_changed(new_text: String) -> void:
	# always show capital letters, so kids/grown-ups can match the word easily
	var caret := reset_input.caret_column
	reset_input.text = new_text.to_upper()
	reset_input.caret_column = caret
	erase_button.disabled = reset_input.text != RESET_WORD

func _on_erase_pressed() -> void:
	if reset_input.text != RESET_WORD:
		AudioManager.play_sfx("wrong")
		return
	GameManager.reset_progress()
	AudioManager.play_sfx("pop")
	reset_text.text = "All stars are erased."
	erase_button.disabled = true
	reset_input.editable = false
	await get_tree().create_timer(1.2).timeout
	_close_reset_window()

func _close_reset_window() -> void:
	reset_input.editable = true
	reset_input.release_focus()
	reset_window.visible = false

# ---------- show the current values ----------

func _refresh() -> void:
	_fill_pips(music_pips, _step_of("music"))
	_fill_pips(sound_pips, _step_of("sfx"))
	music_mute.icon = music_icon if _step_of("music") > 0 else music_off_icon
	sound_mute.icon = sound_icon if _step_of("sfx") > 0 else sound_off_icon
	hints_button.icon = check_icon if GameManager.helper_hints else x_icon
	hints_button.text = "On" if GameManager.helper_hints else "Off"

func _fill_pips(row: HBoxContainer, step: int) -> void:
	for i in row.get_child_count():
		var pip := row.get_child(i) as TextureRect
		pip.texture = pip_on if i < step else pip_off
		pip.modulate = Color(0.75, 1.0, 0.5) if i < step else Color(1, 1, 1, 0.45)   # green = on
