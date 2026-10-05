extends Control

## Profile screen: the player's name and age, their achievements
## (levels finished and stars per subject), and an Edit Profile window.
## Every subject row in Achievements/Rows is named after its subject (Fruits, Numbers, ...).

const MAIN_MENU := "res://scenes/main_menu.tscn"
const LEVELS_PER_SUBJECT := 15
const MIN_AGE := 4

@onready var username_label: Label = $InfoCard/Username
@onready var age_label: Label = $InfoCard/AgeLabel
@onready var edit_button: Button = $InfoCard/EditButton
@onready var total_stars_label: Label = $Achievements/Totals/StarsTotal
@onready var total_levels_label: Label = $Achievements/Totals/LevelsTotal
@onready var rows: Container = $Achievements/Rows
@onready var back_button: Button = $BackButton

@onready var edit_window: Control = $EditWindow
@onready var edit_username: Label = $EditWindow/Panel/Username
@onready var shuffle_button: Button = $EditWindow/Panel/ShuffleButton
@onready var edit_age: Label = $EditWindow/Panel/AgePicker/AgeLabel
@onready var minus_button: Button = $EditWindow/Panel/AgePicker/MinusButton
@onready var plus_button: Button = $EditWindow/Panel/AgePicker/PlusButton
@onready var save_button: Button = $EditWindow/Panel/SaveButton
@onready var cancel_button: Button = $EditWindow/Panel/CancelButton
@onready var anim: AnimationPlayer = $AnimationPlayer

var draft_name := ""
var draft_age := MIN_AGE

func _ready() -> void:
	back_button.pressed.connect(func(): get_tree().change_scene_to_file(MAIN_MENU))
	edit_button.pressed.connect(_open_editor)
	shuffle_button.pressed.connect(_shuffle)
	minus_button.pressed.connect(_change_age.bind(-1))
	plus_button.pressed.connect(_change_age.bind(1))
	save_button.pressed.connect(_save)
	cancel_button.pressed.connect(_close_editor)
	edit_window.visible = false
	_refresh()

# ---------- profile + achievements ----------

func _refresh() -> void:
	username_label.text = PlayerProfile.username if PlayerProfile.username != "" else "New Player"
	age_label.text = "%d years old" % max(PlayerProfile.age, MIN_AGE)

	var all_stars := 0
	var all_levels := 0
	for row in rows.get_children():
		var subject := String(row.name).to_lower()
		var levels_done := 0
		var stars := 0
		var progress: Dictionary = GameManager.level_progress.get(subject, {})
		for level in progress.keys():
			var s: int = progress[level]
			if s > 0:
				levels_done += 1
				stars += s
		all_levels += levels_done
		all_stars += stars
		row.get_node("Bar").max_value = LEVELS_PER_SUBJECT
		row.get_node("Bar").value = levels_done
		row.get_node("Levels").text = "%d/%d" % [levels_done, LEVELS_PER_SUBJECT]
		row.get_node("Stars").text = "%d" % stars

	var subjects := rows.get_child_count()
	total_stars_label.text = "%d / %d" % [all_stars, subjects * LEVELS_PER_SUBJECT * 3]
	total_levels_label.text = "%d / %d levels done" % [all_levels, subjects * LEVELS_PER_SUBJECT]

# ---------- edit profile ----------

func _open_editor() -> void:
	draft_name = PlayerProfile.username
	draft_age = max(PlayerProfile.age, MIN_AGE)
	edit_username.text = draft_name
	_update_age()
	edit_window.visible = true
	anim.play("open_editor")

func _close_editor() -> void:
	anim.play("close_editor")

func _shuffle() -> void:
	draft_name = PlayerProfile.make_username()
	edit_username.text = draft_name
	_pop(edit_username)

func _change_age(step: int) -> void:
	draft_age = max(MIN_AGE, draft_age + step)
	_update_age()
	_pop(edit_age)

func _update_age() -> void:
	edit_age.text = str(draft_age)
	minus_button.disabled = draft_age <= MIN_AGE

func _save() -> void:
	PlayerProfile.create_profile(draft_age, draft_name)
	_refresh()
	_pop(username_label)
	_close_editor()

func _pop(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	var t := create_tween()
	t.tween_property(node, "scale", Vector2.ONE * 1.15, 0.08)
	t.tween_property(node, "scale", Vector2.ONE, 0.1)
