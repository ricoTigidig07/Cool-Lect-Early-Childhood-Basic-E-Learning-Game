extends Area2D

var is_dialogue_open = false
var quest_ready_to_deliver = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	QuestManager.quest_completed.connect(_on_taming_complete)

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

	if is_dialogue_open:
		GameUIManager.hide_dialogue()
		if portrait:
			portrait.play("merchant_defaults")
		is_dialogue_open = false
	elif quest_ready_to_deliver:
		if portrait:
			portrait.play("merchant_talking")
		GameUIManager.show_dialogue([
			"You brought back all 5 chicks! Thank you so much for your help.",
			"Here, take this as thanks for being such a great helper!"
		])
		GameUIManager.connect_dialogue_finished(_on_delivery_dialogue_finished)
		is_dialogue_open = true
	elif QuestManager.active:
		if portrait:
			portrait.play("merchant_talking")
		GameUIManager.show_dialogue([
			"Looks like there are still some chicks out there!",
			"Do you want to keep looking for them?"
		])
		GameUIManager.connect_dialogue_finished(_on_incomplete_dialogue_finished)
		is_dialogue_open = true
	else:
		if portrait:
			portrait.play("merchant_talking")
		GameUIManager.complete_mission_1()
		GameUIManager.show_dialogue([
			"Oh no, my baby chicks got loose in the field!",
			"Here, take these seeds — they'll help you lure the chicks back."
		])
		GameUIManager.connect_dialogue_finished(_on_dialogue_finished)
		is_dialogue_open = true

func _on_dialogue_finished() -> void:
	GameUIManager.show_choices(["Yes, I'll help!", "No, but maybe next time!"])
	GameUIManager.connect_choice_selected(_on_choice_selected)

func _on_choice_selected(choice_text: String) -> void:
	var portrait = get_tree().get_first_node_in_group("avatar_icon")
	if choice_text.begins_with("Yes"):
		GameUIManager.give_hotbar_item("seed", 5)
		var chickens = get_tree().get_nodes_in_group("chickens")
		QuestManager.start_quest({"chicken": chickens.size()})
		GameUIManager.show_items_panel()
	GameUIManager.hide_dialogue()
	if portrait:
		portrait.play("merchant_defaults")
	is_dialogue_open = false

func _on_taming_complete() -> void:
	if QuestManager.current_counts.get("chicken", 0) >= QuestManager.target_counts.get("chicken", 0):
		GameUIManager.complete_mission_2()
		quest_ready_to_deliver = true

func _on_delivery_dialogue_finished() -> void:
	var portrait = get_tree().get_first_node_in_group("avatar_icon")
	GameUIManager.complete_mission_3()
	GameUIManager.hide_items_panel()
	if portrait:
		portrait.play("merchant_defaults")
	is_dialogue_open = false
	quest_ready_to_deliver = false
	await get_tree().create_timer(1.5).timeout
	GameUIManager.hide_dialogue()
	GameUIManager.show_mission_complete()

func _on_incomplete_dialogue_finished() -> void:
	GameUIManager.show_choices(["Yes, I'll keep looking!", "No, maybe later."])
	GameUIManager.connect_choice_selected(_on_incomplete_choice_selected)

func _on_incomplete_choice_selected(choice_text: String) -> void:
	var portrait = get_tree().get_first_node_in_group("avatar_icon")
	GameUIManager.hide_dialogue()
	if portrait:
		portrait.play("merchant_defaults")
	is_dialogue_open = false

	if not choice_text.begins_with("Yes"):
		GameUIManager.hide_items_panel()
		await get_tree().create_timer(0.6).timeout
		GameUIManager.show_mission_complete()
