extends Control

@onready var panel: PanelContainer = $PanelContainer
@onready var resume_button = $PanelContainer/MarginContainer/VBoxContainer/ResumeButton
@onready var main_menu_button = $PanelContainer/MarginContainer/VBoxContainer/MainMenuButton
@onready var music_button: Button = $PanelContainer/MarginContainer/VBoxContainer/MusicButton
@onready var sound_button: Button = $PanelContainer/MarginContainer/VBoxContainer/SoundButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(_on_resume_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	music_button.pressed.connect(_on_music_pressed)
	sound_button.pressed.connect(_on_sound_pressed)
	_refresh_audio_buttons()
	visibility_changed.connect(_on_visibility_changed)
	visible = false

func _on_visibility_changed() -> void:
	if not visible:
		return
	# Draw above the rest of the HUD and block taps behind the menu.
	get_parent().move_child(self, -1)
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(panel, "modulate:a", 1.0, 0.1)

func _on_resume_pressed() -> void:
	visible = false
	get_tree().paused = false

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ---------- music / sound on-off (saved by AudioManager) ----------

func _on_music_pressed() -> void:
	AudioManager.set_music_on(not AudioManager.music_on)
	_refresh_audio_buttons()

func _on_sound_pressed() -> void:
	AudioManager.set_sfx_on(not AudioManager.sfx_on)
	_refresh_audio_buttons()

func _refresh_audio_buttons() -> void:
	music_button.text = "Music: ON" if AudioManager.music_on else "Music: OFF"
	sound_button.text = "Sounds: ON" if AudioManager.sfx_on else "Sounds: OFF"
