extends Node

var current_subject: String = ""
var current_level: int = 1

## Settings > Helper hints: helpers show the picture bubble and the guide arrow.
var helper_hints := true
const SETTINGS_PATH := "user://settings.cfg"

## Subjects whose tutorial was hidden with "Don't show again" (this session only,
## NOT saved: it is empty again every time the game is opened).
var tutorials_hidden := {}

# Structure: subject_name -> level_number -> star count (0 = not completed)
var level_progress := {
	"fruits": {},
	"numbers": {},
	"alphabets": {},
	"animals": {},
	"shapes": {},
	"colors": {}
}

func set_level_result(subject: String, level: int, stars: int) -> void:
	level_progress[subject][level] = max(stars, level_progress[subject].get(level, 0))
	PlayerProfile.save_profile()

func get_level_stars(subject: String, level: int) -> int:
	return level_progress[subject].get(level, 0)

func is_level_unlocked(subject: String, level: int) -> bool:
	if level == 1:
		return true
	return level_progress[subject].get(level - 1, 0) > 0

func set_current_level(subject: String, level: int) -> void:
	current_subject = subject
	current_level = level

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		helper_hints = cfg.get_value("game", "helper_hints", true)

func set_helper_hints(on: bool) -> void:
	helper_hints = on
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("game", "helper_hints", on)
	cfg.save(SETTINGS_PATH)

## Settings > Reset stars: every level back to 0 stars (the profile name stays).
func reset_progress() -> void:
	for subject in level_progress.keys():
		level_progress[subject] = {}
	PlayerProfile.save_profile()
