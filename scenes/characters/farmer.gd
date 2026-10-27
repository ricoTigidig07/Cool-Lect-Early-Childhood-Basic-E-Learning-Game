extends StaticBody2D

## The Farmer. His animals got out! He builds the whole conversation from the
## animals in the level (every animal adds itself to the "farm_animals" group),
## so this one script works for every Animals level.
## What an animal eats comes from its required_item (seed, bread, corn ...).

## Optional: a fun fact about the animals, said after the greeting.
@export_multiline var tip: String = ""

const PLURALS := {
	"chicken": "chickens", "duck": "ducks", "cow": "cows", "pig": "pigs", "sheep": "sheep",
	"rabbit": "rabbits", "goat": "goats", "horse": "horses", "cat": "cats", "dog": "dogs",
	"turkey": "turkeys", "donkey": "donkeys", "chick": "chicks", "calf": "calves", "piglet": "piglets",
}
const FOOD_NAMES := {
	"seed": "seeds", "bread": "bread", "grass": "grass", "corn": "corn", "hay": "hay",
	"carrot": "carrots", "leaf": "leaves", "apple": "apples", "fish": "fish", "bone": "bones",
	"berry": "berries", "milk": "milk",
}

@onready var interaction_area: Area2D = $InteractionArea

var is_dialogue_open := false
var lesson_started := false
var quest_ready_to_deliver := false

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	QuestManager.quest_completed.connect(_on_taming_complete)

# ---------- the animals in this level ----------

func _animals() -> Array:
	return get_tree().get_nodes_in_group("farm_animals")

## {"duck": 3, "pig": 2} in the order they are in the scene
func _animal_counts() -> Dictionary:
	var out := {}
	for a in _animals():
		out[a.item_type] = out.get(a.item_type, 0) + 1
	return out

## {"bread": 3, "corn": 2}: one food for each animal
func _food_counts() -> Dictionary:
	var out := {}
	for a in _animals():
		out[a.required_item] = out.get(a.required_item, 0) + 1
	return out

func _food_of(animal_type: String) -> String:
	for a in _animals():
		if a.item_type == animal_type:
			return a.required_item
	return ""

func _plural(animal_type: String) -> String:
	return PLURALS.get(animal_type, animal_type + "s")

func _food_name(food: String) -> String:
	return FOOD_NAMES.get(food, food)

func _count_words(counts: Dictionary) -> String:
	var parts: Array[String] = []
	for t in counts:
		var n: int = counts[t]
		parts.append("%d %s" % [n, t if n == 1 else _plural(t)])
	return _join(parts)

func _join(words: Array[String]) -> String:
	if words.is_empty():
		return ""
	if words.size() == 1:
		return words[0]
	return ", ".join(words.slice(0, words.size() - 1)) + " and " + words[-1]

## "Ducks love bread and pigs love corn."
func _likes_line() -> String:
	var likes: Array[String] = []
	for t in _animal_counts():
		likes.append("%s love %s" % [_plural(t), _food_name(_food_of(t))])
	var line := _join(likes)
	return line.substr(0, 1).to_upper() + line.substr(1) + "."

# ---------- what the Farmer says ----------

func _intro_lines() -> Array[String]:
	var lines: Array[String] = []
	if GameManager.current_level <= 1:
		lines.append("Hello, little friend! I'm the Farmer, and this is my farm.")
	else:
		lines.append("Hello again, little friend! Welcome back to the farm!")
	if tip != "":
		lines.append(tip)
	lines.append("Oh no! My %s got out and ran all over the farm!" % _count_words(_animal_counts()))
	lines.append(_likes_line())
	lines.append("I'll give you the food. Pick the right food in your bag, then hold the button next to an animal to make friends!")
	lines.append("Will you help me bring them back?")
	return lines

func _incomplete_lines() -> Array[String]:
	var left := {}
	for t in QuestManager.target_counts:
		var n: int = QuestManager.target_counts[t] - QuestManager.current_counts.get(t, 0)
		if n > 0:
			left[t] = n
	return [
		"There are still %s out there!" % _count_words(left) if not left.is_empty() else "Some animals are still out there!",
		"Do you want to keep looking?",
	]

func _delivery_lines() -> Array[String]:
	return [
		"You found all my animals! Thank you so much!",
		"Remember: " + _likes_line(),
		"You're a great little farmer!",
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
	if is_dialogue_open:
		GameUIManager.hide_dialogue()
		if portrait:
			portrait.play("merchant_defaults")
		is_dialogue_open = false
		return
	if portrait:
		portrait.play("merchant_talking")
	if quest_ready_to_deliver:
		GameUIManager.show_dialogue(_delivery_lines())
		GameUIManager.connect_dialogue_finished(_on_delivery_dialogue_finished)
	elif lesson_started:
		GameUIManager.show_dialogue(_incomplete_lines())
		GameUIManager.connect_dialogue_finished(_on_incomplete_dialogue_finished)
	else:
		GameUIManager.show_dialogue(_intro_lines())
		GameUIManager.connect_dialogue_finished(_on_dialogue_finished)
	is_dialogue_open = true

func _on_dialogue_finished() -> void:
	GameUIManager.show_choices(["Yes, I'll help!", "No, maybe later."])
	GameUIManager.connect_choice_selected(_on_choice_selected)

func _on_choice_selected(choice_text: String) -> void:
	var portrait = get_tree().get_first_node_in_group("avatar_icon")
	if choice_text.begins_with("Yes") and not lesson_started:
		lesson_started = true
		GameUIManager.complete_mission_1()
		_register_icons()
		var foods := _food_counts()
		for food in foods:
			GameUIManager.give_hotbar_item(food, foods[food])
		QuestManager.start_quest(_animal_counts())
		GameUIManager.show_items_panel()
	GameUIManager.hide_dialogue()
	if portrait:
		portrait.play("merchant_defaults")
	is_dialogue_open = false

## Tells the hotbar and the Items panel which picture to use for each food and animal.
func _register_icons() -> void:
	for a in _animals():
		if GameUIManager.hotbar and a.food_icon and not GameUIManager.hotbar.item_icons.has(a.required_item):
			GameUIManager.hotbar.item_icons[a.required_item] = a.food_icon
		if GameUIManager.items_panel and a.icon and "item_icons" in GameUIManager.items_panel:
			GameUIManager.items_panel.item_icons[a.item_type] = a.icon

func _on_taming_complete() -> void:
	if not lesson_started or quest_ready_to_deliver:
		return
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
	GameUIManager.show_choices(["Yes, I'll keep looking!", "No, I'll stop here."])
	GameUIManager.connect_choice_selected(_on_incomplete_choice_selected)

func _on_incomplete_choice_selected(choice_text: String) -> void:
	var portrait = get_tree().get_first_node_in_group("avatar_icon")
	GameUIManager.hide_dialogue()
	if portrait:
		portrait.play("merchant_defaults")
	is_dialogue_open = false
	if not choice_text.begins_with("Yes"):
		GameUIManager.hide_items_panel()
		GameUIManager.end_level()
		await get_tree().create_timer(0.6).timeout
		GameUIManager.show_mission_complete()
