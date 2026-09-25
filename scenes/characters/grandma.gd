extends Area2D

## Numbers NPC. Asks the player to fill her baskets with eggs.
## Yes -> baskets unlock (Mission 1). All baskets full -> come back (Mission 3).

var is_dialogue_open = false
var quest_ready_to_deliver = false
var lesson_started = false

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

func _all_baskets_full() -> bool:
	var baskets = get_tree().get_nodes_in_group("count_baskets")
	if baskets.is_empty():
		return false
	for basket in baskets:
		if not basket.is_full:
			return false
	return true

func interact() -> void:
	var portrait = get_tree().get_first_node_in_group("avatar_icon")

	if lesson_started and _all_baskets_full():
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
			"You filled every basket with just the right number of eggs!",
			"You're such a good counter. Thank you, dear!"
		])
		GameUIManager.connect_dialogue_finished(_on_delivery_dialogue_finished)
		is_dialogue_open = true
	elif lesson_started:
		if portrait:
			portrait.play("merchant_talking")
		GameUIManager.show_dialogue([
			"Some baskets still need eggs! Look at the number on each basket.",
			"Do you want to keep going?"
		])
		GameUIManager.connect_dialogue_finished(_on_incomplete_dialogue_finished)
		is_dialogue_open = true
	else:
		if portrait:
			portrait.play("merchant_talking")
		GameUIManager.show_dialogue([
			"Oh hello, dear! My hens laid eggs all over the yard.",
			"Can you put the right number of eggs in each basket? Look at the number on the basket!"
		])
		GameUIManager.connect_dialogue_finished(_on_dialogue_finished)
		is_dialogue_open = true

func _on_dialogue_finished() -> void:
	GameUIManager.show_choices(["Yes, I'll help!", "No, maybe later."])
	GameUIManager.connect_choice_selected(_on_choice_selected)

func _on_choice_selected(choice_text: String) -> void:
	var portrait = get_tree().get_first_node_in_group("avatar_icon")
	if choice_text.begins_with("Yes"):
		lesson_started = true
		GameUIManager.complete_mission_1()
		get_tree().call_group("count_baskets", "activate")
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
