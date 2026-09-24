extends Area2D

var is_dialogue_open = false
var quest_ready_to_deliver = false
var lesson_started = false

@export var letter_sequence: NodePath

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

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

func interact() -> void:
	var portrait = get_tree().get_first_node_in_group("avatar_icon")

	var seq = get_node_or_null(letter_sequence)
	if seq == null:
		seq = get_tree().current_scene.get_node_or_null("LetterSequence")
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
		GameUIManager.show_dialogue([
			"Wonderful work! You matched every letter perfectly!",
			"You're becoming such a great reader!"
		])
		GameUIManager.connect_dialogue_finished(_on_delivery_dialogue_finished)
		is_dialogue_open = true
	elif lesson_started:
		if portrait:
			portrait.play("merchant_talking")
		GameUIManager.show_dialogue([
			"There are still some letters waiting to be matched!",
			"Do you want to keep going?"
		])
		GameUIManager.connect_dialogue_finished(_on_incomplete_dialogue_finished)
		is_dialogue_open = true
	else:
		if portrait:
			portrait.play("merchant_talking")
		GameUIManager.show_dialogue([
			"Hello there! Today we're going to practice our letters.",
			"Find each capital letter in order, then match it to its lowercase partner. Are you ready?"
		])
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
