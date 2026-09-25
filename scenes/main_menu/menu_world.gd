extends Node2D

## The living background of the main menu.
## Spawns animals and floating objects from every subject, plus the player
## who walks around collecting and petting them.

@export var chicken_count := 3
@export var cow_count := 2
@export var item_count := 8
## Area (in world pixels) where things can walk and float.
@export var play_area := Rect2(24, 72, 384, 152)
## Middle area kept clear for the title and buttons (items won't spawn here).
@export var keep_clear := Rect2(100, 90, 232, 76)

const LETTERS := "res://scenes/collectables/alphabets/capital_%s.tres"
const NUMBERS := "res://scenes/collectables/numbers/number_%d.tres"
const SHAPES := "res://scenes/main_menu/menu_shapes.png"
const FRUIT_ICONS := ["res://scenes/objects/icons/apple.tres", "res://scenes/objects/icons/egg.tres"]

var looks: Array[Dictionary] = []

func _ready() -> void:
	y_sort_enabled = true
	_build_looks()
	for i in item_count:
		var item := MenuFloatItem.new()
		item.world = self
		item.position = random_free_spot()
		add_child(item)
	for i in chicken_count:
		_spawn_critter(MenuCritter.Kind.CHICKEN)
	for i in cow_count:
		_spawn_critter(MenuCritter.Kind.COW)
	var player := MenuPlayer.new()
	player.position = Vector2(play_area.get_center().x, play_area.end.y - 10)
	add_child(player)

func _spawn_critter(kind: MenuCritter.Kind) -> void:
	var c := MenuCritter.new()
	c.kind = kind
	c.bounds = play_area
	c.position = random_free_spot()
	add_child(c)

func _build_looks() -> void:
	# Alphabets
	for l in ["A", "B", "C", "D", "E"]:
		_add_look(LETTERS % l, 0.4)
	# Numbers
	for n in [1, 2, 3, 4, 5]:
		_add_look(NUMBERS % n, 0.4)
	# Fruits / Animals items
	for p in FRUIT_ICONS:
		_add_look(p, 0.9)
	# Shapes & Colors
	var sheet: Texture2D = load(SHAPES)
	for i in 6:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * 16, 0, 16, 16)
		looks.append({"texture": at, "scale": 0.9})

func _add_look(path: String, s: float) -> void:
	if ResourceLoader.exists(path):
		looks.append({"texture": load(path), "scale": s})

func random_item_look() -> Dictionary:
	return looks[randi() % looks.size()]

func random_free_spot() -> Vector2:
	for attempt in 30:
		var p := Vector2(
			randf_range(play_area.position.x, play_area.end.x),
			randf_range(play_area.position.y, play_area.end.y))
		if keep_clear.has_point(p):
			continue
		var crowded := false
		for n in get_tree().get_nodes_in_group("menu_interactable"):
			if n.position.distance_to(p) < 22.0:
				crowded = true
				break
		if not crowded:
			return p
	return play_area.get_center() + Vector2(randf_range(-150, 150), 60)
