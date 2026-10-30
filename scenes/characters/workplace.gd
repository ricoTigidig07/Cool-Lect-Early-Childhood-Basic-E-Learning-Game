extends Node2D

## The NPC's workplace (shop, chalkboard, coop...), drawn behind them.
## Each Sprite2D child is one piece. Metadata on a piece:
##   solid = true : its bottom part must stand on free ground (not in a wall, tree or water)
##   main  = true : the piece that stays if there is only room for one
## Levels are all different, so when the level starts this picks the first layout that
## fits: as drawn or mirrored (left <-> right), then moved a little, then only the main piece.
## A layout fits when it doesn't stand in a wall/tree/water and doesn't cover an item,
## basket, board, easel, door or helper. If nothing fits, the workplace is hidden.
## It is only decoration: it never blocks the player, so no path in a level can be closed.

const FOOT_HEIGHT := 6.0
## small moves tried when the drawn spot is taken (a little further back / to the side)
const SHIFTS := [Vector2(0, 0), Vector2(0, -8), Vector2(10, 0), Vector2(-10, 0), Vector2(10, -8), Vector2(-10, -8), Vector2(0, -16), Vector2(20, 0), Vector2(-20, 0), Vector2(20, -8), Vector2(-20, -8)]
const KEEP_CLEAR := ["count_basket.gd", "letter_frame.gd", "shape_board.gd", "easel.gd", "mixing_pot.gd", "door.gd"]

var pieces: Array[Sprite2D] = []
var drawn_at := {}
var chosen := ""     # which layout was picked (for checking)

func _ready() -> void:
	for c in get_children():
		if c is Sprite2D:
			pieces.append(c)
			drawn_at[c] = c.position
	visible = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	for only_main in [false, true]:
		for shift in SHIFTS:
			for mirror in [false, true]:
				if _fits(mirror, only_main, shift):
					_use(mirror, only_main, shift)
					chosen = "%s%s%s" % ["mirrored" if mirror else "as drawn", ", main piece only" if only_main else "",
						"" if shift == Vector2.ZERO else ", moved %s" % shift]
					return
	chosen = "hidden (no room)"

func _used(only_main: bool) -> Array[Sprite2D]:
	if not only_main:
		return pieces
	var out: Array[Sprite2D] = []
	for p in pieces:
		if p.get_meta("main", false):
			out.append(p)
	return out

func _local_pos(p: Sprite2D, mirror: bool, shift: Vector2) -> Vector2:
	var pos: Vector2 = drawn_at[p]
	if mirror:
		pos.x = -(pos.x + p.texture.get_size().x)
	return pos + Vector2(-shift.x if mirror else shift.x, shift.y)

func _footprint(p: Sprite2D, pos: Vector2) -> Rect2:
	var size := p.texture.get_size()
	return Rect2(pos.x + 1, pos.y + size.y - FOOT_HEIGHT - 1, size.x - 2, FOOT_HEIGHT)

func _fits(mirror: bool, only_main: bool, shift: Vector2) -> bool:
	var used := _used(only_main)
	if used.is_empty():
		return false
	var level := get_tree().current_scene
	var space := get_world_2d().direct_space_state
	var exclude: Array[RID] = []
	if owner is CollisionObject2D:
		exclude.append(owner.get_rid())
	var player = level.get_node_or_null("Player") if level else null
	if player:
		exclude.append(player.get_rid())
	var keep_clear: Array = []
	if level:
		for n in level.find_children("*", "", true, false):
			if owner and (n == owner or owner.is_ancestor_of(n)):
				continue
			var s = n.get_script()
			if n is CollectableComponent or n is HelperNPC or (s and s.resource_path.get_file() in KEEP_CLEAR):
				keep_clear.append(n)
	for p in used:
		var pos := _local_pos(p, mirror, shift)
		var picture := Rect2(global_position + pos, p.texture.get_size())
		for n in keep_clear:
			if picture.grow(4).has_point(n.global_position):
				return false
			if not (n is CollectableComponent) and picture.intersects(_visual_rect(n)):
				return false
		if p.get_meta("solid", false):
			var foot := _footprint(p, pos)
			var shape := RectangleShape2D.new()
			shape.size = foot.size
			var q := PhysicsShapeQueryParameters2D.new()
			q.shape = shape
			q.transform = Transform2D(0, global_position + foot.get_center())
			q.exclude = exclude
			if not space.intersect_shape(q, 1).is_empty():
				return false
	return true

## The area a station / helper / door covers on screen (all its pictures together).
var _rect_cache := {}
func _visual_rect(n: Node) -> Rect2:
	if _rect_cache.has(n):
		return _rect_cache[n]
	var r := Rect2(n.global_position - Vector2(6, 6), Vector2(12, 12))
	for c in n.find_children("*", "", true, false):
		if c is CanvasItem and not c.is_visible_in_tree():
			continue
		if c is Sprite2D and c.texture:
			var t: Transform2D = c.get_global_transform()
			var local: Rect2 = c.get_rect()
			r = r.merge(Rect2(t * local.position, local.size * t.get_scale().abs()))
		elif c is Control and not (c is Label):
			r = r.merge(c.get_global_rect())
	_rect_cache[n] = r
	return r

func _use(mirror: bool, only_main: bool, shift: Vector2) -> void:
	var used := _used(only_main)
	for p in pieces:
		p.visible = p in used
		p.position = _local_pos(p, mirror, shift)
	visible = true
