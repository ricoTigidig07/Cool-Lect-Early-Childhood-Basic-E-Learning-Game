extends StaticBody2D

## Bobo the Builder. Builds his dialogue from the ShapeBoard's holes,
## so the same script works for every Shapes level.

@export var shape_board: NodePath
## What the picture is, used in the dialogue: "house", "car", "rocket" ...
@export var picture_name: String = "house"
## Optional: a short lesson about a shape, said after the greeting.
@export_multiline var tip: String = ""

## Plural names used in the dialogue.
const PLURALS := {
	"circle": "circles", "square": "squares", "triangle": "triangles",
	"rectangle": "rectangles", "star": "stars", "heart": "hearts",
	"oval": "ovals", "diamond": "diamonds",
}

@onready var interaction_area: Area2D = $InteractionArea

var is_dialogue_open = false
var lesson_started = false

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _board() -> Node:
	var board = get_node_or_null(shape_board)
	if board == null:
		board = get_parent().get_node_or_null("ShapeBoard")
	return board

# ---------- dialogue, built from the board ----------

func _is_proper_name() -> bool:
	return picture_name != "" and picture_name[0] == picture_name[0].to_upper()

## "a train", "an ice cream", "Shape Town"
func _a_picture() -> String:
	if _is_proper_name():
		return picture_name
	return ("an " if "aeiou".contains(picture_name.substr(0, 1)) else "a ") + picture_name

## "The train", "Shape Town"
func _the_picture() -> String:
	return picture_name if _is_proper_name() else "The " + picture_name

func _shape_word(shape: String, count: int) -> String:
	return "%d %s" % [count, shape if count == 1 else PLURALS.get(shape, shape + "s")]

## "1 circle, 2 squares and 1 triangle"
func _shapes_text() -> String:
	var board = _board()
	if board == null:
		return "some shapes"
	var counts: Dictionary = board.shape_counts()
	var parts: Array[String] = []
	for shape in counts.keys():
		parts.append(_shape_word(shape, counts[shape]))
	if parts.size() == 1:
		return parts[0]
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[-1]

func _intro_lines() -> Array[String]:
	var lines: Array[String] = []
	if GameManager.current_level <= 1:
		lines.append("Hi there! I'm Bobo the Builder. I build things using shapes!")
	else:
		lines.append("Hey, it's you again! Bobo the Builder here!")
	if tip != "":
		lines.append(tip)
	lines.append("I'm making %s, but the pieces got scattered everywhere! Look at my blueprint. The white outlines show the shapes I need." % _a_picture())
	var need: String = "I need %s." % _shapes_text()
	if get_parent().has_node("WrongShapes"):
		need += " Be careful, some shapes don't fit my picture!"
	lines.append(need)
	lines.append("Will you help me build it?")
	return lines

func _incomplete_lines() -> Array[String]:
	var board = _board()
	var next: String = board.next_needed_shape() if board else ""
	var lines: Array[String] = []
	if next != "":
		lines.append("My %s isn't finished yet! I still need a %s." % [picture_name, next])
	else:
		lines.append("My %s isn't finished yet!" % picture_name)
	lines.append("Do you want to keep building?")
	return lines

func _delivery_lines() -> Array[String]:
	return [
		"Wow, look at that! %s is finished!" % _the_picture(),
		"It's made of %s. Shapes are everywhere!" % _shapes_text(),
		"Thank you, you're a great builder!"
	]

# ---------- player near / far ----------

func _on_body_entered(body: Node2D) -> void:
	if body is Player01:
		InteractionManager.register(self)
		var portrait = get_tree().get_first_node_in_group("avatar_icon")
		if portrait:
			portrait.set_near_merchant(true)
			portrait.play("merchant_defaults")

func _on_body_exited(body: Node2D) -> void:
	if body is Player01:
		InteractionManager.unregister(self)
		var portrait = get_tree().get_first_node_in_group("avatar_icon")
		if portrait:
			portrait.play("defaults")
			portrait.set_near_merchant(false)
		GameUIManager.hide_dialogue()
		is_dialogue_open = false

# ---------- talking ----------

func interact() -> void:
	var portrait = get_tree().get_first_node_in_group("avatar_icon")
	var board = _board()

	if is_dialogue_open:
		GameUIManager.hide_dialogue()
		if portrait:
			portrait.play("merchant_defaults")
		is_dialogue_open = false
	elif lesson_started and board and board.is_complete():
		if portrait:
			portrait.play("merchant_talking")
		GameUIManager.show_dialogue(_delivery_lines())
		GameUIManager.connect_dialogue_finished(_on_delivery_dialogue_finished)
		is_dialogue_open = true
	elif lesson_started:
		if portrait:
			portrait.play("merchant_talking")
		GameUIManager.show_dialogue(_incomplete_lines())
		GameUIManager.connect_dialogue_finished(_on_incomplete_dialogue_finished)
		is_dialogue_open = true
	else:
		if portrait:
			portrait.play("merchant_talking")
		GameUIManager.show_dialogue(_intro_lines())
		GameUIManager.connect_dialogue_finished(_on_dialogue_finished)
		is_dialogue_open = true

func _on_dialogue_finished() -> void:
	GameUIManager.show_choices(["Yes, let's build!", "No, maybe later."])
	GameUIManager.connect_choice_selected(_on_choice_selected)

func _on_choice_selected(choice_text: String) -> void:
	var portrait = get_tree().get_first_node_in_group("avatar_icon")
	if choice_text.begins_with("Yes"):
		lesson_started = true
		GameUIManager.complete_mission_1()
		var board = _board()
		if board:
			board.start()
	GameUIManager.hide_dialogue()
	if portrait:
		portrait.play("merchant_defaults")
	is_dialogue_open = false

func _on_delivery_dialogue_finished() -> void:
	var portrait = get_tree().get_first_node_in_group("avatar_icon")
	GameUIManager.complete_mission_3()
	if portrait:
		portrait.play("merchant_defaults")
	is_dialogue_open = false
	await get_tree().create_timer(1.5).timeout
	GameUIManager.hide_dialogue()
	GameUIManager.show_mission_complete()

func _on_incomplete_dialogue_finished() -> void:
	GameUIManager.show_choices(["Yes, I'll keep building!", "No, I'll stop here."])
	GameUIManager.connect_choice_selected(_on_incomplete_choice_selected)

func _on_incomplete_choice_selected(choice_text: String) -> void:
	var portrait = get_tree().get_first_node_in_group("avatar_icon")
	GameUIManager.hide_dialogue()
	if portrait:
		portrait.play("merchant_defaults")
	is_dialogue_open = false
	if not choice_text.begins_with("Yes"):
		await get_tree().create_timer(0.6).timeout
		GameUIManager.show_mission_complete()
