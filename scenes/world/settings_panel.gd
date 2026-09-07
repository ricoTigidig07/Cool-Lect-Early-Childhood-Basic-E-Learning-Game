extends Control

@onready var resume_button = $PanelContainer/VBoxContainer/ResumeButton
@onready var main_menu_button = $PanelContainer/VBoxContainer/MainMenuButton
@onready var volume_slider = $PanelContainer/VBoxContainer/HBoxContainer/HSlider

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
#	resume_button.pressed.connect(_on_resume_pressed)
#	main_menu_button.pressed.connect(_on_main_menu_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)
	visible = false

func _on_resume_pressed() -> void:
	visible = false
	get_tree().paused = false

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
