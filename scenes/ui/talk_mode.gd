extends Control

## Talking with a mission NPC, the close-up way:
##  - the player walks by themselves to stand right of the NPC (NPC left, player right),
##  - the camera zooms in on the two of them,
##  - everything else on the screen is hidden (mission list, bag, joystick, buttons...),
##  - a wood panel at the top left shows pictures of what is still needed (and how many),
##    an arrow, and where it goes (basket, easel, letter board, blueprint, or the NPC),
##  - the dialogue box at the bottom (bigger text) and the Yes / No buttons at the right.
## When the conversation closes everything goes back the way it was.
## GameUIManager.show_dialogue() starts it, GameUIManager.hide_dialogue() ends it.

const STAND_OFFSET := Vector2(16, 0)      # where the player stands, from the NPC's feet
const ZOOM := 8.0
const ZOOM_TIME := 0.45
const WALK_TIMEOUT := 6.0                 # seconds; then the player is just placed there
## Where the middle of the two characters should be on the screen (between the picture panel and the buttons).
const PAIR_ON_SCREEN := Vector2(650, 250)
## What is NOT hidden while talking (the rest of the game UI is).
const KEEP := ["DialoguePanel", "TalkMode", "MissionCompletePanel", "SettingsPanel", "Selector", "Tutorial"]
const ICONS := "res://scenes/objects/icons/"
const BASKET_ICON := "res://assets/sprites/game/Sprout Lands - Sprites - premium pack/Objects/Piknik basket.png"
const NUMBER_ICON := "res://scenes/collectables/numbers/number_%d.tres"

## The mission NPCs (found by their script).
const TALKERS := ["merchant.gd", "farmer.gd", "teacher.gd", "grandma.gd", "builder.gd", "painter.gd"]

@onready var needs_frame: Control = $NeedsFrame
@onready var needs_grid: GridContainer = $NeedsFrame/Box/Needs
@onready var places_row: HBoxContainer = $NeedsFrame/Box/Places
@onready var arrow: Control = $NeedsFrame/Box/Arrow
@onready var template: Control = $NeedTemplate
@onready var anim: AnimationPlayer = $AnimationPlayer

var active := false
var npc: Node2D = null
var player: Node2D = null
var _hidden: Array[CanvasItem] = []
var _cam_saved := {}

func _ready() -> void:
	visible = false
	GameUIManager.talk_mode = self
	GameUIManager.talking = false
	GameUIManager.talk_speaker = null
	template.visible = false
	# the arrow points down (from the things to where they go)
	var img: Image = arrow.texture.get_image()
	img.rotate_90(CLOCKWISE)
	arrow.texture = ImageTexture.create_from_image(img)

func is_talker(n: Node) -> bool:
	if n == null:
		return false
	if n.name == "InteractionArea":
		n = n.get_parent()
	var s = n.get_script()
	return s != null and s.resource_path.get_file() in TALKERS

## Walks the player over, zooms in, then calls show_words (which opens the dialogue box).
func start(speaker: Node, show_words: Callable) -> void:
	if speaker.name == "InteractionArea":
		speaker = speaker.get_parent()
	active = true
	GameUIManager.talking = true
	GameUIManager.talk_speaker = speaker
	npc = speaker
	player = get_tree().current_scene.get_node_or_null("Player")
	_hide_hud()
	if player:
		player.controls_locked = true
		await _walk_player()
		if not active:
			return
		player.last_direction = "left"            # look at the NPC
		_npc_face("idle_right")
		_zoom_in()
	_show_needs()
	visible = true
	anim.play("show")
	show_words.call()

## Back to playing.
func finish() -> void:
	if not active:
		return
	active = false
	GameUIManager.talking = false
	GameUIManager.talk_speaker = null
	anim.play("hide")
	_npc_face("idle_front")
	_zoom_out()
	for c in _hidden:
		if is_instance_valid(c):
			c.visible = true
	_hidden.clear()
	if player and is_instance_valid(player):
		player.auto_path = PackedVector2Array()
		player.controls_locked = false
		# the "walked away" that was ignored while talking: tell the NPC now if it's true
		var area = npc.get_node_or_null("InteractionArea") if npc and is_instance_valid(npc) else null
		if area and area.is_inside_tree() and not area.overlaps_body(player) and npc.has_method("_on_body_exited"):
			npc._on_body_exited(player)

func _exit_tree() -> void:
	if GameUIManager.talk_mode == self:
		GameUIManager.talking = false
		GameUIManager.talk_speaker = null

# ---------- the player walks to the NPC ----------

func _walk_player() -> void:
	var spot: Vector2 = npc.global_position + STAND_OFFSET
	if player.global_position.distance_to(spot) < 2.0:
		return
	var guide = null
	for n in get_tree().current_scene.get_children():
		if n is GuidePath:
			guide = n
	var path := PackedVector2Array()
	if guide:
		path = guide.path_to(spot)
	path.append(spot)
	player.walk_path(path)
	var t := 0.0
	while active and not player.auto_path.is_empty() and t < WALK_TIMEOUT:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		# stuck against something for a while: stop trying
		if t > 1.0 and player.get_real_velocity().length() < 2.0 and player.global_position.distance_to(spot) > 3.0:
			break
	player.auto_path = PackedVector2Array()
	if active and player.global_position.distance_to(spot) > 1.0:
		var tw := create_tween()
		tw.tween_property(player, "global_position", spot, 0.25)
		await tw.finished

func _npc_face(anim_name: String) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	for c in npc.get_children():
		if c is AnimatedSprite2D and c.sprite_frames and c.sprite_frames.has_animation(anim_name):
			c.play(anim_name)

# ---------- camera ----------

func _zoom_in() -> void:
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam == null:
		return
	_cam_saved = {"zoom": cam.zoom, "offset": cam.offset, "smooth": cam.position_smoothing_enabled,
		"limits": [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom]}
	cam.limit_left = -10000000
	cam.limit_top = -10000000
	cam.limit_right = 10000000
	cam.limit_bottom = 10000000
	cam.position_smoothing_enabled = false
	# the middle of the two characters (a bit above their feet) goes to PAIR_ON_SCREEN
	var mid: Vector2 = (npc.global_position + player.global_position) / 2.0 + Vector2(0, -10)
	var screen_center: Vector2 = get_viewport_rect().size / 2.0
	var offset: Vector2 = (mid - player.global_position) - (PAIR_ON_SCREEN - screen_center) / ZOOM
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "zoom", Vector2(ZOOM, ZOOM), ZOOM_TIME)
	tw.tween_property(cam, "offset", offset, ZOOM_TIME)

func _zoom_out() -> void:
	if player == null or not is_instance_valid(player) or _cam_saved.is_empty():
		return
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam == null:
		return
	var saved := _cam_saved
	_cam_saved = {}
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "zoom", saved["zoom"], ZOOM_TIME)
	tw.tween_property(cam, "offset", saved["offset"], ZOOM_TIME)
	tw.chain().tween_callback(func():
		cam.limit_left = saved["limits"][0]
		cam.limit_top = saved["limits"][1]
		cam.limit_right = saved["limits"][2]
		cam.limit_bottom = saved["limits"][3]
		cam.position_smoothing_enabled = saved["smooth"])

# ---------- the rest of the screen ----------

func _hide_hud() -> void:
	_hidden.clear()
	for c in get_parent().get_children():
		if c is CanvasItem and c.visible and not (String(c.name) in KEEP):
			c.visible = false
			_hidden.append(c)

# ---------- what is needed (pictures only) ----------

## Fills the wood panel: every thing still needed (picture + how many), an arrow,
## and the place(s) where it goes. Nothing needed any more: no panel.
func _show_needs() -> void:
	for c in needs_grid.get_children():
		c.queue_free()
	for c in places_row.get_children():
		c.queue_free()
	var level := get_tree().current_scene
	var needs: Array = []      # [texture, count, tint, badge]
	var places: Array = []     # [texture, tint, badge]
	match GameManager.current_subject:
		"fruits": _fruit_needs(level, needs, places)
		"animals": _animal_needs(level, needs, places)
		"alphabets": _letter_needs(level, needs, places)
		"numbers": _egg_needs(level, needs, places)
		"shapes": _shape_needs(level, needs, places)
		"colors": _paint_needs(level, needs, places)
	needs_frame.visible = not needs.is_empty()
	if needs.is_empty():
		return
	var size := 104.0 if needs.size() <= 2 else (88.0 if needs.size() <= 4 else (70.0 if needs.size() <= 9 else 56.0))
	needs_grid.columns = 2 if needs.size() <= 4 else (3 if needs.size() <= 9 else 4)
	for n in needs:
		needs_grid.add_child(_symbol(n[0], n[1], n[2], n[3], size))
	var place_size := 96.0 if places.size() <= 2 else (60.0 if places.size() <= 4 else 50.0)
	for p in places:
		if p is Control:
			p.custom_minimum_size = Vector2(place_size, place_size)
			places_row.add_child(p)
		else:
			places_row.add_child(_symbol(p[0], 0, p[1], p[2], place_size))
	arrow.visible = not places.is_empty()

## One picture with an optional "x3" and a small picture in the corner.
func _symbol(tex: Texture2D, count: int, tint: Color, badge: Texture2D, size: float) -> Control:
	var s: Control = template.duplicate()
	s.visible = true
	s.custom_minimum_size = Vector2(size, size)
	var icon: TextureRect = s.get_node("Icon")
	icon.texture = tex
	icon.self_modulate = tint
	var b: TextureRect = s.get_node("Badge")
	b.texture = badge
	b.visible = badge != null
	var label: Label = s.get_node("Count")
	label.text = "x%d" % count
	label.visible = count > 1
	return s

func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

func _npc_symbol() -> Texture2D:
	var sym = npc.get_node_or_null("Symbol") if npc else null
	return sym.icon if sym and "icon" in sym else null

func _fruit_needs(level: Node, needs: Array, places: Array) -> void:
	var wanted: Dictionary = npc.quest_items if "quest_items" in npc else {}
	for fruit in wanted:
		var left: int = int(wanted[fruit])
		if QuestManager.active and QuestManager.target_counts.has(fruit):
			left = int(QuestManager.target_counts[fruit]) - int(QuestManager.current_counts.get(fruit, 0))
		if left <= 0:
			continue
		var tex := _tex(ICONS + "fruits/%s.tres" % fruit)
		if tex == null:
			tex = _tex(ICONS + "%s.tres" % fruit)
		needs.append([tex, left, Color.WHITE, null])
	places.append([_npc_symbol(), Color.WHITE, null])

func _animal_needs(level: Node, needs: Array, places: Array) -> void:
	var by_type := {}
	for a in get_tree().get_nodes_in_group("farm_animals"):
		if a.tamed:
			continue
		if not by_type.has(a.item_type):
			by_type[a.item_type] = [a.icon, 0, Color.WHITE, a.food_icon]
		by_type[a.item_type][1] += 1
	for t in by_type:
		needs.append(by_type[t])
	places.append([_npc_symbol(), Color.WHITE, null])

func _letter_needs(level: Node, needs: Array, places: Array) -> void:
	var seq: Node = null
	for n in level.find_children("*", "", true, false):
		if "letter_order" in n:
			seq = n
			break
	if seq == null:
		return
	for i in range(seq.current_index, seq.letter_order.size()):
		var l: String = seq.letter_order[i]
		needs.append([_tex("res://scenes/collectables/alphabets/capital_%s.tres" % l), 1, Color.WHITE, null])
		needs.append([_tex("res://scenes/collectables/alphabets/small_%s.tres" % l.to_lower()), 1, Color.WHITE, null])
	places.append(_mini_letter_board())

## A small letter board: wooden board with a big and a small letter space.
func _mini_letter_board() -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wood := ColorRect.new()
	wood.color = Color(0.62, 0.4, 0.24)
	wood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wood.anchor_top = 0.15
	wood.anchor_right = 1.0
	wood.anchor_bottom = 0.75
	box.add_child(wood)
	var post := ColorRect.new()
	post.color = Color(0.45, 0.28, 0.16)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post.anchor_left = 0.44
	post.anchor_right = 0.56
	post.anchor_top = 0.75
	post.anchor_bottom = 1.0
	box.add_child(post)
	for i in 2:
		var socket := ColorRect.new()
		socket.color = Color(0.98, 0.9, 0.72)
		socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		socket.anchor_left = 0.1 + i * 0.47
		socket.anchor_right = 0.43 + i * 0.47
		socket.anchor_top = 0.24
		socket.anchor_bottom = 0.66
		box.add_child(socket)
	return box

func _egg_needs(level: Node, needs: Array, places: Array) -> void:
	var left := 0
	var baskets := level.find_children("*", "CountBasket", true, false)
	baskets.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	for b in baskets:
		var n: int = int(b.target_count) - int(b.current_count)
		if n <= 0:
			continue
		left += n
		places.append([_tex(BASKET_ICON), Color.WHITE, _tex(NUMBER_ICON % int(b.target_count))])
	if left > 0:
		needs.append([_tex(ICONS + "egg.tres"), left, Color.WHITE, null])

func _shape_needs(level: Node, needs: Array, places: Array) -> void:
	var board: Node = null
	for n in level.find_children("*", "", true, false):
		if n.get_script() and n.get_script().resource_path.get_file() == "shape_board.gd":
			board = n
			break
	if board == null:
		return
	var left := {}
	for hole in board.holes.get_children():
		if not hole.get_meta("filled", false):
			var shape: String = board.shape_of(hole)
			left[shape] = left.get(shape, 0) + 1
	for shape in left:
		var tint := Color.WHITE
		for c in level.find_children("*", "ShapeCollectible", true, false):
			if c.item_type == shape:
				tint = c.tint
				break
		needs.append([_tex(ICONS + "shapes/%s.tres" % shape), left[shape], tint, null])
	places.append(_mini_board(board))

## A small copy of Bob's blueprint: blue board with the outlines of the shapes.
func _mini_board(board: Node) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var area: Panel = board.get_node("Board")
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.33, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bg)
	var inner := Control.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(inner)
	# the hole sprites are placed like on the real board, scaled to the box when it gets its size
	var rect := Rect2(area.position, area.size)
	inner.resized.connect(func():
		for c in inner.get_children():
			c.queue_free()
		var k: float = minf(inner.size.x / rect.size.x, inner.size.y / rect.size.y)
		var off: Vector2 = (inner.size - rect.size * k) / 2.0
		for hole in board.holes.get_children():
			if not (hole is Sprite2D) or hole.texture == null:
				continue
			var t := TextureRect.new()
			t.texture = hole.texture
			t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_SCALE
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sz: Vector2 = hole.texture.get_size() * hole.scale.abs() * k
			t.size = sz
			t.position = off + (hole.position - rect.position) * k - sz / 2.0
			t.modulate = hole.modulate
			t.self_modulate = hole.self_modulate
			inner.add_child(t))
	return box

func _paint_needs(level: Node, needs: Array, places: Array) -> void:
	var easel: Node = null
	for n in level.find_children("*", "", true, false):
		if n.get_script() and n.get_script().resource_path.get_file() == "easel.gd":
			easel = n
			break
	if easel == null:
		return
	var left: Array[String] = []
	for part in easel.parts():
		var c: String = easel.color_of(part)
		if not part.get_meta("painted", false) and not left.has(c):
			left.append(c)
	for c in left:
		needs.append([PaintColors.bucket_icon(c), 1, Color.WHITE, null])
	var outline: Texture2D = null
	for part in easel.picture.get_children():
		if part is Sprite2D and String(part.name).begins_with("Outline"):
			outline = part.texture
	if outline:
		places.append([outline, Color.WHITE, null])
