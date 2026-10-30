class_name DepthSorter
extends RefCounted

## Makes everything that stands up (trees, bushes, rocks, fences, walls, furniture,
## roofs, barns, chicken houses, NPC houses...) draw in front of or behind the player,
## NPCs and items depending on who is lower on the screen ("Y sort").
## Before, all tiles were drawn as one flat picture under the player, so the player
## walked on top of tree leaves and roofs.
##
## How it works (once, when a level starts - called from level_missions.gd):
##  - flat ground (water, grass, soil, hills, floors, carpets, bridges, paths) stays in
##    the level's tile group, drawn under everything (z_index GROUND_Z).
##  - small standing tiles (fence posts, wall pieces, flowers, furniture, trees, rocks)
##    move to y-sorted layers under a new "Standing" node. Each tile sorts at its
##    "feet": the middle of its collision shape, or near its bottom when it has none.
##  - big objects drawn with many tiles (roofs, barns, chicken houses, NPC houses) are
##    kept together and sort at their lowest row, so the player can never be half in
##    front of / half behind one. A roof sorts at the bottom of the house walls under it.
## Collisions: tiles keep their collisions. Trees, stumps and logs drawn as plain tiles
## (not as tree scenes) had none, so the player walked through them: they get a small
## block at the trunk / log. Doors of houses that have a roof are closed (the player
## would disappear under the roof).
## Nothing is changed in the scene files.

const GROUND_Z := -10
const FOOT_INSET := 2.0     # pixels above the very bottom of a tile without collision

## Layers with these names are always flat ground (their atlas tiles).
const GROUND_LAYER_WORDS := ["floor", "carpet", "detail", "water", "soil", "grass", "hill",
		"bridge", "brigde", "port", "path", "land"]
## Pictures that are flat ground.
const GROUND_TEX_WORDS := ["water", "grass", "soil", "hill", "dirt", "path", "bridge", "ground"]
## Pictures of big objects that must stay in one piece.
const OBJECT_TEX_WORDS := ["chikcen", "chicken", "barn", "house", "hut", "tray"]

enum { GROUND, TILE, OBJECT, ROOF }

const COPY_PROPS := [
	"tile_set", "collision_enabled", "use_kinematic_bodies", "collision_visibility_mode",
	"navigation_enabled", "navigation_visibility_mode", "texture_filter", "texture_repeat",
	"material", "use_parent_material", "light_mask", "visibility_layer", "modulate",
	"self_modulate", "occlusion_enabled", "x_draw_order_reversed", "rendering_quadrant_size",
]

static var _origins_done := {}     # TileSet -> true, tile feet already set

static func apply(level: Node2D) -> void:
	var group := _tile_group(level)
	if group == null:
		return
	group.z_index = GROUND_Z
	group.z_as_relative = false
	var player := level.get_node_or_null("Player")
	if player:
		player.z_index = 0          # sort with everything else instead of always on top

	var standing := Node2D.new()
	standing.name = "Standing"
	standing.y_sort_enabled = true
	level.add_child(standing)
	level.move_child(standing, group.get_index() + 1)

	var objects := {}     # grid cell -> [layer, cell]   (barns, chicken houses, NPC houses)
	var roofs := {}       # grid cell -> [layer, cell]
	var walls := {}       # grid cell -> true            (wall / door / window tiles)
	var doors := {}       # grid cell -> true            (door tiles)
	for layer: TileMapLayer in group.find_children("*", "TileMapLayer", true, false):
		if layer.tile_set == null or not layer.is_visible_in_tree():
			continue
		_add_trunk_blocks(layer.tile_set)
		_set_tile_feet(layer.tile_set)
		var ground_layer := _has_word(layer.name, GROUND_LAYER_WORDS)
		var tiles: Array[Vector2i] = []
		for cell in layer.get_used_cells():
			var kind := _kind(layer, cell, ground_layer)
			if kind == TILE:
				tiles.append(cell)
				var tex := _texture_name(layer, cell)
				if tex.contains("walls") or tex.contains("door"):
					walls[_grid(layer, cell)] = true
				if tex.contains("door"):
					doors[_grid(layer, cell)] = true
			elif kind == OBJECT:
				objects[_grid(layer, cell)] = [layer, cell]
			elif kind == ROOF:
				roofs[_grid(layer, cell)] = [layer, cell]
		if not tiles.is_empty():
			var sorted := _new_layer(layer, standing)
			sorted.name = "%s_ysort" % layer.name
			sorted.y_sort_enabled = true
			_move_cells(layer, sorted, tiles)

	for part in _parts(objects, {}, true):
		_make_piece(part, objects, standing, "Object")
	for part in _parts(roofs, walls, false):
		var holder := _make_piece(part, roofs, standing, "Roof", walls)
		for g: Vector2i in part:
			if doors.has(g):
				_block(holder, Vector2(g) * 16.0 + Vector2(8, 8))

## The level's tile group: the plain Node2D holding the TileMapLayers.
static func _tile_group(level: Node) -> Node2D:
	for child in level.get_children():
		if child is Node2D and child.get_script() == null and not child is TileMapLayer \
				and not child.find_children("*", "TileMapLayer", true, false).is_empty():
			return child
	return null

static func _has_word(text: String, words: Array) -> bool:
	text = text.to_lower()
	for w in words:
		if text.contains(w):
			return true
	return false

static func _texture_name(layer: TileMapLayer, cell: Vector2i) -> String:
	var source := layer.tile_set.get_source(layer.get_cell_source_id(cell))
	if source is TileSetAtlasSource and source.texture:
		return source.texture.resource_path.get_file().to_lower()
	return ""

static func _kind(layer: TileMapLayer, cell: Vector2i, ground_layer: bool) -> int:
	var source := layer.tile_set.get_source(layer.get_cell_source_id(cell))
	if source is TileSetScenesCollectionSource:
		return TILE                          # trees, bushes, rocks (scenes sort by their own position)
	if ground_layer:
		return GROUND
	var tex := _texture_name(layer, cell)
	if tex.contains("roof"):
		return ROOF
	if tex.contains("walls") or tex.contains("door") or tex.contains("fence"):
		return TILE
	if _has_word(tex, OBJECT_TEX_WORDS):
		return OBJECT
	if _has_word(tex, GROUND_TEX_WORDS):
		return GROUND
	return TILE

## Each tile's sort point ("feet"): middle of its collision shape, or near its bottom.
static func _set_tile_feet(tile_set: TileSet) -> void:
	if _origins_done.has(tile_set):
		return
	_origins_done[tile_set] = true
	var physics := tile_set.get_physics_layers_count() > 0
	for i in tile_set.get_source_count():
		var source := tile_set.get_source(tile_set.get_source_id(i))
		if not source is TileSetAtlasSource:
			continue
		for t in source.get_tiles_count():
			var coords: Vector2i = source.get_tile_id(t)
			var region: Rect2i = source.get_tile_texture_region(coords)
			for a in source.get_alternative_tiles_count(coords):
				var data: TileData = source.get_tile_data(coords, source.get_alternative_tile_id(coords, a))
				var feet := region.size.y / 2.0 - FOOT_INSET - data.texture_origin.y
				if physics and data.get_collision_polygons_count(0) > 0:
					var lo := INF
					var hi := -INF
					for p in data.get_collision_polygons_count(0):
						for v in data.get_collision_polygon_points(0, p):
							lo = min(lo, v.y)
							hi = max(hi, v.y)
					feet = (lo + hi) / 2.0
				data.y_sort_origin = int(round(feet))

static func _grid(layer: TileMapLayer, cell: Vector2i) -> Vector2i:
	var p := layer.to_global(layer.map_to_local(cell))
	return Vector2i(floori(p.x / 16.0), floori(p.y / 16.0))

## Groups touching cells (8 directions) into parts. Wall cells under a roof join its part
## (they only decide where the roof sorts, they are not moved).
## same_picture: two cells only belong together when they are neighbours in the tile
## picture too (so a row of hay bales or crates stays separate objects).
static func _parts(cells: Dictionary, extra: Dictionary, same_picture: bool) -> Array:
	var seen := {}
	var parts := []
	for start in cells:
		if seen.has(start):
			continue
		var part := []
		var stack := [start]
		seen[start] = true
		var x0: int = start.x
		var x1: int = start.x
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			part.append(c)
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					var n := c + Vector2i(dx, dy)
					if seen.has(n):
						continue
					if cells.has(n) and same_picture and not _same_object(cells[c], cells[n], n - c):
						continue
					if cells.has(n) or (extra.has(n) and n.x >= x0 - 1 and n.x <= x1 + 1):
						seen[n] = true
						stack.append(n)
						if cells.has(n):
							x0 = mini(x0, n.x)
							x1 = maxi(x1, n.x)
		parts.append(part)
	return parts

static func _same_object(a: Array, b: Array, step: Vector2i) -> bool:
	var la: TileMapLayer = a[0]
	var lb: TileMapLayer = b[0]
	return la == lb and la.get_cell_source_id(a[1]) == lb.get_cell_source_id(b[1]) \
			and lb.get_cell_atlas_coords(b[1]) - la.get_cell_atlas_coords(a[1]) == step

static func _make_piece(part: Array, cells: Dictionary, standing: Node2D, label: String, extra := {}) -> Node2D:
	var bottom := -INF
	var by_layer := {}
	for g: Vector2i in part:
		if cells.has(g):
			var layer: TileMapLayer = cells[g][0]
			var cell: Vector2i = cells[g][1]
			var region: Rect2i = layer.tile_set.get_source(layer.get_cell_source_id(cell)).get_tile_texture_region(layer.get_cell_atlas_coords(cell))
			bottom = max(bottom, layer.to_global(layer.map_to_local(cell)).y + region.size.y / 2.0)
			if not by_layer.has(layer):
				by_layer[layer] = []
			by_layer[layer].append(cell)
		elif extra.has(g):
			bottom = max(bottom, g.y * 16.0 + 16.0)
	var holder := Node2D.new()
	holder.name = label
	holder.global_position = Vector2(0, bottom - FOOT_INSET)
	standing.add_child(holder)
	for layer: TileMapLayer in by_layer:
		var piece := _new_layer(layer, holder)
		piece.name = "%s_%s" % [layer.name, label]
		_move_cells(layer, piece, by_layer[layer])
	return holder

## A closed door: blocks one tile.
static func _block(parent: Node2D, at: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "ClosedDoor"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	body.add_child(shape)
	parent.add_child(body)
	body.global_position = at

## Trees, stumps and logs from the tree picture without a collision get a block at
## the bottom middle (trunk / log), the same way the tree scenes have one.
static func _add_trunk_blocks(tile_set: TileSet) -> void:
	if _origins_done.has(tile_set) or tile_set.get_physics_layers_count() == 0:
		return
	for i in tile_set.get_source_count():
		var source := tile_set.get_source(tile_set.get_source_id(i))
		if not (source is TileSetAtlasSource and source.texture \
				and source.texture.resource_path.get_file().to_lower().begins_with("trees, stumps")):
			continue
		for t in source.get_tiles_count():
			var coords: Vector2i = source.get_tile_id(t)
			var size := Vector2(source.get_tile_texture_region(coords).size)
			for a in source.get_alternative_tiles_count(coords):
				var data: TileData = source.get_tile_data(coords, source.get_alternative_tile_id(coords, a))
				if data.get_collision_polygons_count(0) > 0:
					continue
				var half_w := minf(size.x * 0.3, 12.0)
				var bottom := size.y / 2.0 - 2.0
				var top := bottom - minf(size.y * 0.4, 8.0)
				data.add_collision_polygon(0)
				data.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(-half_w, top), Vector2(half_w, top), Vector2(half_w, bottom), Vector2(-half_w, bottom)]))

static func _new_layer(from: TileMapLayer, parent: Node2D) -> TileMapLayer:
	var layer := TileMapLayer.new()
	for p in COPY_PROPS:
		layer.set(p, from.get(p))
	parent.add_child(layer)
	layer.global_transform = from.global_transform
	return layer

static func _move_cells(from: TileMapLayer, to: TileMapLayer, cells: Array) -> void:
	for cell in cells:
		to.set_cell(cell, from.get_cell_source_id(cell), from.get_cell_atlas_coords(cell), from.get_cell_alternative_tile(cell))
		from.erase_cell(cell)
