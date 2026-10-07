extends Control

## Island level map. All visuals are nodes in level_map.tscn (move islands, rocks, boats
## in the editor). Animations: AnimationPlayer (intro), WaterAnimation, BoatAnimation.
## This script only: reads progress, scrolls the map, and opens a level when tapped.

@export_enum("fruits", "numbers", "alphabets", "animals", "shapes", "colors") var subject := "fruits"
@export var title := "FRUITS"
## Width of the whole map in pixels (used to stop scrolling at the last island).
@export var map_width := 3960.0

## Scene to open for each level. Missing ones show "Coming soon!".
const LEVEL_SCENES := {
	"fruits": {
		1: "res://scenes/levels/fruits/Lvl1Apple/Lvl1AppleMap.tscn",
		2: "res://scenes/levels/fruits/Lvl2Banana/Lvl2BananaMap.tscn",
		3: "res://scenes/levels/fruits/Lvl3Orange/Lvl3OrangeMap.tscn",
		4: "res://scenes/levels/fruits/Lvl4Grapes/Lvl4GrapesMap.tscn",
		5: "res://scenes/levels/fruits/Lvl5Strawberry/Lvl5StrawberryMap.tscn",
		6: "res://scenes/levels/fruits/Lvl6Mango/Lvl6MangoMap.tscn",
		7: "res://scenes/levels/fruits/Lvl7Cherry/Lvl7CherryMap.tscn",
		8: "res://scenes/levels/fruits/Lvl8Pineapple/Lvl8PineappleMap.tscn",
		9: "res://scenes/levels/fruits/Lvl9Watermelon/Lvl9WatermelonMap.tscn",
		10: "res://scenes/levels/fruits/Lvl10Papaya/Lvl10PapayaMap.tscn",
		11: "res://scenes/levels/fruits/Lvl11Coconut/Lvl11CoconutMap.tscn",
		12: "res://scenes/levels/fruits/Lvl12Guava/Lvl12GuavaMap.tscn",
		13: "res://scenes/levels/fruits/Lvl13Avocado/Lvl13AvocadoMap.tscn",
		14: "res://scenes/levels/fruits/Lvl14Rambutan/Lvl14RambutanMap.tscn",
		15: "res://scenes/levels/fruits/Lvl15Durian/Lvl15DurianMap.tscn",
	},
	"animals": {1: "res://scenes/levels/animals/Lvl1Chicken/Animals_Tilemap.tscn"},
	"alphabets": {1: "res://scenes/levels/alphabets/alphabet_map.tscn"},
	"numbers": {1: "res://scenes/levels/numbers/number_map.tscn"},
	"shapes": {
		1: "res://scenes/levels/shapes/Lvl1House/Lvl1HouseMap.tscn",
		2: "res://scenes/levels/shapes/Lvl2Train/Lvl2TrainMap.tscn",
		3: "res://scenes/levels/shapes/Lvl3NightSky/Lvl3NightSkyMap.tscn",
		4: "res://scenes/levels/shapes/Lvl4GiftBox/Lvl4GiftBoxMap.tscn",
		5: "res://scenes/levels/shapes/Lvl5Snowman/Lvl5SnowmanMap.tscn",
		6: "res://scenes/levels/shapes/Lvl6Kite/Lvl6KiteMap.tscn",
		7: "res://scenes/levels/shapes/Lvl7Car/Lvl7CarMap.tscn",
		8: "res://scenes/levels/shapes/Lvl8Rocket/Lvl8RocketMap.tscn",
		9: "res://scenes/levels/shapes/Lvl9Castle/Lvl9CastleMap.tscn",
		10: "res://scenes/levels/shapes/Lvl10Flower/Lvl10FlowerMap.tscn",
		11: "res://scenes/levels/shapes/Lvl11Boat/Lvl11BoatMap.tscn",
		12: "res://scenes/levels/shapes/Lvl12Robot/Lvl12RobotMap.tscn",
		13: "res://scenes/levels/shapes/Lvl13IceCream/Lvl13IceCreamMap.tscn",
		14: "res://scenes/levels/shapes/Lvl14Butterfly/Lvl14ButterflyMap.tscn",
		15: "res://scenes/levels/shapes/Lvl15ShapeTown/Lvl15ShapeTownMap.tscn",
	},
}

@onready var map: Node2D = $Map
@onready var islands: Array = $Map/Islands.get_children()
@onready var toast: Label = $Toast

var pressing := false
var dragged := false
var drag_start_x := 0.0
var velocity := 0.0
var target_x := 0.0

func _ready() -> void:
	$TopBar/Title.text = title
	$TopBar/BackButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/subject_selector.tscn"))
	var current := _next_level_to_play()
	var total := 0
	for island in islands:
		island.setup(subject, island.level == current)
		island.pressed.connect(_on_level_pressed)
		total += GameManager.get_level_stars(subject, island.level)
	$TopBar/StarsPill/HBox/Stars.text = "%d / %d" % [total, islands.size() * 3]
	# start with the next level to play in the middle of the screen
	map.position.x = _clamp_x(size.x / 2.0 - islands[current - 1].position.x)
	target_x = map.position.x

func _next_level_to_play() -> int:
	var last := 1
	for island in islands:
		var lv: int = island.level
		if GameManager.is_level_unlocked(subject, lv):
			last = lv
			if GameManager.get_level_stars(subject, lv) == 0:
				return lv
	return last

# ---------- scrolling (drag, swipe, mouse wheel) ----------

func _clamp_x(x: float) -> float:
	return clampf(x, min(0.0, size.x - map_width), 0.0)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pressing = true
				dragged = false
				drag_start_x = event.position.x
				velocity = 0.0
			else:
				pressing = false
				if dragged:
					target_x = _clamp_x(map.position.x + velocity * 0.25)
					call_deferred("set", "dragged", false)  # a drag is not a tap
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]:
			target_x = _clamp_x(target_x - 250.0)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]:
			target_x = _clamp_x(target_x + 250.0)
	elif event is InputEventMouseMotion and pressing:
		if abs(event.position.x - drag_start_x) > 10.0:
			dragged = true
		if dragged:
			map.position.x = _clamp_x(map.position.x + event.relative.x)
			target_x = map.position.x
			velocity = event.velocity.x

func _process(delta: float) -> void:
	if not pressing:
		map.position.x = lerpf(map.position.x, target_x, 1.0 - exp(-10.0 * delta))

# ---------- tapping a level ----------

func _on_level_pressed(level: int) -> void:
	if dragged:
		return
	var island = islands[level - 1]
	if not island.unlocked:
		island.wiggle()
		_show_toast("Finish level %d first!" % (level - 1))
		return
	var path: String = LEVEL_SCENES.get(subject, {}).get(level, "")
	if path == "" or not ResourceLoader.exists(path):
		_show_toast("Coming soon!")
		return
	get_tree().change_scene_to_file(path)

func _show_toast(text: String) -> void:
	toast.text = text
	toast.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(1.0)
	t.tween_property(toast, "modulate:a", 0.0, 0.4)
