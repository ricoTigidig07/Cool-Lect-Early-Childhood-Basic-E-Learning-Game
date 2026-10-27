extends StaticBody2D
class_name HelperNPC

## A friendly villager from another subject who gives directions.
## Talk to them and they say where to go next, and a bubble above their head
## shows WHAT to look for (a picture of the item) and an arrow pointing WHERE.
##
##  - Before the mission starts: points to the NPC who gives the mission ("!").
##  - During the mission: points to the closest item that is still needed.
##  - When the player has everything: points to where to use it
##    (letter board, shape board, easel, mixing pot, basket) or back to the mission NPC.
##
## Works in every subject without setup: it reads the level by itself.
## The look is a placeholder (the shared character + a color per NPC).
## When the real NPC designs are ready, change the look in helper_npc.tscn / LOOKS below.

enum Character { MERCHANT, TEACHER, BUILDER, PAINTER, GRANDMA, FARMER }

## Which villager this helper is (sets the name and the placeholder color).
@export var character: Character = Character.GRANDMA:
	set(value):
		character = value
		if is_node_ready():
			_apply_look()

## Name, placeholder color and greeting for each villager.
const LOOKS := {
	Character.MERCHANT: {"name": "Momo", "color": Color(0.66, 0.95, 1.53), "hello": "Hi there! It's me, Momo!"},
	Character.TEACHER: {"name": "Teacher", "color": Color(1.04, 0.43, 0.74), "hello": "Hello, my little student!"},
	Character.BUILDER: {"name": "Bobo", "color": Color(1.35, 1.0, 0.55), "hello": "Hey there, buddy! I'm Bobo!"},
	Character.PAINTER: {"name": "Pinta", "color": Color(1.45, 0.8, 1.35), "hello": "Hi, little artist! It's Pinta!"},
	Character.GRANDMA: {"name": "Grandma", "color": Color(0.4, 0.8, 0.0), "hello": "Oh hello, dear! It's Grandma."},
	Character.FARMER: {"name": "Farmer", "color": Color(1.29, 0.79, 0.0), "hello": "Howdy, little friend!"},
}

## The mission NPCs, found by their script.
const GIVERS := {
	"merchant.gd": "Momo",
	"teacher.gd": "the Teacher",
	"builder.gd": "Bobo",
	"painter.gd": "Pinta",
	"grandma.gd": "Grandma",
	"farmer.gd": "the Farmer",
}

## Where the player uses what they collected, found by their script.
const STATIONS := {
	"letter_frame.gd": "the letter board",
	"shape_board.gd": "the shape board",
	"easel.gd": "the easel",
	"count_basket.gd": "the basket",
	"mixing_pot.gd": "the mixing pot",
}

## What each animal food is called when talking.
const FOOD_NAMES := {
	"seed": "seeds", "bread": "bread", "grass": "grass", "corn": "corn", "hay": "hay",
	"carrot": "carrots", "leaf": "leaves", "apple": "apples", "fish": "fish", "bone": "bones",
	"berry": "berries", "milk": "milk",
}

const GUIDE_ARROW := preload("res://scenes/characters/helper/guide_arrow.tscn")

const ICON_SIZE := 13.0      # how big the item picture is inside the bubble (pixels)
const AUTO_CLOSE_TIME := 3.0 # seconds the words stay after the last page

@export var talk_icon: Texture2D       # "!" shown when you should talk to the mission NPC

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var ask_mark: Sprite2D = $AskMark
@onready var bubble: Node2D = $HintBubble
@onready var item_icon: Sprite2D = $HintBubble/ItemIcon
@onready var arrow_pivot: Node2D = $HintBubble/ArrowPivot
@onready var bubble_anim: AnimationPlayer = $BubbleAnim

var display_name: String = ""          # read by the dialogue box for the name tag
var player_near := false
var is_dialogue_open := false
var talk_id := 0
var target: Node2D = null              # what the arrow points at
var player_ref: Node2D = null

func _ready() -> void:
	_apply_look()
	bubble.visible = false
	bubble.scale = Vector2.ZERO
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _apply_look() -> void:
	var look: Dictionary = LOOKS[character]
	display_name = look["name"]
	if sprite:
		sprite.modulate = look["color"]

# ---------- player near / far ----------

func _on_body_entered(body: Node2D) -> void:
	if body is Player01:
		player_near = true
		player_ref = body
		InteractionManager.register(self)
		ask_mark.visible = false
		_face(body.global_position)
		var portrait = get_tree().get_first_node_in_group("avatar_icon")
		if portrait:
			portrait.set_near_merchant(true)
			portrait.play("merchant_defaults")

func _on_body_exited(body: Node2D) -> void:
	if body is Player01:
		player_near = false
		InteractionManager.unregister(self)
		ask_mark.visible = true
		sprite.play("idle_front")
		var portrait = get_tree().get_first_node_in_group("avatar_icon")
		if portrait:
			portrait.play("defaults")
			portrait.set_near_merchant(false)
		if is_dialogue_open:
			GameUIManager.hide_dialogue()
			is_dialogue_open = false
		_hide_bubble()

# ---------- talking ----------

func interact() -> void:
	var portrait = get_tree().get_first_node_in_group("avatar_icon")
	if is_dialogue_open:
		GameUIManager.hide_dialogue()
		is_dialogue_open = false
		if portrait:
			portrait.play("merchant_defaults")
		return
	var hint := find_hint()
	target = hint["node"]
	if GameManager.helper_hints:      # Settings > Helper hints
		_show_bubble(hint["icon"], hint["tint"])
		_guide_player(hint)
	if portrait:
		portrait.play("merchant_talking")
	var lines: Array[String] = [LOOKS[character]["hello"]]
	var text: String = hint["text"]
	if text.contains("%s"):
		text = text % _direction_words(target)
	lines.append(text)
	GameUIManager.show_dialogue(lines)
	is_dialogue_open = true
	talk_id += 1
	var panel = GameUIManager.dialogue_panel
	if panel and not panel.finished.is_connected(_on_dialogue_finished):
		GameUIManager.connect_dialogue_finished(_on_dialogue_finished)
	AudioManager.play_sfx("pop")

func _on_dialogue_finished() -> void:
	var id := talk_id
	var portrait = get_tree().get_first_node_in_group("avatar_icon")
	if portrait:
		portrait.play("merchant_defaults")
	await get_tree().create_timer(AUTO_CLOSE_TIME).timeout
	# close the words if they're still ours (the bubble + arrow stay while you're near)
	if is_dialogue_open and id == talk_id and player_near:
		GameUIManager.hide_dialogue()
		is_dialogue_open = false

# ---------- the arrow at the player's feet ----------

## Puts (or re-aims) the GuideArrow under the player. It stays until the job is done.
func _guide_player(hint: Dictionary) -> void:
	var to: Node2D = hint["node"]
	if player_ref == null or not is_instance_valid(player_ref) or to == null:
		return
	var arrow = player_ref.get_node_or_null("GuideArrow")
	if arrow == null or arrow.is_queued_for_deletion():
		arrow = GUIDE_ARROW.instantiate()
		player_ref.add_child(arrow)
	arrow.point_to(to, _done_check(hint))

## When the arrow can go away.
func _done_check(hint: Dictionary) -> Callable:
	var to: Node2D = hint["node"]
	var p: Node2D = player_ref
	match hint.get("kind", ""):
		"start":    # talk to the mission NPC first
			var giver: Node = to
			return func() -> bool: return _mission_started(giver)
		"item":     # until it's picked up (or the animal is your friend)
			return func() -> bool:
				if not is_instance_valid(to):
					return true
				if to is Chicken:
					return to.tamed or to.is_collecting
				return to.is_collecting or not to.is_visible_in_tree()
		_:          # a place or the mission NPC: until you get there
			return func() -> bool:
				return not is_instance_valid(to) or not is_instance_valid(p) \
					or p.global_position.distance_to(to.global_position) < 30.0

# ---------- the bubble ----------

func _show_bubble(icon: Texture2D, tint: Color) -> void:
	if icon == null:
		icon = talk_icon
	item_icon.texture = icon
	item_icon.modulate = tint
	if icon:
		var size := icon.get_size()
		item_icon.scale = Vector2.ONE * (ICON_SIZE / max(size.x, size.y))
	bubble.visible = true
	_update_arrow()
	bubble_anim.play("pop_in")

func _hide_bubble() -> void:
	target = null
	if bubble.visible:
		bubble_anim.play("pop_out")

func _process(_delta: float) -> void:
	if bubble.visible and target:
		_update_arrow()

func _update_arrow() -> void:
	if target == null or not is_instance_valid(target):
		arrow_pivot.visible = false
		return
	var to := target.global_position - global_position
	arrow_pivot.visible = to.length() > 20.0
	arrow_pivot.rotation = to.angle()

func _face(pos: Vector2) -> void:
	var d := pos - global_position
	if abs(d.x) > abs(d.y):
		sprite.play("idle_right" if d.x > 0 else "idle_left")
	else:
		sprite.play("idle_front" if d.y > 0 else "idle_back")

## "up and to the left", "close by"
func _direction_words(node: Node2D) -> String:
	if node == null or not is_instance_valid(node):
		return "somewhere around here"
	var d := node.global_position - global_position
	if d.length() < 40.0:
		return "right here next to me"
	var up_down := ""
	var side := ""
	if abs(d.y) > abs(d.x) * 0.45:
		up_down = "up" if d.y < 0 else "down"
	if abs(d.x) > abs(d.y) * 0.45:
		side = "to the left" if d.x < 0 else "to the right"
	var where := up_down
	if side != "":
		where = side if where == "" else where + " and " + side
	if d.length() > 400.0:
		where += ", far away"
	return where

# ---------- reading the level ----------

func _level() -> Node:
	var n: Node = self
	while n.get_parent() and n.get_parent() != get_tree().root:
		n = n.get_parent()
	return n

func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_all(c, out)

func _script_name(n: Node) -> String:
	var s = n.get_script()
	return s.resource_path.get_file() if s else ""

## How many of this item the player is holding in the hotbar.
func _held(item: String) -> int:
	var bar = GameUIManager.hotbar
	if bar == null or not ("slot_by_item" in bar) or not bar.slot_by_item.has(item):
		return 0
	return int(bar.slot_by_item[item].get_node("Label").text)

func _icon_of(n: Node) -> Texture2D:
	var s = n.get_node_or_null("Sprite2D")
	if s and s is Sprite2D:
		return s.texture
	for c in n.get_children():
		if c is Sprite2D and c.texture:
			return c.texture
		if c is AnimatedSprite2D and c.sprite_frames:
			return c.sprite_frames.get_frame_texture(c.animation, 0)
	return null

## Returns {node, icon, tint, text}. text has one %s for the direction.
func find_hint() -> Dictionary:
	var nodes: Array = []
	_all(_level(), nodes)
	var giver: Node2D = null
	var giver_name := ""
	var stations: Array = []
	for n in nodes:
		var sn := _script_name(n)
		if GIVERS.has(sn) and n != self and giver == null:
			giver = n
			giver_name = GIVERS[sn]
		elif STATIONS.has(sn):
			stations.append(n)

	var excl := {"node": giver, "icon": talk_icon, "tint": Color.WHITE, "kind": "start"}
	if giver == null:
		excl["text"] = "Have fun exploring!"
		return excl

	# 1. the mission hasn't started yet
	if not _mission_started(giver):
		excl["text"] = "%s needs your help! Go and talk to %s first. Follow the arrow, it's %%s!" % [giver_name.capitalize(), giver_name]
		return excl

	# 2. the closest item that is still needed
	var best: Node2D = null
	var best_d := INF
	var best_info := {}
	for n in nodes:
		if not (n is CollectableComponent) or not n.is_visible_in_tree() or n.is_collecting:
			continue
		var info := _item_info(n, stations)
		if info.is_empty() or not _bag_has_room(n):
			continue
		var dist: float = global_position.distance_to(n.global_position)
		if dist < best_d:
			best_d = dist
			best = n
			best_info = info
	if best:
		return {"node": best, "icon": best_info["icon"], "tint": best_info.get("tint", Color.WHITE), "kind": "item",
			"text": "Looking for %s? It's %%s! Follow the arrow!%s" % [best_info["name"], best_info.get("extra", "")]}

	# 3. nothing left to find: where to use it
	var place := _station_to_use(stations)
	if place.size() > 0:
		return {"node": place["node"], "icon": place["icon"], "tint": place.get("tint", Color.WHITE), "kind": "place",
			"text": "You have what you need! Go to %s. It's %%s!" % place["name"]}

	# 4. go back to the mission NPC
	excl["kind"] = "return"
	excl["text"] = "Great job! Now go back to %s. It's %%s!" % giver_name
	return excl

func _mission_started(giver: Node) -> bool:
	if "lesson_started" in giver:
		return giver.lesson_started
	# Momo (fruits) uses the quest list
	if "quest_ready_to_deliver" in giver and giver.quest_ready_to_deliver:
		return true
	return QuestManager.active

## Can this item still go in the bag? (5 slots: when they are all full of other things,
## the helper should send you to use them first instead of to an item you can't pick up.)
func _bag_has_room(n: Node) -> bool:
	var bar = GameUIManager.hotbar
	if bar == null or not (n is ShapeCollectible or n is PaintBucket or n is LetterCollectible or n.item_type == "egg"):
		return true
	return bar.slot_by_item.has(n.item_type) or bar._find_empty_slot() != null

## Is this item still needed? Returns {name, icon, tint} or {} if not.
func _item_info(n: Node, stations: Array) -> Dictionary:
	var type: String = n.item_type
	# animals: still running around
	if n is Chicken:
		if n.tamed:
			return {}
		var food := " Remember, it likes %s!" % FOOD_NAMES.get(n.required_item, n.required_item) if n.required_item != "" else ""
		return {"name": "the %s" % type, "extra": food, "icon": n.icon if n.icon else _icon_of(n)}
	# letters: only the letter the lesson is on, if not picked up yet
	if n is LetterCollectible:
		var seq = n.get_node_or_null(n.letter_sequence)
		if seq == null or not seq.is_collectible(type) or _held(type) > 0:
			return {}
		var kind := "big letter" if type == type.to_upper() else "small letter"
		return {"name": "the %s %s" % [kind, type], "icon": GameUIManager.get_item_icon(type)}
	# shapes: the board still has an empty hole for it (minus what you already hold)
	if n is ShapeCollectible:
		var board = n.get_node_or_null(n.shape_board)
		if board == null or not board.needs(type):
			return {}
		var empty := 0
		for hole in board.holes.get_children():
			if not hole.get_meta("filled") and board.shape_of(hole) == type:
				empty += 1
		if _held(type) >= empty:
			return {}
		return {"name": _a(type), "icon": _icon_of(n), "tint": n.tint}
	# paint: the easel needs it (or it mixes into a color it needs), and you don't have it
	if n is PaintBucket:
		var easel = n.get_node_or_null(n.easel)
		if easel == null or not easel.wants_paint(type) or _held(type) > 0:
			return {}
		return {"name": "%s paint" % type, "icon": PaintColors.bucket_icon(type)}
	# eggs: the baskets still need more than you're holding
	if type == "egg":
		var missing := 0
		for b in stations:
			if b is CountBasket and not b.is_full:
				missing += b.target_count - b.current_count
		if missing <= _held("egg"):
			return {}
		return {"name": "an egg", "icon": _icon_of(n)}
	# fruits: Momo still wants this fruit
	if type == "fruits":
		var fruit: String = n.collectable_name
		if not QuestManager.active or not QuestManager.target_counts.has(fruit):
			return {}
		if QuestManager.current_counts.get(fruit, 0) >= QuestManager.target_counts[fruit]:
			return {}
		return {"name": _a(fruit), "icon": _icon_of(n)}
	return {}

## "a circle", "an apple", "some grapes"
func _a(word: String) -> String:
	if word.ends_with("s"):
		return "some " + word
	if "aeiou".contains(word.substr(0, 1)):
		return "an " + word
	return "a " + word

func _nearest_open_basket(stations: Array) -> Node2D:
	var best: Node2D = null
	for b in stations:
		if b is CountBasket and not b.is_full:
			if best == null or global_position.distance_to(b.global_position) < global_position.distance_to(best.global_position):
				best = b
	return best

## Where to use what you're holding: {node, name, icon, tint} or {}.
func _station_to_use(stations: Array) -> Dictionary:
	for s in stations:
		var sn := _script_name(s)
		match sn:
			"letter_frame.gd":
				var seq = s.get_node_or_null(s.letter_sequence)
				if seq and not seq.is_complete():
					var l: String = seq.current_letter()
					return {"node": s, "name": STATIONS[sn], "icon": GameUIManager.get_item_icon(l)}
			"shape_board.gd":
				if not s.is_complete():
					var shape: String = s.next_needed_shape()
					return {"node": s, "name": STATIONS[sn], "icon": GameUIManager.get_item_icon(shape)}
			"count_basket.gd":
				var basket := _nearest_open_basket(stations)
				if basket:
					return {"node": basket, "name": "the basket with the number %d" % basket.target_count, "icon": GameUIManager.get_item_icon("egg")}
	# colors: paint what you hold, otherwise mix
	for s in stations:
		if _script_name(s) == "easel.gd" and not s.is_complete():
			for c in s.needed_colors():
				if s.needs(c) and _held(c) > 0:
					return {"node": s, "name": STATIONS["easel.gd"], "icon": PaintColors.bucket_icon(c)}
			for p in stations:
				if _script_name(p) == "mixing_pot.gd":
					return {"node": p, "name": STATIONS["mixing_pot.gd"], "icon": PaintColors.bucket_icon(s.next_needed_color())}
			return {"node": s, "name": STATIONS["easel.gd"], "icon": PaintColors.bucket_icon(s.next_needed_color())}
	return {}
