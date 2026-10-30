extends Node2D
class_name GuidePath

## Arrows on the ground that show the player where to go (replaces the helper villagers).
##
##  1. Mission not started: the arrows lead to the mission NPC right away.
##  2. Collecting: the arrows only come when the player hasn't found anything for
##     WAIT_TIME seconds, and lead to the closest item that is still needed.
##     Picking something up hides them again (and the wait starts over).
##  3. Everything collected: the arrows lead right away to ONE place where it is used
##     (the closest basket that still needs eggs, the letter board, the easel...) or back
##     to the mission NPC.
## The way goes around walls, trees and water (a grid of the level, made at the start).
## Settings > Guide arrows turns them off (GameManager.helper_hints).
## Added to every level by level_missions.gd.

const WAIT_TIME := 10.0       # seconds without progress before the arrows help with the next item
const CELL := 4.0             # path grid size (pixels): small enough for narrow stairs and gaps
const SPACING := 14.0         # distance between two arrows
const SPEED := 18.0           # how fast the arrows flow toward the target (pixels per second)
const START_GAP := 16.0       # no arrows right under the player
const END_GAP := 12.0         # ...or on top of the target
const ARRIVED := 26.0         # closer than this to the target: no arrows
const ARROW_SCALE := 0.55
const OPACITY := 0.55         # arrows are see-through (55%)

## The mission NPCs and the places where items are used, found by their script.
const GIVERS := ["merchant.gd", "teacher.gd", "builder.gd", "painter.gd", "grandma.gd", "farmer.gd"]
const STATIONS := ["letter_frame.gd", "shape_board.gd", "easel.gd", "count_basket.gd", "mixing_pot.gd"]

@export var arrow_texture: Texture2D

var player: Node2D
var astar := AStarGrid2D.new()
var grid_ready := false
var origin := Vector2.ZERO        # world position of cell (0, 0)
var reach := {}                   # cells the player can walk to (from where they started)

var target: Node2D = null
var kind := ""
var points := PackedVector2Array()   # the way, from the player to the target
var length := 0.0
var flow := 0.0
var shown := 0.0                  # 0 = hidden, 1 = fully visible (fades)
var last_sig := ""
var last_progress := 0.0
var think := 0.0
var last_cell := Vector2i(-99999, -99999)
var last_target_pos := Vector2.ZERO

func _ready() -> void:
	z_index = -5                  # on the ground: under the player, trees and roofs
	z_as_relative = false
	player = get_parent().get_node_or_null("Player")
	last_progress = _now()
	for i in 3:                       # workplaces and doors are set up by now
		await get_tree().physics_frame
		if not is_inside_tree():
			return                    # the level was closed already
	await _build_grid()
	if not is_inside_tree():
		return
	grid_ready = true

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# ---------- the grid ----------

func _build_grid() -> void:
	var bounds := _level_bounds()
	origin = bounds.position
	var size := Vector2i(ceili(bounds.size.x / CELL), ceili(bounds.size.y / CELL))
	astar.region = Rect2i(Vector2i.ZERO, size)
	astar.cell_size = Vector2(CELL, CELL)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	astar.fill_solid_region(astar.region, true)
	reach.clear()
	if player == null:
		return
	# walk out from the player like the player would: only the places they can reach
	# are tested (water and the sea around the islands are never looked at)
	var shape_node: CollisionShape2D = null
	for c in player.get_children():
		if c is CollisionShape2D and not c.disabled:
			shape_node = c
			break
	var space := get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	if shape_node:
		q.shape = shape_node.shape
	else:
		var body := CircleShape2D.new()
		body.radius = 4.0
		q.shape = body
	var offset: Vector2 = shape_node.position if shape_node else Vector2(0, -4)
	q.collision_mask = player.collision_mask
	q.exclude = _passable()
	var free_at := func(c: Vector2i) -> bool:
		q.transform = Transform2D(0, _to_world(c) + offset)
		return space.intersect_shape(q, 1).is_empty()
	var start := _to_cell(player.global_position)
	if not free_at.call(start):
		for r in range(1, 6):
			for d in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r)]:
				if free_at.call(start + d):
					start = start + d
					break
			if free_at.call(start):
				break
	if not astar.is_in_boundsv(start):
		return
	reach[start] = true
	astar.set_point_solid(start, false)
	var stack: Array[Vector2i] = [start]
	var done := 0
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if reach.has(n) or not astar.is_in_boundsv(n):
				continue
			done += 1
			if free_at.call(n):
				reach[n] = true
				astar.set_point_solid(n, false)
				stack.append(n)
			else:
				reach[n] = false          # tested: blocked
			if done % 3000 == 0:
				await get_tree().process_frame      # spread over a few frames (phones)
				if not is_inside_tree():
					return                          # the level was closed meanwhile
	for k in reach.keys():
		if not reach[k]:
			reach.erase(k)

## Bodies the player walks through: the player and doors (they open when you come close).
func _passable() -> Array[RID]:
	var out: Array[RID] = []
	if player is CollisionObject2D:
		out.append(player.get_rid())
	for n in get_tree().current_scene.find_children("*", "StaticBody2D", true, false):
		if n.name == "DoorBody":
			out.append(n.get_rid())
	return out

func _level_bounds() -> Rect2:
	var r := Rect2()
	var first := true
	for l: TileMapLayer in get_parent().find_children("*", "TileMapLayer", true, false):
		var used := l.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var a := l.to_global(l.map_to_local(used.position))
		var b := l.to_global(l.map_to_local(used.end))
		var lr := Rect2(a, b - a).abs()
		r = lr if first else r.merge(lr)
		first = false
	if player:
		r = r.expand(player.global_position)
	return r.grow(16)

func _to_world(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * CELL

func _to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / CELL), floori((p.y - origin.y) / CELL))

## The walkable cell closest to a point (in the reachable area when there is one).
func _free_cell_near(p: Vector2, reachable := true) -> Variant:
	var c := _to_cell(p)
	for r in range(0, 9):
		var best = null
		var best_d := INF
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var n := c + Vector2i(x, y)
				if not astar.is_in_boundsv(n) or astar.is_point_solid(n):
					continue
				if reachable and not reach.is_empty() and not reach.has(n):
					continue
				var d := _to_world(n).distance_squared_to(p)
				if d < best_d:
					best_d = d
					best = n
		if best != null:
			return best
	return null

# ---------- what to point at ----------

func _process(delta: float) -> void:
	flow = fmod(flow + SPEED * delta, SPACING)
	think -= delta
	if think <= 0.0:
		think = 0.25
		_update_target()
	var want := 1.0 if (target != null and points.size() > 1) else 0.0
	shown = move_toward(shown, want, delta * 3.0)
	queue_redraw()

func _update_target() -> void:
	var sig := _progress_signature()
	if sig != last_sig:
		last_sig = sig
		last_progress = _now()
	if not grid_ready or player == null or not _allowed():
		_set_target(null, "")
		return
	var hint := find_hint()
	var to: Node2D = hint.get("node")
	var k: String = hint.get("kind", "")
	if k == "item" and _now() - last_progress < WAIT_TIME:
		to = null                     # let the player look by themselves first
	if to and player.global_position.distance_to(to.global_position) < ARRIVED:
		to = null
	_set_target(to, k)

func _allowed() -> bool:
	if not GameManager.helper_hints or GameUIManager.level_over:
		return false
	var panel = GameUIManager.dialogue_panel
	if panel and is_instance_valid(panel) and panel.visible:
		return false
	return true

func _set_target(to: Node2D, k: String) -> void:
	var cell := _to_cell(player.global_position) if player else Vector2i.ZERO
	var moved_target := to != null and target == to and to.global_position.distance_to(last_target_pos) > CELL
	if to == target and k == kind and cell == last_cell and not moved_target:
		return
	last_target_pos = to.global_position if to else Vector2.ZERO
	target = to
	kind = k
	last_cell = cell
	if target == null:
		return
	_find_way()

func _find_way() -> void:
	var a = _free_cell_near(player.global_position)
	var b = _free_cell_near(target.global_position)
	if a == null or b == null:
		points = PackedVector2Array()
		return
	var cells := astar.get_id_path(a, b)
	if cells.is_empty():
		points = PackedVector2Array()
		return
	var raw := PackedVector2Array()
	for c in cells:
		raw.append(_to_world(c))
	raw[0] = player.global_position
	points = _smooth(raw)
	length = 0.0
	for i in range(1, points.size()):
		length += points[i - 1].distance_to(points[i])

## Straighter lines: skip corners when the straight way is free.
func _smooth(raw: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([raw[0]])
	var i := 0
	while i < raw.size() - 1:
		var j := raw.size() - 1
		while j > i + 1 and not _clear(raw[i], raw[j]):
			j -= 1
		out.append(raw[j])
		i = j
	return out

func _clear(a: Vector2, b: Vector2) -> bool:
	var steps := int(a.distance_to(b) / (CELL * 0.5)) + 1
	for s in range(steps + 1):
		var c := _to_cell(a.lerp(b, float(s) / steps))
		if not astar.is_in_boundsv(c) or astar.is_point_solid(c):
			return false
	return true

# ---------- drawing ----------

func _draw() -> void:
	if shown <= 0.0 or points.size() < 2 or arrow_texture == null:
		return
	var tex_size := arrow_texture.get_size()
	var d := START_GAP + flow
	var seg := 0
	var seg_start := 0.0
	while d < length - END_GAP:
		while seg < points.size() - 2 and d > seg_start + points[seg].distance_to(points[seg + 1]):
			seg_start += points[seg].distance_to(points[seg + 1])
			seg += 1
		var a := points[seg]
		var b := points[seg + 1]
		var seg_len := a.distance_to(b)
		var t := clampf((d - seg_start) / maxf(seg_len, 0.001), 0.0, 1.0)
		var pos := a.lerp(b, t)
		# fade in near the player and out near the end
		var fade := clampf((d - START_GAP) / 10.0, 0.0, 1.0) * clampf((length - END_GAP - d) / 10.0, 0.0, 1.0)
		draw_set_transform(pos, (b - a).angle(), Vector2.ONE * ARROW_SCALE)
		draw_texture(arrow_texture, -tex_size / 2.0, Color(1, 1, 1, OPACITY * fade * shown))
		d += SPACING
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------- reading the level (the same rules the helper villagers used) ----------

## Something changed: an item picked up, delivered, an animal tamed, a mission done...
func _progress_signature() -> String:
	var sig := str(QuestManager.current_counts) + str(QuestManager.active)
	if GameUIManager.mission_panel:
		sig += str(GameUIManager.mission_panel.completed_missions)
	var bar = GameUIManager.hotbar
	if bar and "slot_by_item" in bar:
		for k in bar.slot_by_item:
			sig += "%s%d," % [k, _held(k)]
	for n in _stations():
		if n is CountBasket:
			sig += str(n.current_count)
		elif n.has_method("is_complete"):
			sig += str(n.is_complete())
	for n in get_tree().get_nodes_in_group("farm_animals"):
		sig += "1" if n.tamed else "0"
	return sig

var _station_cache: Array = []
func _stations() -> Array:
	if _station_cache.is_empty():
		for n in get_parent().find_children("*", "", true, false):
			if STATIONS.has(_script_name(n)):
				_station_cache.append(n)
	return _station_cache

var _giver: Node2D = null
var _items: Array = []
var _scanned := false
## The mission NPC and the items, found once (looking through the whole level every
## few frames is slow on phones).
func _scan_level() -> void:
	if _scanned:
		_items = _items.filter(func(n): return is_instance_valid(n))
		return
	_scanned = true
	for n in get_parent().find_children("*", "", true, false):
		if GIVERS.has(_script_name(n)) and _giver == null:
			_giver = n
		elif n is CollectableComponent:
			_items.append(n)

## {node, kind}: kind is start / item / place / return.
func find_hint(from: Vector2 = Vector2.INF) -> Dictionary:
	var at: Vector2 = from if from != Vector2.INF else (player.global_position if player else global_position)
	_scan_level()
	var giver: Node2D = _giver
	var items: Array = _items
	if giver == null:
		return {"node": null, "kind": ""}
	if not _mission_started(giver):
		return {"node": giver, "kind": "start"}
	var stations := _stations()
	var best: Node2D = null
	var best_d := INF
	for n in items:
		if not is_instance_valid(n) or not n.is_visible_in_tree() or n.is_collecting:
			continue
		if not _still_needed(n, stations) or not _bag_has_room(n):
			continue
		var dist: float = at.distance_to(n.global_position)
		if dist < best_d:
			best_d = dist
			best = n
	if best:
		return {"node": best, "kind": "item"}
	var place := _station_to_use(stations, at)
	if place:
		return {"node": place, "kind": "place"}
	return {"node": giver, "kind": "return"}

func _script_name(n: Node) -> String:
	var s = n.get_script()
	return s.resource_path.get_file() if s else ""

func _mission_started(giver: Node) -> bool:
	if "lesson_started" in giver:
		return giver.lesson_started
	if "quest_ready_to_deliver" in giver and giver.quest_ready_to_deliver:
		return true
	return QuestManager.active

## How many of this item the player is holding in the bag.
func _held(item: String) -> int:
	var bar = GameUIManager.hotbar
	if bar == null or not ("slot_by_item" in bar) or not bar.slot_by_item.has(item):
		return 0
	return int(bar.slot_by_item[item].get_node("Label").text)

## Can this item still go in the bag? (when all 5 slots are full of other things,
## lead to where they are used first)
func _bag_has_room(n: Node) -> bool:
	var bar = GameUIManager.hotbar
	if bar == null or not (n is ShapeCollectible or n is PaintBucket or n is LetterCollectible or n.item_type == "egg"):
		return true
	return bar.slot_by_item.has(n.item_type) or bar._find_empty_slot() != null

func _still_needed(n: Node, stations: Array) -> bool:
	var type: String = n.item_type
	if n is Chicken:
		return not n.tamed
	if n is LetterCollectible:
		var seq = n.get_node_or_null(n.letter_sequence)
		return seq != null and seq.is_collectible(type) and _held(type) == 0
	if n is ShapeCollectible:
		var board = n.get_node_or_null(n.shape_board)
		if board == null or not board.needs(type):
			return false
		var empty := 0
		for hole in board.holes.get_children():
			if not hole.get_meta("filled") and board.shape_of(hole) == type:
				empty += 1
		return _held(type) < empty
	if n is PaintBucket:
		var easel = n.get_node_or_null(n.easel)
		return easel != null and easel.wants_paint(type) and _held(type) == 0
	if type == "egg":
		var missing := 0
		for b in stations:
			if b is CountBasket and not b.is_full:
				missing += b.target_count - b.current_count
		return missing > _held("egg")
	if type == "fruits":
		var fruit: String = n.collectable_name
		if not QuestManager.active or not QuestManager.target_counts.has(fruit):
			return false
		return QuestManager.current_counts.get(fruit, 0) < QuestManager.target_counts[fruit]
	return false

## The ONE place where what you're holding is used (or null).
func _station_to_use(stations: Array, at: Vector2) -> Node2D:
	var basket: Node2D = null
	for s in stations:
		match _script_name(s):
			"letter_frame.gd":
				var seq = s.get_node_or_null(s.letter_sequence)
				if seq and not seq.is_complete():
					return s
			"shape_board.gd":
				if not s.is_complete():
					return s
			"count_basket.gd":
				if not s.is_full and (basket == null or at.distance_to(s.global_position) < at.distance_to(basket.global_position)):
					basket = s
	if basket:
		return basket
	for s in stations:
		if _script_name(s) == "easel.gd" and not s.is_complete():
			for c in s.needed_colors():
				if s.needs(c) and _held(c) > 0:
					return s
			for p in stations:
				if _script_name(p) == "mixing_pot.gd":
					return p
			return s
	return null
