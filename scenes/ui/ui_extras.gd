extends Control

## Extra in-game UI, all made from the Sprout Lands UI pack:
##  - Level banner: "Fruits - Level 3 / Orange" slides down when the level starts.
##  - Task progress (top middle): the item picture, "3 / 5" and a progress ring
##    that fills from purple to green with a check mark when done.
##  - Avatar reactions: the cat in the top-left corner shows hearts when you collect,
##    cheers when a mission is done, looks worried on a wrong item and gets sleepy
##    when you stand still.
##  - "Lost?" bubble: after standing still for a while, a bubble next to the avatar
##    reminds you to ask a helper.
##  - Interact badge: a little icon on the big hand button shows what it will do
##    (talk, make friends, use) and the button lights up when something is near.
##  - Paw mouse cursor on computers.
## Nothing here changes how the levels or the Mission Complete panel work.

const RING_FRAMES := 37            # frames in "Stamina circle" sheet (16 px each)
const IDLE_TIME := 15.0            # seconds standing still before the "Lost?" bubble
const SUBJECT_NAMES := {
	"fruits": "Fruits", "animals": "Animals", "alphabets": "Alphabets",
	"numbers": "Numbers", "shapes": "Shapes", "colors": "Colors",
}

@export var badge_talk: Texture2D
@export var badge_paw: Texture2D
@export var badge_use: Texture2D
@export var cursor_texture: Texture2D

@onready var banner_title: Label = $TopCenter/LevelBanner/Title
@onready var banner_name: Label = $TopCenter/LevelBanner/LevelName
@onready var banner_anim: AnimationPlayer = $BannerAnim
@onready var progress_box: Control = $TopCenter/TaskProgress
@onready var progress_icon: TextureRect = $TopCenter/TaskProgress/ItemIcon
@onready var progress_count: Label = $TopCenter/TaskProgress/Count
@onready var progress_ring: TextureRect = $TopCenter/TaskProgress/Ring
@onready var progress_anim: AnimationPlayer = $ProgressAnim
@onready var idle_bubble: Control = $IdleBubble
@onready var idle_text: Label = $IdleBubble/Text
@onready var bubble_anim: AnimationPlayer = $BubbleAnim
@onready var badge: Control = $BottomRight/InteractBadge
@onready var badge_icon: TextureRect = $BottomRight/InteractBadge/Icon
@onready var badge_anim: AnimationPlayer = $BadgeAnim

var ring_atlas: AtlasTexture
var last_done := -1
var task_finished := false
var idle_time := 0.0
var last_player_pos := Vector2.INF
var bubble_shown := false
var sleepy := false
var reacting := false
var badge_target: Object = null
var poll := 0.0
## The level's work station (letter board, shape board or easel), found once.
## Looking through every node of the level 5 times a second made phones stutter.
var station: Node = null
var station_searched := false
var quest_icon: Texture2D = null

func _ready() -> void:
	# own copy, so changing the ring frame never touches the scene file
	ring_atlas = (progress_ring.texture as AtlasTexture).duplicate()
	progress_ring.texture = ring_atlas
	progress_box.visible = false
	idle_bubble.visible = false
	badge.visible = false
	AudioManager.sfx_played.connect(_on_sfx)
	_set_cursor()
	await get_tree().process_frame
	_show_banner()

# ---------- level banner ----------

func _show_banner() -> void:
	var subject: String = GameManager.current_subject
	var level: int = GameManager.current_level
	var scene := _level()
	var file := scene.scene_file_path.get_file().get_basename() if scene else ""
	# "Lvl3OrangeMap" -> "Orange", "Lvl15BigEggHuntMap" -> "Big Egg Hunt"
	var re := RegEx.new()
	re.compile("^Lvl(\\d+)(.*)Map$")
	var m := re.search(file)
	var pretty := ""
	if m:
		level = int(m.get_string(1))
		pretty = m.get_string(2).capitalize()
	if scene:
		for s in SUBJECT_NAMES:
			if scene.scene_file_path.contains("/%s/" % s):
				subject = s
	if SUBJECT_NAMES.has(subject):
		banner_title.text = "%s - Level %d" % [SUBJECT_NAMES[subject], level]
	else:
		banner_title.text = "Level %d" % level
	banner_name.text = pretty if pretty != "" else "Let's play!"
	banner_anim.play("show")
	AudioManager.play_sfx("pop")

# ---------- every frame ----------

func _process(delta: float) -> void:
	poll -= delta
	if poll <= 0.0:
		poll = 0.2
		_update_progress()
		_update_badge()
	_update_idle(delta)

# ---------- task progress ----------

func _update_progress() -> void:
	if not _mission_started():
		return
	var p := _progress()
	if p.is_empty():
		return
	var done: int = p["done"]
	var total: int = max(1, p["total"])
	if not progress_box.visible:
		progress_box.visible = true
		progress_anim.play("appear")
	if p["icon"]:
		progress_icon.texture = p["icon"]
		progress_icon.modulate = p.get("tint", Color.WHITE)
	if done != last_done:
		if last_done >= 0 and done > last_done:
			progress_anim.play("bump")
		last_done = done
	var finished := done >= total
	progress_count.text = "Done!" if finished else "%d / %d" % [done, total]
	var frame := int(round(float(done) / total * (RING_FRAMES - 1)))
	ring_atlas.region.position.x = clamp(frame, 0, RING_FRAMES - 1) * 16
	if finished and not task_finished:
		task_finished = true
		progress_anim.play("bump")

func _mission_started() -> bool:
	if QuestManager.active or QuestManager.target_counts.size() > 0:
		return true    # fruits / animals: the quest list started
	var mp = GameUIManager.mission_panel
	return mp != null and "completed_missions" in mp and mp.completed_missions[0]

## The level this UI belongs to (GameUI is a child of the level).
func _level() -> Node:
	var ui := get_parent()
	return ui.get_parent() if ui and ui.get_parent() else get_tree().current_scene

func _level_nodes() -> Array:
	var out: Array = []
	var level := _level()
	if level:
		_collect(level, out)
	return out

func _collect(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_collect(c, out)

func _script_name(n: Node) -> String:
	var s = n.get_script()
	return s.resource_path.get_file() if s else ""

func _find_station() -> void:
	station_searched = true
	for n in _level_nodes():
		if _script_name(n) in ["letter_frame.gd", "shape_board.gd", "easel.gd"]:
			station = n
			return

## {done, total, icon, tint} for whatever this level asks for.
func _progress() -> Dictionary:
	if not station_searched:
		_find_station()
	if station and is_instance_valid(station):
		var n = station
		match _script_name(n):
			"letter_frame.gd":
				var seq = n.get_node_or_null(n.letter_sequence)
				if seq:
					var letter: String = seq.current_letter()
					return {"done": seq.current_index, "total": seq.letter_order.size(),
						"icon": GameUIManager.get_item_icon(letter) if letter != "" else null}
			"shape_board.gd":
				var filled := 0
				var holes: Array = n.holes.get_children()
				var icon: Texture2D = null
				var tint := Color.WHITE
				for h in holes:
					if h.get_meta("filled"):
						filled += 1
					elif icon == null:
						icon = h.texture
						tint = h.get_meta("color", Color.WHITE)
				if icon == null and holes.size() > 0:
					icon = holes[0].texture
				return {"done": filled, "total": holes.size(), "icon": icon, "tint": tint}
			"easel.gd":
				var parts: Array = n.parts()
				var painted := 0
				for part in parts:
					if part.get_meta("painted"):
						painted += 1
				var next: String = n.next_needed_color()
				if next == "" and not n.needed_colors().is_empty():
					next = n.needed_colors()[0]
				return {"done": painted, "total": parts.size(), "icon": PaintColors.bucket_icon(next) if next != "" else null}
	# baskets (numbers)
	var baskets := get_tree().get_nodes_in_group("count_baskets")
	if baskets.size() > 0:
		var cur := 0
		var tot := 0
		for b in baskets:
			cur += b.current_count
			tot += b.target_count
		return {"done": cur, "total": tot, "icon": GameUIManager.get_item_icon("egg")}
	# fruits / animals: the quest list
	if QuestManager.target_counts.size() > 0:
		var cur2 := 0
		var tot2 := 0
		for k in QuestManager.target_counts:
			tot2 += QuestManager.target_counts[k]
			cur2 += QuestManager.current_counts.get(k, 0)
		if quest_icon == null:
			quest_icon = _quest_icon(_level_nodes())
		return {"done": cur2, "total": tot2, "icon": quest_icon}
	return {}

func _quest_icon(nodes: Array) -> Texture2D:
	for n in nodes:
		if n is Chicken and n.icon:
			return n.icon
		if n is CollectableComponent and n.item_type == "fruits":
			var s = n.get_node_or_null("Sprite2D")
			if s:
				return s.texture
	return null

# ---------- avatar reactions ----------

func _avatar() -> AnimatedSprite2D:
	return get_tree().get_first_node_in_group("avatar_icon") as AnimatedSprite2D

func _on_sfx(sfx_name: String) -> void:
	match sfx_name:
		"collect", "place", "paint":
			_react("Love", 1.2)
		"mission", "star":
			_react("Cheer", 1.6)
		"wrong":
			_react("Oops", 1.0)

func _react(anim: String, time: float) -> void:
	var a := _avatar()
	if a == null or not a.sprite_frames.has_animation(anim) or a.is_near_merchant:
		return
	reacting = true
	sleepy = false
	a.play(anim)
	await get_tree().create_timer(time).timeout
	reacting = false
	a = _avatar()
	if a and not a.is_near_merchant and a.animation == anim:
		a.play("defaults")

# ---------- standing still: sleepy cat + "Lost?" bubble ----------

func _player() -> Node2D:
	var level := _level()
	return level.get_node_or_null("Player") as Node2D if level else null

func _update_idle(delta: float) -> void:
	var p := _player()
	if p == null:
		return
	var moved := p.global_position.distance_to(last_player_pos) > 0.5
	last_player_pos = p.global_position
	var busy: bool = GameUIManager.dialogue_panel != null and GameUIManager.dialogue_panel.visible
	if moved or busy or not _mission_started() or task_finished:
		idle_time = 0.0
		if bubble_shown:
			bubble_shown = false
			bubble_anim.play("hide")
		if sleepy:
			sleepy = false
			var a := _avatar()
			if a and not a.is_near_merchant and not reacting:
				a.play("defaults")
		return
	idle_time += delta
	if idle_time >= IDLE_TIME and not bubble_shown:
		bubble_shown = true
		idle_text.text = "Look around!"
		bubble_anim.play("show")
		var a := _avatar()
		if a and not a.is_near_merchant and not reacting:
			sleepy = true
			a.play("Sleepy")

func _has_helpers() -> bool:
	for n in _level().get_children():
		if n.name.begins_with("Helper"):
			return true
	return false

# ---------- interact button badge ----------

func _update_badge() -> void:
	var t = InteractionManager.get_current_target()
	if t == badge_target:
		return
	badge_target = t
	var icon: Texture2D = null
	if t != null and is_instance_valid(t):
		var holder: Node = t.get_parent() if t.name == "InteractionArea" else t
		if holder is Chicken:
			icon = badge_paw
		elif holder is StaticBody2D:
			icon = badge_talk          # Momo, Teacher Abby, Bob, Pablo, Lola Nena, Farmer Kiko, helpers
		elif not (holder is CollectableComponent):
			icon = badge_use           # letter board, shape board, easel, basket, mixing pot
	var button: Control = get_parent().get_node_or_null("InteractionButton/Button")
	if button:
		button.modulate.a = 1.0 if t != null else 0.6117647
	if icon:
		badge_icon.texture = icon
		badge.visible = true
		badge_anim.play("pop")
	else:
		badge.visible = false

# ---------- paw cursor (computer only) ----------

func _set_cursor() -> void:
	if cursor_texture == null or OS.has_feature("mobile"):
		return
	var img := cursor_texture.get_image()
	if img == null or img.is_empty():
		return
	img.convert(Image.FORMAT_RGBA8)
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(img), Input.CURSOR_ARROW, Vector2(6, 2))

func _exit_tree() -> void:
	# back to the normal cursor outside the level (also frees the paw picture)
	if cursor_texture and not OS.has_feature("mobile"):
		Input.set_custom_mouse_cursor(null)
