extends Control

## Subject carousel: one row of cards, the selected subject sits big in the middle.
## Swipe / drag, mouse wheel, arrow buttons or keyboard to scroll.
## Tap a side card to bring it to the middle; tap the middle card (or Let's Go!) to open it.
## The selector comes down like a window blind over the main menu's living meadow;
## the blind's colour and the floating objects change to match the selected subject.
##
## embedded = true  -> opened from the main menu on top of its meadow (no own background);
##                     Back rolls the blind up and emits `closed`.
## embedded = false -> opened as its own scene (e.g. back from a level select); shows its
##                     own copy of the meadow and Back rolls up then loads the main menu.

signal closed

@export var embedded := false

const SUBJECTS := [
	{"id": "fruits", "name": "Fruits", "icon": Rect2(8, 2, 176, 166), "color": Color(0.93, 0.42, 0.4),
		"scene": "res://scenes/levels/fruits/fruits_level_select.tscn"},
	{"id": "numbers", "name": "Numbers", "icon": Rect2(296, 0, 160, 168), "color": Color(0.42, 0.62, 0.95),
		"scene": "res://scenes/levels/numbers/numbers_level_select.tscn"},
	{"id": "alphabets", "name": "Alphabets", "icon": Rect2(576, 0, 176, 168), "color": Color(0.97, 0.62, 0.3),
		"scene": "res://scenes/levels/alphabets/alphabets_level_select.tscn"},
	{"id": "animals", "name": "Animals", "icon": Rect2(8, 160, 176, 172), "color": Color(0.93, 0.56, 0.7),
		"scene": "res://scenes/levels/animals/animals_level_select.tscn"},
	{"id": "shapes", "name": "Shapes", "icon": Rect2(296, 160, 168, 172), "color": Color(0.95, 0.78, 0.3),
		"scene": "res://scenes/levels/shapes/shapes_level_select.tscn"},
	{"id": "colors", "name": "Colors", "icon": Rect2(576, 160, 176, 172), "color": Color(0.68, 0.5, 0.9),
		"scene": "res://scenes/levels/colors/colors_level_select.tscn"},
]
const ICON_SHEET := "res://assets/UI/ui/emojis-free/subjects_icon.png"
const TITLE_FONT := "res://assets/UI/ui/fonts/pixelFont-7-8x14-sproutLands.ttf"
const LEVELS_PER_SUBJECT := 15

const CARD_SIZE := Vector2(300, 370)
const SPACING := 320.0
const DRAG_THRESHOLD := 12.0

## Remembered while the game runs, so coming back shows the last subject in the middle.
static var last_index := 0

@onready var blind: Control = $Blind
@onready var fabric: Control = $Blind/Fabric
@onready var carousel: Control = $Blind/Carousel
@onready var floaters: Control = $Blind/Floaters
@onready var dots_box: HBoxContainer = $Blind/Dots
@onready var go_button: Button = $Blind/GoButton
@onready var left_arrow: Button = $Blind/LeftArrow
@onready var right_arrow: Button = $Blind/RightArrow
@onready var back_button: Button = $Blind/BackButton

var cards: Array[Control] = []
var dots: Array[Panel] = []
var scroll := 0.0            # float index of the card in the middle
var selected := 0
var dragging := false
var drag_moved := 0.0
var drag_velocity := 0.0
var press_pos := Vector2.ZERO
var snap_tween: Tween
var float_timer := 0.0
var float_looks: Dictionary = {}

func _ready() -> void:
	selected = clampi(last_index, 0, SUBJECTS.size() - 1)
	scroll = selected
	_build_cards()
	_build_dots()
	_build_float_looks()
	carousel.gui_input.connect(_on_carousel_input)
	left_arrow.pressed.connect(func(): _go_to(selected - 1))
	right_arrow.pressed.connect(func(): _go_to(selected + 1))
	back_button.pressed.connect(_on_back)
	go_button.pressed.connect(_open_selected)
	for b in [left_arrow, right_arrow]:
		b.add_theme_constant_override("icon_max_width", 36)
	back_button.add_theme_constant_override("icon_max_width", 22)
	# Inside the main menu it sits on the menu's own meadow; on its own it shows a copy.
	if get_parent() != get_tree().root:
		embedded = true
	if embedded:
		$MenuBackground.queue_free()
	_apply_selection(true)
	_layout_cards()
	if embedded:
		visible = false        # the main menu calls open() when Play is pressed
	else:
		open()

# ---------- window-blind animation (AnimationPlayer: drop_down / roll_up) ----------

@onready var anim: AnimationPlayer = $AnimationPlayer

func is_moving() -> bool:
	return anim.is_playing()

## Show the selector: the blind drops down and bounces (animation "drop_down").
func open() -> void:
	visible = true
	anim.play("drop_down")

func _on_back() -> void:
	if is_moving():
		return
	anim.play("roll_up")
	await anim.animation_finished
	if embedded:
		visible = false
		closed.emit()
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ---------- cards ----------

func _build_cards() -> void:
	var sheet: Texture2D = load(ICON_SHEET)
	var title_font: Font = load(TITLE_FONT)
	for i in SUBJECTS.size():
		var s: Dictionary = SUBJECTS[i]
		var card := Panel.new()
		card.size = CARD_SIZE
		card.pivot_offset = CARD_SIZE / 2.0
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.97, 0.91, 0.78)
		style.set_border_width_all(6)
		style.border_width_bottom = 10
		style.border_color = Color(0.66, 0.44, 0.31)
		style.set_corner_radius_all(18)
		style.corner_detail = 4
		style.shadow_color = Color(0, 0, 0, 0.2)
		style.shadow_offset = Vector2(0, 8)
		style.shadow_size = 2
		card.add_theme_stylebox_override("panel", style)
		card.set_meta("style", style)
		# coloured header band
		var band := Panel.new()
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var band_style := StyleBoxFlat.new()
		band_style.bg_color = s.color
		band_style.corner_radius_top_left = 12
		band_style.corner_radius_top_right = 12
		band_style.corner_detail = 4
		band.add_theme_stylebox_override("panel", band_style)
		band.position = Vector2(6, 6)
		band.size = Vector2(CARD_SIZE.x - 12, 40)
		card.add_child(band)
		# icon
		var icon := TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = s.icon
		icon.texture = at
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(40, 58)
		icon.size = Vector2(CARD_SIZE.x - 80, 200)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		# name
		var name_label := Label.new()
		name_label.text = s.name.to_upper()
		name_label.add_theme_font_override("font", title_font)
		name_label.add_theme_font_size_override("font_size", 40)
		name_label.add_theme_color_override("font_color", Color(0.36, 0.22, 0.15))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.position = Vector2(0, 262)
		name_label.size = Vector2(CARD_SIZE.x, 50)
		card.add_child(name_label)
		# stars earned
		var stars := Label.new()
		stars.text = "★ %d / %d" % [_stars_for(s.id), LEVELS_PER_SUBJECT * 3]
		stars.add_theme_font_size_override("font_size", 26)
		stars.add_theme_color_override("font_color", Color(0.62, 0.42, 0.18))
		stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stars.position = Vector2(0, 312)
		stars.size = Vector2(CARD_SIZE.x, 36)
		card.add_child(stars)
		carousel.add_child(card)
		cards.append(card)

func _stars_for(subject_id: String) -> int:
	var total := 0
	if GameManager and "level_progress" in GameManager and GameManager.level_progress.has(subject_id):
		for v in GameManager.level_progress[subject_id].values():
			total += int(v)
	return total

func _build_dots() -> void:
	for i in SUBJECTS.size():
		var d := Panel.new()
		d.custom_minimum_size = Vector2(14, 14)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.WHITE
		sb.set_corner_radius_all(7)
		d.add_theme_stylebox_override("panel", sb)
		dots_box.add_child(d)
		dots.append(d)

func _layout_cards() -> void:
	var center := carousel.size / 2.0
	for i in cards.size():
		var card := cards[i]
		var d := float(i) - scroll
		var ad: float = abs(d)
		var s: float = 1.0 - 0.3 * min(ad, 1.0) - 0.15 * clampf(ad - 1.0, 0.0, 1.0)
		card.scale = Vector2.ONE * s
		card.position = Vector2(center.x + d * SPACING - CARD_SIZE.x / 2.0, center.y - CARD_SIZE.y / 2.0)
		card.modulate.a = clampf(1.0 - 0.35 * clampf(ad - 0.6, 0.0, 3.0), 0.0, 1.0)
		card.z_index = 10 - int(round(ad * 2.0))
		card.visible = ad < 3.2
		if i == selected and not dragging:
			card.position.y += sin(Time.get_ticks_msec() / 1000.0 * 2.5) * 4.0

# ---------- selection ----------

func _go_to(index: int) -> void:
	index = clampi(index, 0, SUBJECTS.size() - 1)
	if snap_tween:
		snap_tween.kill()
	snap_tween = create_tween()
	snap_tween.tween_property(self, "scroll", float(index), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if index != selected:
		selected = index
		_apply_selection(false)

func _apply_selection(instant: bool) -> void:
	last_index = selected
	var color: Color = SUBJECTS[selected].color
	if instant:
		fabric.tint = color
	else:
		create_tween().tween_property(fabric, "tint", color, 0.35)
	go_button.text = "Let's Go!"
	for i in cards.size():
		var st: StyleBoxFlat = cards[i].get_meta("style")
		st.border_color = SUBJECTS[i].color.darkened(0.25) if i == selected else Color(0.66, 0.44, 0.31)
	for i in dots.size():
		dots[i].self_modulate = color.darkened(0.2) if i == selected else Color(1, 1, 1, 0.7)
		dots[i].custom_minimum_size = Vector2(22, 14) if i == selected else Vector2(14, 14)
	left_arrow.disabled = selected == 0
	right_arrow.disabled = selected == SUBJECTS.size() - 1

func _open_selected() -> void:
	if is_moving():
		return
	var card := cards[selected]
	var t := create_tween()
	t.tween_property(card, "scale", Vector2.ONE * 1.12, 0.1)
	t.tween_property(card, "scale", Vector2.ONE, 0.1)
	await t.finished
	get_tree().change_scene_to_file(SUBJECTS[selected].scene)

# ---------- input ----------

func _on_carousel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_moved = 0.0
			drag_velocity = 0.0
			press_pos = event.position
			if snap_tween:
				snap_tween.kill()
		elif dragging:
			dragging = false
			if drag_moved < DRAG_THRESHOLD:
				_on_tap(event.global_position)
			else:
				_go_to(int(round(scroll + drag_velocity * 0.12)))
	elif event is InputEventMouseMotion and dragging:
		var dx: float = event.relative.x
		drag_moved += abs(dx)
		var delta_scroll := -dx / SPACING
		# rubber-band past the first / last card
		if (scroll <= 0.0 and delta_scroll < 0.0) or (scroll >= SUBJECTS.size() - 1 and delta_scroll > 0.0):
			delta_scroll *= 0.35
		scroll += delta_scroll
		drag_velocity = lerp(drag_velocity, -event.velocity.x / SPACING, 0.5)
		var nearest := clampi(int(round(scroll)), 0, SUBJECTS.size() - 1)
		if nearest != selected:
			selected = nearest
			_apply_selection(false)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			_go_to(selected + 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_LEFT:
			_go_to(selected - 1)

func _on_tap(global_pos: Vector2) -> void:
	# check front-most cards first
	var order := range(cards.size())
	order.sort_custom(func(a, b): return cards[a].z_index > cards[b].z_index)
	for i in order:
		if cards[i].visible and cards[i].get_global_rect().has_point(global_pos):
			if i == selected:
				_open_selected()
			else:
				_go_to(i)
			return
	_go_to(selected)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or is_moving():
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back()
	elif event.is_action_pressed("ui_right"):
		_go_to(selected + 1)
	elif event.is_action_pressed("ui_left"):
		_go_to(selected - 1)
	elif event.is_action_pressed("ui_accept"):
		_open_selected()

# ---------- floating objects that match the selected subject ----------

func _build_float_looks() -> void:
	var trees: Texture2D = load("res://assets/sprites/game/Sprout Lands - Sprites - premium pack/Objects/Trees, stumps and bushes.png")
	var shapes: Texture2D = load("res://scenes/main_menu/menu_shapes.png") if ResourceLoader.exists("res://scenes/main_menu/menu_shapes.png") else null
	var fruits: Array = []
	for x in [16, 32, 48, 64, 80, 96, 112]:
		fruits.append(_atlas(trees, Rect2(x, 32, 16, 16)))
	var numbers: Array = []
	for n in range(1, 11):
		var p := "res://scenes/collectables/numbers/number_%d.tres" % n
		if ResourceLoader.exists(p):
			numbers.append(load(p))
	var letters: Array = []
	for l in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
		var p := "res://scenes/collectables/alphabets/capital_%s.tres" % l
		if ResourceLoader.exists(p):
			letters.append(load(p))
	var animals: Array = []
	for p in ["res://scenes/objects/icons/chicken.tres", "res://scenes/objects/icons/egg.tres"]:
		if ResourceLoader.exists(p):
			animals.append(load(p))
	var cow: Texture2D = load("res://assets/sprites/game/Sprout Lands - Sprites - premium pack/Animals/Cow/Light cow animations.png")
	animals.append(_atlas(cow, Rect2(0, 0, 32, 32)))
	var shape_list: Array = []
	var circles: Array = []
	if shapes:
		for i in 6:
			shape_list.append(_atlas(shapes, Rect2(i * 16, 0, 16, 16)))
		circles.append(_atlas(shapes, Rect2(0, 0, 16, 16)))
	float_looks = {"fruits": fruits, "numbers": numbers, "alphabets": letters,
		"animals": animals, "shapes": shape_list, "colors": circles}

func _atlas(tex: Texture2D, r: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = r
	return a

func _spawn_floater() -> void:
	var id: String = SUBJECTS[selected].id
	var list: Array = float_looks.get(id, [])
	if list.is_empty():
		return
	var tex: Texture2D = list[randi() % list.size()]
	var r := TextureRect.new()
	r.texture = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var sz := randf_range(44, 72)
	r.size = Vector2(sz, sz)
	r.pivot_offset = r.size / 2.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = Vector2(randf_range(0, size.x - sz), size.y + 10)
	if id == "colors":
		r.self_modulate = Color.from_hsv(randf(), 0.65, 1.0)
	r.modulate.a = 0.0
	r.set_meta("speed", randf_range(40, 80))
	r.set_meta("sway", randf() * TAU)
	floaters.add_child(r)
	create_tween().tween_property(r, "modulate:a", 0.85, 0.6)

func _process(delta: float) -> void:
	_layout_cards()
	float_timer -= delta
	if float_timer <= 0.0:
		float_timer = randf_range(0.35, 0.7)
		_spawn_floater()
	var t := Time.get_ticks_msec() / 1000.0
	for f in floaters.get_children():
		f.position.y -= f.get_meta("speed") * delta
		f.position.x += sin(t * 1.5 + f.get_meta("sway")) * 20.0 * delta
		f.rotation = sin(t * 2.0 + f.get_meta("sway")) * 0.2
		if f.position.y < -90:
			f.queue_free()
