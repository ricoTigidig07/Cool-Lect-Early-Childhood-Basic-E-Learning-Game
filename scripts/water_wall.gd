class_name WaterWall
extends RefCounted

## Keeps the player out of the sea.
## The coast tiles have thin collision lines, but in a few places (under a tree, at a
## corner) the line has a small gap and the player could slip out onto the water.
## This puts one invisible wall over every water tile that has no land, bridge or path
## on it. Lily pads and rocks in the water don't count as land.
## Called once when a level starts (level_missions.gd). Nothing is changed in the scene files.

const TILE := 16.0

static func apply(level: Node2D) -> void:
	var water_layers: Array[TileMapLayer] = []
	var land_layers: Array[TileMapLayer] = []
	for l: TileMapLayer in level.find_children("*", "TileMapLayer", true, false):
		if l.tile_set == null:
			continue
		if String(l.name).to_lower().contains("water"):
			water_layers.append(l)
		else:
			land_layers.append(l)
	# every water tile, in world tile coordinates
	var water := {}
	for l in water_layers:
		if not String(l.name).to_lower().begins_with("water") or String(l.name).to_lower().contains("object") \
				or String(l.name).to_lower().contains("detail"):
			continue          # lily pads, rocks... are on top of water tiles anyway
		for c in l.get_used_cells():
			var p := l.to_global(l.map_to_local(c))
			water[Vector2i(floori(p.x / TILE), floori(p.y / TILE))] = true
	# remove the ones with land, a bridge, a path... on them
	for l in land_layers:
		for c in l.get_used_cells():
			var src := l.tile_set.get_source(l.get_cell_source_id(c))
			if src is TileSetAtlasSource and src.texture and src.texture.resource_path.get_file().to_lower().begins_with("water"):
				continue      # lily pads / water plants drawn in a land layer
			var p := l.to_global(l.map_to_local(c))
			water.erase(Vector2i(floori(p.x / TILE), floori(p.y / TILE)))
	if water.is_empty():
		return
	var body := StaticBody2D.new()
	body.name = "WaterWall"
	level.add_child(body)
	# one long rectangle per row of water tiles (fewer shapes = faster)
	var rows := {}
	for c: Vector2i in water:
		if not rows.has(c.y):
			rows[c.y] = []
		rows[c.y].append(c.x)
	for y in rows:
		var xs: Array = rows[y]
		xs.sort()
		var start: int = xs[0]
		var last: int = xs[0]
		for i in range(1, xs.size() + 1):
			if i < xs.size() and xs[i] == last + 1:
				last = xs[i]
				continue
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2((last - start + 1) * TILE, TILE)
			shape.shape = rect
			shape.position = Vector2((start + last + 1) * TILE / 2.0, y * TILE + TILE / 2.0)
			body.add_child(shape)
			if i < xs.size():
				start = xs[i]
				last = xs[i]
