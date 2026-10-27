extends Control

## Two little wooden signs hanging together (from the Sprout Lands UI pack),
## next to the avatar at the top-left of every level:
##   top sign    = the player's username
##   bottom sign = all the stars earned so far, e.g. "12 / 270"
## Animations (AnimationPlayer): "intro" swings the signs down when the level starts,
## "bump" pops the star count when new stars are earned.

const LEVELS_PER_SUBJECT := 15
const STARS_PER_LEVEL := 3

@onready var name_label: Label = $Board/Top/Name
@onready var count_label: Label = $Board/Bottom/Row/Count
@onready var anim: AnimationPlayer = $AnimationPlayer

var shown_total := -1

func _ready() -> void:
	name_label.text = PlayerProfile.username if PlayerProfile.username != "" else "Player"
	_refresh(false)
	GameManager.progress_changed.connect(_refresh.bind(true))
	anim.play("intro")

func _refresh(bump: bool) -> void:
	var total := 0
	for subject in GameManager.level_progress:
		for level in GameManager.level_progress[subject]:
			total += int(GameManager.level_progress[subject][level])
	var most := GameManager.level_progress.size() * LEVELS_PER_SUBJECT * STARS_PER_LEVEL
	count_label.text = "%d / %d" % [total, most]
	if bump and total != shown_total:
		anim.play("bump")
	shown_total = total
