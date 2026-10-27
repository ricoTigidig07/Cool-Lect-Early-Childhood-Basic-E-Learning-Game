extends Control

## The pause / settings panel (gear button in the top-right corner).
##  - Resume
##  - Music and Sounds volume: tap the speaker to mute, - / + to change (5 steps)
##  - Helper hints On / Off (the bubble picture + arrows from helper villagers)
##  - How to Play (opens the tutorial pages again)
##  - Restart level (asks first)
##  - Main Menu
## (Reset all stars is only in the Main Menu > Settings screen.)
## Everything is saved on this device.

const STEPS := 5

@export var pip_on: Texture2D
@export var pip_off: Texture2D
@export var music_icon: Texture2D
@export var music_off_icon: Texture2D
@export var sound_icon: Texture2D
@export var sound_off_icon: Texture2D
@export var check_icon: Texture2D
@export var x_icon: Texture2D

@onready var panel: PanelContainer = $PanelContainer
@onready var box: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer
@onready var resume_button: Button = box.get_node("ResumeButton")
@onready var music_mute: Button = box.get_node("MusicRow/Mute")
@onready var music_minus: Button = box.get_node("MusicRow/Minus")
@onready var music_plus: Button = box.get_node("MusicRow/Plus")
@onready var music_pips: HBoxContainer = box.get_node("MusicRow/Pips")
@onready var sound_mute: Button = box.get_node("SoundRow/Mute")
@onready var sound_minus: Button = box.get_node("SoundRow/Minus")
@onready var sound_plus: Button = box.get_node("SoundRow/Plus")
@onready var sound_pips: HBoxContainer = box.get_node("SoundRow/Pips")
@onready var hints_button: Button = box.get_node("HintsRow/Toggle")
@onready var restart_button: Button = box.get_node("RestartButton")
@onready var howto_button: Button = box.get_node("HowToButton")
@onready var main_menu_button: Button = box.get_node("MainMenuButton")
@onready var confirm: Control = $Confirm
@onready var confirm_text: Label = $Confirm/Box/MarginContainer/VBoxContainer/Text
@onready var confirm_yes: Button = $Confirm/Box/MarginContainer/VBoxContainer/Buttons/Yes
@onready var confirm_no: Button = $Confirm/Box/MarginContainer/VBoxContainer/Buttons/No
@onready var anim: AnimationPlayer = $AnimationPlayer

var pending: Callable

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(_on_resume_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	music_mute.pressed.connect(_on_mute.bind("music"))
	sound_mute.pressed.connect(_on_mute.bind("sfx"))
	music_minus.pressed.connect(_on_step.bind("music", -1))
	music_plus.pressed.connect(_on_step.bind("music", 1))
	sound_minus.pressed.connect(_on_step.bind("sfx", -1))
	sound_plus.pressed.connect(_on_step.bind("sfx", 1))
	hints_button.pressed.connect(_on_hints_pressed)
	howto_button.pressed.connect(_on_howto_pressed)
	restart_button.pressed.connect(_ask.bind("Start this level again?", _restart_level))
	confirm_yes.pressed.connect(_on_confirm.bind(true))
	confirm_no.pressed.connect(_on_confirm.bind(false))
	confirm.visible = false
	visibility_changed.connect(_on_visibility_changed)
	visible = false
	_refresh()

func _on_visibility_changed() -> void:
	if not visible:
		confirm.visible = false
		return
	# Draw above the rest of the HUD and block taps behind the menu.
	get_parent().move_child(self, -1)
	_refresh()
	anim.play("open")

func _on_resume_pressed() -> void:
	visible = false
	get_tree().paused = false

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ---------- volume (saved by AudioManager) ----------

func _step_of(which: String) -> int:
	var v: float = AudioManager.music_volume if which == "music" else AudioManager.sfx_volume
	var on: bool = AudioManager.music_on if which == "music" else AudioManager.sfx_on
	return 0 if not on else int(round(v * STEPS))

func _on_step(which: String, delta: int) -> void:
	var step: int = clamp(_step_of(which) + delta, 0, STEPS)
	_set_step(which, step)
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

# ---------- how to play ----------

func _on_howto_pressed() -> void:
	var tut = get_tree().get_first_node_in_group("tutorial")
	if tut:
		visible = false          # the tutorial opens this menu again when it closes
		tut.open(true)

# ---------- restart ----------

func _restart_level() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

# ---------- yes / no box ----------

func _ask(question: String, on_yes: Callable) -> void:
	pending = on_yes
	confirm_text.text = question
	confirm.visible = true
	anim.play("confirm")

func _on_confirm(yes: bool) -> void:
	confirm.visible = false
	if yes and pending.is_valid():
		pending.call()
	pending = Callable()

# ---------- show the current values ----------

func _refresh() -> void:
	if not is_node_ready():
		return
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
