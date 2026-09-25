@tool
extends Node2D

## One island on the level map. Everything you see is a node in level_island.tscn;
## this script only reads the player's progress and switches the right nodes on/off.

signal pressed(level: int)

@export var level := 1:
	set(value):
		level = value
		if is_node_ready():
			$Badge/Number.text = str(level)   # also updates in the editor
@export var locked_normal: Texture2D
@export var locked_hover: Texture2D
@export var locked_pressed: Texture2D
@export var locked_material: Material

const FILLED_STAR := preload("res://resources/filled_star.tres")
const BLANK_STAR := preload("res://resources/blank_star.tres")

@onready var badge: TextureButton = $Badge
@onready var anim: AnimationPlayer = $AnimationPlayer

var unlocked := true

func _ready() -> void:
	$Badge/Number.text = str(level)
	if Engine.is_editor_hint():
		return
	badge.pressed.connect(func(): pressed.emit(level))

## Called by the level map with this subject's progress.
func setup(subject: String, is_current: bool) -> void:
	unlocked = GameManager.is_level_unlocked(subject, level)
	var stars := GameManager.get_level_stars(subject, level)
	$Badge/Number.visible = unlocked
	$Badge/Lock.visible = not unlocked
	$Stars.visible = unlocked
	for i in 3:
		$Stars.get_child(i).texture = FILLED_STAR if i < stars else BLANK_STAR
	if not unlocked:
		badge.texture_normal = locked_normal
		badge.texture_hover = locked_hover
		badge.texture_pressed = locked_pressed
		for n in [$Island, $Bush, $Badge]:
			n.material = locked_material
	$PlayerMarker.visible = is_current
	if is_current:
		anim.play("pulse")

func wiggle() -> void:
	anim.play("wiggle")
