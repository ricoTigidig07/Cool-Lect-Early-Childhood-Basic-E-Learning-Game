extends Area2D

var is_dialogue_open = false

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

	if is_dialogue_open:
		GameUIManager.hide_dialogue()
		if portrait:
			portrait.play("merchant_defaults")
		is_dialogue_open = false
	else:
		if portrait:
			portrait.play("merchant_talking")
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
		GameUIManager.set_mission_text("Collect apples for the Merchant!")
		GameUIManager.hide_dialogue()
	else:
		GameUIManager.hide_dialogue()
	if portrait:
		portrait.play("merchant_defaults")
	is_dialogue_open = false
