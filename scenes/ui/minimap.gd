extends Control

## The map in the top-right corner (under it: the Map button and the Settings button).
##  - Small map: a little window over the level that follows the player, with North /
##    South / West / East around it and a dot where the player is.
##  - Map button: the whole level on the screen (the game waits meanwhile). Tap X to close.
## Both windows look at the real level (they share its World2D), so they always match it.
##  - Explored: a circle around the player is "explored" as they walk and is remembered.
##    Places not explored yet are dark: on the game screen (the edges, until you go
##    there), on the small map, and on the big map (with a still picture faintly showing).
##  - The player is shown by their head; things to collect get big icons so they are easy
##    to see on the zoomed-out maps.

const SMALL_ZOOM := 0.5           # how much of the level the small map shows (smaller = more)
const COMPASS := ["North", "South", "West", "East"]
const CELL := 8.0                 # explored mask: one pixel per this many world pixels
const SEE_RADIUS := 150.0         # how far around the player becomes explored (world px)
const SCREEN_DARK := 0.20       # how dark unexplored places are on the game screen
const SMALL_ICON := 28.0          # size of the item icons on the small map
const BIG_ICON := 28.0            # ... and on the big map
## Outline colours of the round badges (the player's is red, in minimap.tscn "SB_dot").
const NPC_RING := Color(0.98, 0.72, 0.2)       # NPCs: yellow
const THING_RING := Color(0.36, 0.72, 0.33)    # things to collect and animals: green

@onready var small_vp: SubViewport = $Frame/View/Viewport
@onready var small_cam: Camera2D = $Frame/View/Viewport/Cam
@onready var small_view: SubViewportContainer = $Frame/View
@onready var small_dot: Control = $Frame/Dot
@onready var big: Control = $BigMap
@onready var big_vp: SubViewport = $BigMap/Frame/View/Viewport
@onready var big_cam: Camera2D = $BigMap/Frame/View/Viewport/Cam
@onready var big_view: SubViewportContainer = $BigMap/Frame/View
@onready var big_dot: Control = $BigMap/Frame/Dot
@onready var map_button: BaseButton = $MapButton
@onready var small_items: Control = $Frame/Items
@onready var big_items: Control = $BigMap/Frame/Items
@onready var fog: ColorRect = $BigMap/Frame/Fog
var screen_fog: ColorRect           # over the level on the game screen (made in _ready)

var player: Node2D
var bounds := Rect2()
var _explored: Image                # white where the player has been
var _explored_tex: ImageTexture
var _explored_dirty := false
var _explored_timer := 0.0
var _last_mark := Vector2.INF
var _snapshot: ImageTexture         # still picture of the whole level (under the dark)
var _things: Array = []             # collectables to show as icons
var _things_timer := 0.0
var _icons := {}                    # collectable -> [small icon, big icon]


func _ready() -> void:
	big.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS      # the big map works while the game waits
	map_button.pressed.connect(open_big)
	$BigMap/Frame/Close.pressed.connect(close_big)
	small_vp.world_2d = get_viewport().world_2d
	big_vp.world_2d = get_viewport().world_2d
	big_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	small_cam.zoom = Vector2.ONE * SMALL_ZOOM
	for frame in [$Frame, $BigMap/Frame]:
		for i in COMPASS.size():
			frame.get_node(COMPASS[i]).text = Lang.line(COMPASS[i])
	$BigMap/Frame/Title.text = Lang.line("Map")
	await get_tree().process_frame
	await get_tree().process_frame
	var level := get_tree().current_scene
	player = level.get_node_or_null("Player") if level else null
	bounds = _level_bounds(level)
	if bounds.has_area():
		small_cam.limit_left = int(bounds.position.x)
		small_cam.limit_top = int(bounds.position.y)
		small_cam.limit_right = int(bounds.end.x)
		small_cam.limit_bottom = int(bounds.end.y)
		var w := int(ceil(bounds.size.x / CELL))
		var h := int(ceil(bounds.size.y / CELL))
		_explored = Image.create(maxi(w, 1), maxi(h, 1), false, Image.FORMAT_L8)
		_explored_tex = ImageTexture.create_from_image(_explored)
		_make_screen_fog()
		# each dark layer gets its own copy of the material (they show different places)
		for f in [fog, screen_fog]:
			var mat := (fog.material as ShaderMaterial).duplicate() as ShaderMaterial
			mat.set_shader_parameter("explored", _explored_tex)
			mat.set_shader_parameter("level_rect", Vector4(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y))
			f.material = mat
		(fog.material as ShaderMaterial).set_shader_parameter("use_snapshot", true)
		(screen_fog.material as ShaderMaterial).set_shader_parameter("max_dark", SCREEN_DARK)
		_mark_explored(1.0)
		_explored_tex.update(_explored)
	else:
		fog.visible = false
	var head := _player_head()
	for dot in [small_dot, big_dot]:
		dot.get_node("Head").texture = head


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		small_dot.visible = false
		return
	small_cam.global_position = player.global_position
	small_dot.visible = true
	_place_dot(small_dot, small_view, small_cam)
	_mark_explored(delta)
	_update_fog_views()
	_things_timer -= delta
	if _things_timer <= 0.0:
		_things_timer = 1.0
		_find_things()
	_place_icons(small_items, small_cam, 0, false)
	if big.visible:
		_place_dot(big_dot, big_view, big_cam)
		_place_icons(big_items, big_cam, 1, true)


## The dot sits on the player, wherever the map camera looks.
func _place_dot(dot: Control, view: SubViewportContainer, cam: Camera2D) -> void:
	var center := cam.get_screen_center_position()
	var p := (player.global_position - center) * cam.zoom + view.size * 0.5
	p.x = clampf(p.x, 4.0, view.size.x - 4.0)
	p.y = clampf(p.y, 4.0, view.size.y - 4.0)
	dot.position = view.position + p - dot.size * 0.5


# ---------- explored places ----------

## A circle around the player becomes explored (and stays explored).
func _mark_explored(delta: float) -> void:
	if _explored == null:
		return
	var center := player.global_position
	if center.distance_to(_last_mark) > CELL * 0.5:
		_last_mark = center
		var c := (center - bounds.position) / CELL
		var r := SEE_RADIUS / CELL
		var w := _explored.get_width()
		var h := _explored.get_height()
		for y in range(clampi(int(c.y - r), 0, h), clampi(int(c.y + r) + 1, 0, h)):
			for x in range(clampi(int(c.x - r), 0, w), clampi(int(c.x + r) + 1, 0, w)):
				if Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
					_explored.set_pixel(x, y, Color.WHITE)
		_explored_dirty = true
	_explored_timer -= delta
	if _explored_dirty and (_explored_timer <= 0.0 or big.visible):
		_explored_timer = 0.15
		_explored_dirty = false
		_explored_tex.update(_explored)

## The game screen and the small map: tell their dark layer which part of the world is under it.
func _update_fog_views() -> void:
	if _explored == null:
		return
	var to_world := get_viewport().get_canvas_transform().affine_inverse()
	var screen := get_viewport().get_visible_rect().size * to_world.get_scale()
	(screen_fog.material as ShaderMaterial).set_shader_parameter("view_rect",
		Vector4(to_world.origin.x, to_world.origin.y, screen.x, screen.y))

## The dark over the level on the game screen: above the level, under the buttons.
func _make_screen_fog() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ExploreDark"
	layer.layer = 2                   # the level and its light filter: under; the game UI (5): over
	screen_fog = ColorRect.new()
	screen_fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_fog.color = Color.BLACK
	layer.add_child(screen_fog)
	add_child(layer)

func _is_explored(world: Vector2) -> bool:
	if _explored == null:
		return true
	var c := ((world - bounds.position) / CELL).floor()
	if c.x < 0 or c.y < 0 or c.x >= _explored.get_width() or c.y >= _explored.get_height():
		return false
	return _explored.get_pixel(int(c.x), int(c.y)).r > 0.5

# ---------- the player's head ----------

## The front-facing picture of the player, cut down to the head.
func _player_head() -> Texture2D:
	var body: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D2") if player else null
	if body == null or body.sprite_frames == null or not body.sprite_frames.has_animation(&"idle_front"):
		return null
	var tex := body.sprite_frames.get_frame_texture(&"idle_front", 0)
	if not (tex is AtlasTexture):
		return tex
	var src := tex as AtlasTexture
	var img := src.atlas.get_image().get_region(Rect2i(src.region))
	if img.is_compressed():
		img.decompress()
	var used := img.get_used_rect()
	var head := AtlasTexture.new()
	head.atlas = src.atlas
	var side := maxf(used.size.x, 8.0)
	head.region = Rect2(src.region.position + Vector2(used.position) + Vector2((used.size.x - side) * 0.5, -1.0), Vector2(side, side * 0.85))
	return head

# ---------- things to collect ----------

func _find_things() -> void:
	var level := get_tree().current_scene
	_things.clear()
	if level == null:
		return
	for n in level.find_children("*", "CollectableComponent", true, false):
		_things.append(n)
	# the NPCs' symbols (store, barn, school...) as big as the player's head too
	for n in level.find_children("Symbol", "Node2D", true, false):
		if n.get_script() and n.get_script().resource_path.ends_with("npc_symbol.gd"):
			_things.append(n)

func _icon_texture(n: Node) -> Texture2D:
	if "icon" in n and n.icon:
		return n.icon
	for c in n.get_children():
		if c is Sprite2D and c.texture and c.visible and c.name != "Shadow":
			return c.texture
		if c is AnimatedSprite2D and c.sprite_frames and c.visible:
			return c.sprite_frames.get_frame_texture(c.animation, 0)
	return null

## Big icons over the maps for everything still to collect (not yet picked or tamed).
func _place_icons(layer: Control, cam: Camera2D, which: int, need_explored: bool) -> void:
	var seen := {}
	var center := cam.get_screen_center_position()
	var size := BIG_ICON if which == 1 else SMALL_ICON
	for n in _things:
		if not is_instance_valid(n) or not n.is_visible_in_tree() or n.get("is_collecting") or n.get("tamed"):
			continue
		if need_explored and not _is_explored(n.global_position):
			continue
		var p: Vector2 = (n.global_position - center) * cam.zoom + layer.size * 0.5
		if p.x < -size or p.y < -size or p.x > layer.size.x + size or p.y > layer.size.y + size:
			continue
		seen[n] = true
		if not _icons.has(n):
			_icons[n] = [null, null]
		var icon: Control = _icons[n][which]
		if icon == null or not is_instance_valid(icon):
			icon = _make_badge(n, size)
			layer.add_child(icon)
			_icons[n][which] = icon
		icon.visible = true
		icon.position = p - icon.size * 0.5 + Vector2(0, -size * 0.3)
		icon.scale = (big_dot if which == 1 else small_dot).scale      # zooms with the player's dot
	for n in _icons.keys():
		var icon = _icons[n][which]
		if icon and is_instance_valid(icon) and not seen.has(n):
			icon.visible = false
		if not is_instance_valid(n):
			for i in _icons[n]:
				if i and is_instance_valid(i):
					i.queue_free()
			_icons.erase(n)

## A round badge with an outline, like the player's dot, with the picture inside.
func _make_badge(n: Node, size: float) -> Control:
	var badge := Panel.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size = Vector2(size, size)
	badge.pivot_offset = badge.size * 0.5
	var style := (small_dot.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.border_color = NPC_RING if n.get_script() and n.get_script().resource_path.ends_with("npc_symbol.gd") else THING_RING
	badge.add_theme_stylebox_override("panel", style)
	var pic := TextureRect.new()
	pic.texture = _icon_texture(n)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 4.0
	pic.offset_top = 4.0
	pic.offset_right = -4.0
	pic.offset_bottom = -4.0
	badge.add_child(pic)
	return badge

# ---------- the big map ----------

func open_big() -> void:
	if not bounds.has_area():
		bounds = _level_bounds(get_tree().current_scene)
	big.visible = true
	big_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await get_tree().process_frame
	var size := big_view.size
	var z: float = minf(size.x / maxf(bounds.size.x, 1.0), size.y / maxf(bounds.size.y, 1.0))
	big_cam.zoom = Vector2(z, z)
	big_cam.global_position = bounds.get_center()
	big_cam.reset_smoothing()
	get_tree().paused = true
	AudioManager.play_sfx("pop")
	# what the big map shows (world), for the dark over unexplored places
	var mat := fog.material as ShaderMaterial
	var shown := size / big_cam.zoom
	var c := bounds.get_center()
	mat.set_shader_parameter("view_rect", Vector4(c.x - shown.x * 0.5, c.y - shown.y * 0.5, shown.x, shown.y))
	if _explored_tex:
		_explored_tex.update(_explored)
	# the still picture under the dark: taken once, the first time the map is opened
	if _snapshot == null:
		big.modulate.a = 0.0          # don't show the whole level while taking it
		fog.visible = false
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		_snapshot = ImageTexture.create_from_image(big_vp.get_texture().get_image())
		mat.set_shader_parameter("snapshot", _snapshot)
	fog.visible = _explored != null
	big.modulate.a = 1.0


func close_big() -> void:
	big.visible = false
	big_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	get_tree().paused = false


## The level's size: all its tile layers together (or the camera limits if it has none).
func _level_bounds(level: Node) -> Rect2:
	var rect := Rect2()
	var first := true
	if level:
		for l in level.find_children("*", "TileMapLayer", true, false):
			var r: Rect2i = l.get_used_rect()
			if r.size == Vector2i.ZERO or l.tile_set == null:
				continue
			var ts := Vector2(l.tile_set.tile_size)
			var gr := Rect2(l.to_global(l.map_to_local(r.position) - ts * 0.5), Vector2(r.size) * ts * l.global_scale)
			rect = gr if first else rect.merge(gr)
			first = false
	if first and player and player.get("camera"):
		var c: Camera2D = player.camera
		if c.limit_right - c.limit_left < 100000:
			rect = Rect2(c.limit_left, c.limit_top, c.limit_right - c.limit_left, c.limit_bottom - c.limit_top)
	return rect
