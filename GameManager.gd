extends Node

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
	level_progress[subject][level] = stars

func get_level_stars(subject: String, level: int) -> int:
	return level_progress[subject].get(level, 0)

func is_level_unlocked(subject: String, level: int) -> bool:
	if level == 1:
		return true
	return level_progress[subject].get(level - 1, 0) > 0
