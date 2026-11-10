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
## The practice yard was started but not finished (the app closed, or the player went
## back to the menu): the main menu asks if they want to continue it.
var practice_pending := false
## Settings > How to Play: NewPlayer.tscn skips the language, age and name pages and
## goes straight to Banban's first meeting (not saved, only for that one visit).
var replay_tutorial := false

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
	cfg.set_value("player", "practice_pending", practice_pending)
	cfg.set_value("progress", "levels", GameManager.level_progress)
	cfg.save(SAVE_PATH)

func load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	age = cfg.get_value("player", "age", 0)
	username = cfg.get_value("player", "username", "")
	practice_pending = cfg.get_value("player", "practice_pending", false)
	var saved: Dictionary = cfg.get_value("progress", "levels", {})
	for subject in saved.keys():
		GameManager.level_progress[subject] = saved[subject]

## The practice yard started (true) or was finished / skipped (false).
func set_practice_pending(on: bool) -> void:
	practice_pending = on
	save_profile()

## Deletes the profile (for testing, or a "New Player" button).
func reset_profile() -> void:
	age = 0
	username = ""
	practice_pending = false
	for subject in GameManager.level_progress.keys():
		GameManager.level_progress[subject] = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
