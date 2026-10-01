extends StaticBody2D

## The Teacher builds her dialogue from the LetterSequence, so the same script
## works for every Alphabet level. Set the letters on the LetterSequence node.

@export var letter_sequence: NodePath
## Optional: your own lesson line (e.g. for the vowels level). Leave empty to use "Today we're learning the letters ...".
@export_multiline var custom_lesson: String = ""

@onready var interaction_area: Area2D = $InteractionArea

var is_dialogue_open = false
var quest_ready_to_deliver = false
var lesson_started = false

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _seq() -> Node:
	var seq = get_node_or_null(letter_sequence)
	if seq == null:
		seq = get_parent().get_node_or_null("LetterSequence")
	return seq

# ---------- dialogue, built from the letters ----------

## "A and B"  or  "A, E, I, O and U"
func _letters_text() -> String:
	var seq = _seq()
	var letters: Array[String] = []
	if seq:
		letters.assign(seq.letter_order)
	if letters.is_empty():
		return "our letters"
	if letters.size() == 1:
		return letters[0]
	return ", ".join(letters.slice(0, letters.size() - 1)) + " and " + letters[-1]

func _intro_lines() -> Array[String]:
	var seq = _seq()
	var lines: Array[String] = []
	if GameManager.current_level <= 1:
		lines.append("Hello there! I'm your teacher. Today we're going to practice our letters.")
	else:
		lines.append("Welcome back, little reader! Ready for a new lesson?")
	if custom_lesson != "":
		lines.append(custom_lesson)
	else:
		lines.append("Today we're learning the letters %s!" % _letters_text())
	var how: String = "Find the big letter and the small letter, then put them together on the letter board."
	if seq and seq.letter_order.size() > 0:
		how += " Let's start with %s!" % seq.letter_order[0]
	if get_parent().has_node("WrongLetters"):
		how += " Be careful, some letters are not part of today's lesson!"
	lines.append(how)
	lines.append("Are you ready?")
	return lines

func _incomplete_lines() -> Array[String]:
	var seq = _seq()
	var current: String = seq.current_letter() if seq else ""
	var lines: Array[String] = []
	if current != "":
		lines.append("We still need to match the letter %s! Look for the big %s and the small %s." % [current, current, current.to_lower()])
	else:
		lines.append("There are still some letters waiting to be matched!")
	lines.append("Do you want to keep going?")
	return lines

func _delivery_lines() -> Array[String]:
	var seq = _seq()
	var pairs: Array[String] = []
	var names: Array[String] = []
	if seq:
		for letter in seq.letter_order:
			pairs.append(letter + letter.to_lower())
			names.append(letter)
	return [
		"Wonderful work! You matched every letter: %s!" % ", ".join(pairs),
		"Let's say them together: %s!" % ", ".join(names),
		"You're becoming such a great reader!"
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
	var seq = _seq()
	if lesson_started and seq and seq.is_complete():
		quest_ready_to_deliver = true

	if is_dialogue_open:
		GameUIManager.hide_dialogue()
		if portrait:
			portrait.play("merchant_defaults")
		is_dialogue_open = false
	elif quest_ready_to_deliver:
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
	GameUIManager.show_choices(["Yes, I'm ready!", "No, maybe later."])
	GameUIManager.connect_choice_selected(_on_choice_selected)

func _on_choice_selected(choice_text: String) -> void:
	var portrait = get_tree().get_first_node_in_group("avatar_icon")
	if choice_text.begins_with("Yes"):
		lesson_started = true
		GameUIManager.complete_mission_1()
		var seq = _seq()
		if seq and seq.has_method("start"):
			seq.start()
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
	quest_ready_to_deliver = false
	await get_tree().create_timer(1.5).timeout
	GameUIManager.hide_dialogue()
	GameUIManager.show_mission_complete()

func _on_incomplete_dialogue_finished() -> void:
	GameUIManager.show_choices(["Yes, I'll keep going!", "No, I'll stop here."])
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
