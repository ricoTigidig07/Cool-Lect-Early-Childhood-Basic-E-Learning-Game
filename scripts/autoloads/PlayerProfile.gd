extends Node

## The player's profile: age and username, saved on this device.
## (Only an age and a made-up username are stored, never a real name.)

const SAVE_PATH := "user://profile.cfg"

const ADJECTIVES := ["Happy", "Sunny", "Brave", "Bouncy", "Sparkly", "Jolly", "Cozy", "Speedy",
	"Lucky", "Giggly", "Fluffy", "Clever", "Shiny", "Cheery", "Zippy", "Bubbly"]
const ANIMALS := ["Panda", "Bunny", "Kitten", "Puppy", "Duckling", "Koala", "Turtle", "Fox",
	"Owl", "Penguin", "Bear", "Chick", "Piglet", "Lamb", "Froggy", "Hippo"]

var age: int = 0
var username: String = ""

func _ready() -> void:
	load_profile()

func has_profile() -> bool:
	return age > 0 and username != ""

## A fun, safe username like "SunnyPanda27".
func make_username() -> String:
	return "%s%s%d" % [ADJECTIVES.pick_random(), ANIMALS.pick_random(), randi_range(10, 99)]

func create_profile(new_age: int, new_username: String) -> void:
	age = new_age
	username = new_username
	save_profile()

func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "age", age)
	cfg.set_value("player", "username", username)
	cfg.set_value("progress", "levels", GameManager.level_progress)
	cfg.save(SAVE_PATH)

func load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	age = cfg.get_value("player", "age", 0)
	username = cfg.get_value("player", "username", "")
	var saved: Dictionary = cfg.get_value("progress", "levels", {})
	for subject in saved.keys():
		GameManager.level_progress[subject] = saved[subject]

## Deletes the profile (for testing, or a "New Player" button).
func reset_profile() -> void:
	age = 0
	username = ""
	for subject in GameManager.level_progress.keys():
		GameManager.level_progress[subject] = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
