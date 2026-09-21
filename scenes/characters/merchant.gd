extends Area2D

var is_dialogue_open = false
var quest_ready_to_deliver = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	QuestManager.quest_completed.connect(_on_collection_complete)

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
			"Wow, you actually found all 5 apples! I can't thank you enough for your help.",
			"Here, this is for you — enjoy, and thanks again for being such a great helper!"
		])
		GameUIManager.connect_dialogue_finished(_on_delivery_dialogue_finished)
		is_dialogue_open = true
	elif QuestManager.active:
		if portrait:
			portrait.play("merchant_talking")
		GameUIManager.show_dialogue([
			"Hmm, looks like you haven't found all the apples yet!",
			"Do you still want to keep looking for them?"
		])
		GameUIManager.connect_dialogue_finished(_on_incomplete_dialogue_finished)
		is_dialogue_open = true
	else:
		if portrait:
			portrait.play("merchant_talking")
		GameUIManager.complete_mission_1()
		GameUIManager.show_dialogue([
			"Hi there! I'm Momo, the merchant of this little village. I trade fruits, treats, and all sorts of goodies with everyone who visits!",
			"But oh no — a storm last night knocked apples all over the field, and I can't gather them all by myself! Could you help me collect some apples?"
		])
		GameUIManager.connect_dialogue_finished(_on_dialogue_finished)
		is_dialogue_open = true

func _on_dialogue_finished() -> void:
	GameUIManager.show_choices(["Yes, I am happy to help!", "No, but maybe next time!"])
	GameUIManager.connect_choice_selected(_on_choice_selected)

func _on_choice_selected(choice_text: String) -> void:
	var portrait = get_tree().get_first_node_in_group("avatar_icon")
	if choice_text.begins_with("Yes"):
		QuestManager.start_quest({"apple": 5})
		GameUIManager.show_items_panel()
		GameUIManager.hide_dialogue()
	else:
		GameUIManager.hide_dialogue()
	if portrait:
		portrait.play("merchant_defaults")
	is_dialogue_open = false

func _on_collection_complete() -> void:
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

	if choice_text.begins_with("Yes"):
		GameUIManager.show_items_panel()
	else:
		GameUIManager.hide_items_panel()
		await get_tree().create_timer(0.6).timeout
		GameUIManager.show_mission_complete()
