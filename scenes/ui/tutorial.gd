extends Control

## "How to play" pages shown when a level starts.
## Each subject has its own pages with pictures of the characters and items:
##   1. Meet the mission NPC   2. Find the items   3. Use them
##   4. Lost? Ask a helper      5. Get 3 stars
## "Don't show this again" hides this subject's tutorial until the game is opened
## again (it is NOT saved: GameManager.tutorials_hidden is cleared on every start).
## It can always be opened again from the pause menu ("How to Play").

const PLAYER_FRAMES := preload("res://resources/character_animation.tres")
const NPC_FRAMES := preload("res://scenes/characters/helper/npc_placeholder_frames.tres")
const HAND := preload("res://assets/UI/ui/Sprite sheets/Mouse sprites/Catpaw Mouse icon.png")
const HAND_TINT := Color(1, 0.986, 0.72)

## Mission NPC of each subject: name and placeholder color (same as the helpers).
const GIVERS := {
	"fruits": ["Momo", Color(0.66, 0.95, 1.53)],
	"animals": ["the Farmer", Color(1.29, 0.79, 0.0)],
	"alphabets": ["the Teacher", Color(1.04, 0.43, 0.74)],
	"numbers": ["Grandma", Color(0.4, 0.8, 0.0)],
	"shapes": ["Bobo", Color(1.35, 1.0, 0.55)],
	"colors": ["Pinta", Color(1.45, 0.8, 1.35)],
}
const HELPER_COLOR := Color(1.45, 0.8, 1.35)
## The real look of each subject's mission NPC, and of the helper shown on the "Lost?" page.
const GIVER_LOOKS := {"fruits": "merchant", "animals": "farmer", "alphabets": "teacher",
	"numbers": "grandma", "shapes": "builder", "colors": "painter"}
const NPC_SCALE := 5.0

@export var talk_icon: Texture2D
@export var paw_icon: Texture2D
@export var ask_icon: Texture2D
@export var star_icon: Texture2D
@export var board_texture: Texture2D
@export var box_off: Texture2D
@export var box_on: Texture2D
@export var dot_on: Texture2D
@export var dot_off: Texture2D

@onready var card: Control = $Card
@onready var title: Label = $Card/Title
@onready var text: Label = $Card/Text
@onready var left_char: AnimatedSprite2D = $Card/Picture/LeftChar
@onready var right_char: AnimatedSprite2D = $Card/Picture/RightChar
@onready var right_pic: TextureRect = $Card/Picture/RightPic
@onready var right_badge: TextureRect = $Card/Picture/RightPic/Badge
@onready var items: HBoxContainer = $Card/Picture/Items
@onready var arrow: Control = $Card/Picture/Arrow
@onready var action: TextureRect = $Card/Picture/Action
@onready var dots: HBoxContainer = $Card/Dots
@onready var back_button: Button = $Card/Buttons/Back
@onready var next_button: Button = $Card/Buttons/Next
@onready var go_button: Button = $Card/Buttons/Go
@onready var dont_show: Button = $Card/DontShow
@onready var anim: AnimationPlayer = $AnimationPlayer

var subject := ""
var pages: Array = []
var page := 0
var hide_ticked := false
var was_paused := false
var return_to_menu := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("tutorial")
	visible = false
	back_button.pressed.connect(_go.bind(-1))
	next_button.pressed.connect(_go.bind(1))
	go_button.pressed.connect(close)
	dont_show.pressed.connect(_toggle_dont_show)
	await get_tree().process_frame
	subject = _find_subject()
	if subject != "" and not GameManager.tutorials_hidden.get(subject, false):
		await get_tree().create_timer(0.4).timeout
		open()

## from_menu: opened with "How to Play" (the game is already paused).
func open(from_menu := false) -> void:
	if subject == "":
		subject = _find_subject()
	if subject == "":
		return
	pages = _pages_for(subject)
	page = 0
	hide_ticked = GameManager.tutorials_hidden.get(subject, false)
	dont_show.visible = not from_menu
	return_to_menu = from_menu
	was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	get_parent().move_child(self, -1)
	_build_dots()
	_show_page()
	anim.play("open")

func close() -> void:
	if hide_ticked:
		GameManager.tutorials_hidden[subject] = true
	visible = false
	if return_to_menu:
		# back to the pause menu we came from (the game stays paused)
		var menu = get_tree().get_first_node_in_group("ingame_settings")
		if menu:
			menu.visible = true
			return
	get_tree().paused = was_paused

func _toggle_dont_show() -> void:
	hide_ticked = not hide_ticked
	dont_show.icon = box_on if hide_ticked else box_off

func _go(step: int) -> void:
	page = clamp(page + step, 0, pages.size() - 1)
	_show_page()
	anim.play("page")

# ---------- one page ----------

func _show_page() -> void:
	var p: Dictionary = pages[page]
	title.text = p["title"]
	text.text = p["text"]
	# left: the player
	left_char.visible = p.get("player", true)
	var walk := "walk_right" if p.get("arrow", false) and PLAYER_FRAMES.has_animation("walk_right") else "idle_front"
	left_char.play(p.get("player_anim", walk))
	# right: an NPC / helper, or a picture (basket, board, easel ...)
	right_char.visible = p.has("npc_color")
	if right_char.visible:
		var look: String = p.get("npc_look", "")
		if NpcLooks.FRAMES.has(look):
			right_char.sprite_frames = NpcLooks.FRAMES[look]
			right_char.modulate = Color.WHITE
			right_char.scale = Vector2.ONE * NPC_SCALE * NpcLooks.SCALE[look]
		else:
			right_char.sprite_frames = NPC_FRAMES
			right_char.modulate = p["npc_color"]
			right_char.scale = Vector2(5, 5)
		right_char.play("idle_front")
	right_pic.visible = p.has("pic")
	if right_pic.visible:
		right_pic.texture = p["pic"]
		right_pic.modulate = p.get("pic_tint", Color.WHITE)
	right_badge.visible = p.has("badge")
	if right_badge.visible:
		right_badge.texture = p["badge"]
	# items in the middle
	var list: Array = p.get("items", [])
	for i in items.get_child_count():
		var slot := items.get_child(i) as TextureRect
		slot.visible = i < list.size()
		if slot.visible:
			var it = list[i]
			slot.texture = it[0] if it is Array else it
			slot.modulate = it[1] if it is Array else Color.WHITE
	arrow.visible = p.get("arrow", false)
	action.visible = p.has("action")
	if action.visible:
		action.texture = p["action"]
		action.modulate = p.get("action_tint", Color.WHITE)
	# buttons + dots
	back_button.disabled = page == 0
	var last := page == pages.size() - 1
	next_button.visible = not last
	go_button.visible = last
	dont_show.icon = box_on if hide_ticked else box_off
	for i in dots.get_child_count():
		(dots.get_child(i) as TextureRect).texture = dot_on if i == page else dot_off

func _build_dots() -> void:
	for i in dots.get_child_count():
		dots.get_child(i).visible = i < pages.size()

# ---------- which subject ----------

func _find_subject() -> String:
	var level: Node = get_parent().get_parent() if get_parent() else null
	var path: String = level.scene_file_path if level else ""
	for s in GIVERS:
		if path.contains("/levels/%s/" % s):
			return s
	return GameManager.current_subject if GIVERS.has(GameManager.current_subject) else ""

# ---------- the pages of each subject ----------

func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

func _pages_for(s: String) -> Array:
	var giver: String = GIVERS[s][0]
	var giver_color: Color = GIVERS[s][1]
	var Giver := giver.substr(0, 1).to_upper() + giver.substr(1)
	var giver_look: String = GIVER_LOOKS[s]
	var out: Array = []
	out.append({"title": "Meet %s!" % Giver, "npc_color": giver_color, "npc_look": giver_look, "action": talk_icon,
		"arrow": true,
		"text": "Walk with the joystick to %s.\nTap the hand button to talk and say YES!" % giver})
	match s:
		"fruits":
			var fruits := [_tex("res://scenes/objects/icons/apple.tres"), _tex("res://scenes/objects/icons/fruits/banana.tres"), _tex("res://scenes/objects/icons/fruits/grapes.tres")]
			out.append({"title": "Find the fruits", "items": fruits, "arrow": true, "action": HAND, "action_tint": HAND_TINT,
				"text": "Look for the fruits Momo asks for.\nHold the hand button next to a fruit to pick it up."})
			out.append({"title": "Bring them back", "items": [fruits[0]], "arrow": true, "npc_color": giver_color, "npc_look": giver_look,
				"text": "Got them all? Go back to Momo and give him the fruits!"})
		"animals":
			out.append({"title": "Pick the food", "items": [_tex("res://assets/sprites/animals/food/bread.png"), _tex("res://assets/sprites/animals/food/corn.png")], "action": HAND, "action_tint": HAND_TINT,
				"text": "The Farmer puts food in your bag (at the bottom).\nTap a food to hold it."})
			out.append({"title": "Make friends", "items": [_tex("res://assets/sprites/animals/food/bread.png")], "arrow": true,
				"pic": _tex("res://assets/sprites/animals/duck_icon.png"), "badge": paw_icon,
				"text": "The bubble shows what an animal likes.\nHold the button next to it with that food!"})
		"alphabets":
			var big := _tex("res://scenes/collectables/alphabets/capital_A.tres")
			var small := _tex("res://scenes/collectables/alphabets/small_a.tres")
			out.append({"title": "Find the letters", "items": [big, small], "action": HAND, "action_tint": HAND_TINT,
				"text": "Find the BIG letter and the small letter.\nHold the hand button to pick them up."})
			out.append({"title": "Fill the letter board", "items": [big, small], "arrow": true, "pic": board_texture, "badge": small,
				"text": "Hold the button at the letter board.\nBig letter on the left, small letter on the right!"})
		"numbers":
			var egg := _tex("res://scenes/objects/icons/egg.tres")
			out.append({"title": "Find the eggs", "items": [egg, egg, egg], "action": HAND, "action_tint": HAND_TINT,
				"text": "Grandma's hens laid eggs everywhere.\nHold the hand button to pick them up."})
			out.append({"title": "Count into the basket", "items": [egg], "arrow": true,
				"pic": _tex("res://assets/sprites/game/Sprout Lands - Sprites - premium pack/Objects/Piknik basket.png"),
				"badge": _tex("res://scenes/collectables/numbers/number_3.tres"),
				"text": "Hold at a basket to drop ONE egg.\nCount 1, 2, 3... until it matches the number!"})
		"shapes":
			var shapes := [[_tex("res://scenes/objects/icons/shapes/circle.tres"), Color(1, 0.85, 0.3)],
				[_tex("res://scenes/objects/icons/shapes/square.tres"), Color(0.9, 0.4, 0.35)],
				[_tex("res://scenes/objects/icons/shapes/triangle.tres"), Color(0.45, 0.65, 1)]]
			out.append({"title": "Find the shapes", "items": shapes, "action": HAND, "action_tint": HAND_TINT,
				"text": "Find the shape blocks: circles, squares, triangles...\nHold the hand button to pick them up."})
			out.append({"title": "Build the picture", "items": [shapes[0]], "arrow": true,
				"pic": board_texture, "pic_tint": Color(0.55, 0.75, 1.3),
				"badge": _tex("res://scenes/objects/icons/shapes/circle.tres"),
				"text": "Hold the button at Bobo's board.\nPut each shape in the outline that matches!"})
		"colors":
			var red := PaintColors.bucket_icon("red")
			var yellow := PaintColors.bucket_icon("yellow")
			out.append({"title": "Find the paint", "items": [red, yellow], "action": HAND, "action_tint": HAND_TINT,
				"text": "Find the paint buckets Pinta needs.\nHold the hand button to pick them up."})
			out.append({"title": "Paint and mix", "items": [red, yellow, PaintColors.bucket_icon("orange")], "arrow": true,
				"pic": _tex("res://assets/colors/pictures/apple_red.png"), "pic_tint": PaintColors.color("red"),
				"text": "Hold at the easel to paint.\nNo color? Mix two in the pot: red + yellow = orange!"})
	var helper_color := HELPER_COLOR if s != "colors" else Color(0.4, 0.8, 0.0)   # never the same as the mission NPC
	out.append({"title": "Lost? Ask a helper!", "npc_color": helper_color, "npc_look": "painter" if s != "colors" else "grandma", "action": ask_icon, "arrow": true,
		"text": "Villagers with a ? know where things are.\nTalk to them and follow the arrow at your feet!"})
	out.append({"title": "Get 3 stars!", "player_anim": "idle_front", "npc_color": giver_color, "npc_look": giver_look,
		"items": [star_icon, star_icon, star_icon],
		"text": "Talk, find, and go back to %s to finish all 3 missions.\nHave fun!" % giver})
	return out
