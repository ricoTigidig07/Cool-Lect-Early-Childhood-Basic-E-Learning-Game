class_name TileBatcher
extends RefCounted

## Faster drawing on phones.
## A TileMapLayer that mixes tiles from different pictures (e.g. "Hills.png" and
## "Grass_Hill_Tiles_v2.png" in the same layer) has to switch pictures again and again
## while drawing, and every switch is a separate draw call (up to 700 per frame in
## some Shapes levels). This moves the tiles of each extra picture into its own small
## layer, drawn right after the original one, so each picture is drawn in one go.
## The level looks exactly the same; collisions stay the same.
## Called once when a level starts (level_missions.gd). Nothing is changed in the scene files.

const COPY_PROPS := [
	"tile_set", "collision_enabled", "use_kinematic_bodies", "collision_visibility_mode",
	"navigation_enabled", "navigation_visibility_mode", "rendering_quadrant_size",
	"texture_filter", "texture_repeat", "material", "use_parent_material",
	"light_mask", "visibility_layer", "self_modulate", "occlusion_enabled",
	"x_draw_order_reversed",
]

static func optimize(root: Node) -> void:
	for layer in root.find_children("*", "TileMapLayer", true, false):
		_split(layer)

static func _split(layer: TileMapLayer) -> void:
	if layer.y_sort_enabled or layer.tile_set == null:
		return              # y-sorted layers draw tile by tile anyway: leave them as they are
	var by_source := {}
	for cell in layer.get_used_cells():
		var id := layer.get_cell_source_id(cell)
		if not (layer.tile_set.get_source(id) is TileSetAtlasSource):
			return          # layers with scene tiles (trees, bushes...) stay untouched
		if not by_source.has(id):
			by_source[id] = []
		by_source[id].append(cell)
	if by_source.size() < 2:
		return
	# the picture used most stays in the original layer
	var keep: int = by_source.keys()[0]
	for id in by_source:
		if by_source[id].size() > by_source[keep].size():
			keep = id
	var index := 0
	for id in by_source:
		if id == keep:
			continue
		var part := TileMapLayer.new()
		part.name = "%s_part%d" % [layer.name, id]
		for p in COPY_PROPS:
			part.set(p, layer.get(p))
		for cell in by_source[id]:
			part.set_cell(cell, id, layer.get_cell_atlas_coords(cell), layer.get_cell_alternative_tile(cell))
			layer.erase_cell(cell)
		layer.add_child(part)
		layer.move_child(part, index)   # before the layer's own child layers: same drawing order
		index += 1
