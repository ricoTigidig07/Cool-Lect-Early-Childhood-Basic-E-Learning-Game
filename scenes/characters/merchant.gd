extends StaticBody2D

## What Momo asks for in this level. Set this on the Merchant in each level's Inspector.
## e.g. {"banana": 5}  or  {"coconut": 4, "banana": 3}
@export var quest_items: Dictionary = {"apple": 5}
## Optional: your own story line for this level. Leave empty to use the story for the fruit.
@export_multiline var custom_story: String = ""

## Plural names used in the dialogue. Add a line here when you add a new fruit.
const PLURALS := {
	"apple": "apples", "banana": "bananas", "orange": "oranges", "grapes": "grapes",
	"strawberry": "strawberries", "mango": "mangoes", "cherry": "cherries",
	"pineapple": "pineapples", "watermelon": "watermelons", "papaya": "papayas",
	"coconut": "coconuts", "guava": "guavas", "avocado": "avocados",
	"rambutan": "rambutans", "durian": "durians", "lemon": "lemons",
	"lychee": "lychees", "starfruit": "starfruits",
}

## Momo's story for each level, picked by the first fruit he asks for.
const STORIES := {
	"apple": "A storm knocked my apples all over the field!",
	"banana": "Silly monkeys left my bananas everywhere!",
	"orange": "My cart tipped over and the oranges rolled away!",
	"grapes": "Silly birds dropped my grapes all around!",
	"strawberry": "I'm baking a big strawberry cake!",
	"mango": "The wind shook my mangoes off the trees!",
	"cherry": "Every ice cream needs a cherry on top!",
	"pineapple": "The farmers left pineapples all over the islands!",
	"watermelon": "It's so hot! Everyone wants a juicy watermelon.",
	"papaya": "A big wave washed my papayas onto the land!",
	"coconut": "I'm making a fruit salad for the village!",
	"guava": "It's time to make fresh fruit juice!",
	"avocado": "I'm packing a picnic for the village kids!",
	"rambutan": "Visitors are coming to my shop today!",
	"durian": "Today is the big Fruit Festival!",
}

## Which voice reads this NPC's lines (folder in assets/audio/voice/).
var voice_id := "merchant"
## Name shown on the dialogue box.
var display_name := "Momo"

@onready var interaction_area: Area2D = $InteractionArea

var is_dialogue_open = false
var quest_ready_to_deliver = false

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	QuestManager.quest_completed.connect(_on_collection_complete)

# ---------- dialogue, built from quest_items ----------

func _plural(fruit: String) -> String:
	return PLURALS.get(fruit, fruit + "s")

## "5 bananas"  or  "4 coconuts and 3 bananas"
func _wanted_text() -> String:
	var parts: Array[String] = []
	for fruit in quest_items.keys():
		parts.append("%d %s" % [quest_items[fruit], _plural(fruit)])
	if parts.size() == 1:
		return parts[0]
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[-1]

func _total() -> int:
	var total := 0
	for fruit in quest_items.keys():
		total += int(quest_items[fruit])
	return total

func _intro_lines() -> Array[String]:
	var first_fruit: String = quest_items.keys()[0]
	var story: String = custom_story if custom_story != "" else STORIES.get(first_fruit, "I need your help today!")
	var lines: Array[String] = []
	if GameManager.current_level <= 1:
		lines.append("Hi! I'm Momo, the fruit merchant.")
	else:
		lines.append("Hi again! It's me, Momo!")
	lines.append(story)
	lines.append("Please bring me %s!" % _wanted_text())
	if get_parent().has_node("WrongFruits"):
		lines.append("Only pick the fruits I asked for!")
	return lines

func _incomplete_lines() -> Array[String]:
	var what: String = _plural(quest_items.keys()[0]) if quest_items.size() == 1 else "fruits"
	return ["I still need more %s!" % what, "Will you keep looking?"]

func _delivery_lines() -> Array[String]:
	var lines: Array[String] = []
	if quest_items.size() == 1:
		var fruit: String = quest_items.keys()[0]
		var count: int = quest_items[fruit]
		var numbers: Array[String] = []
		for i in range(1, count + 1):
			numbers.append(str(i))
		lines.append("Yay! You found all %d %s!" % [count, _plural(fruit)])
		lines.append("Let's count: %s!" % ", ".join(numbers))
	else:
		lines.append("Yay! You found %s!" % _wanted_text())
		lines.append("That's %d fruits in all!" % _total())
	lines.append("Thank you, great helper!")
	return lines

## Every line Momo can say in this level (used to make the voice clips).
func voice_lines() -> Array[String]:
	return _intro_lines() + _incomplete_lines() + _delivery_lines()

# ---------- player near / far ----------

func _on_body_entered(body: Node2D) -> void:
	if body is Player01:
		InteractionManager.register(self)
		var portrait = get_tree().get_first_node_in_group("avatar_icon")
		if portrait:
			portrait.set_near_merchant(true)
			portrait.play("merchant_defaults")

func _on_body_exited(body: Node2D) -> void:
	if GameUIManager.talking:
		return            # the player is walking over to talk (close-up), not leaving
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
	elif quest_ready_to_deliver:
		if portrait:
			portrait.play("merchant_talking")
		GameUIManager.show_dialogue(_delivery_lines())
		GameUIManager.connect_dialogue_finished(_on_delivery_dialogue_finished)
		is_dialogue_open = true
	elif QuestManager.active:
		if portrait:
			portrait.play("merchant_talking")
		GameUIManager.show_dialogue(_incomplete_lines())
		GameUIManager.connect_dialogue_finished(_on_incomplete_dialogue_finished)
		is_dialogue_open = true
	else:
		if portrait:
			portrait.play("merchant_talking")
		GameUIManager.complete_mission_1()
		GameUIManager.show_dialogue(_intro_lines())
		GameUIManager.connect_dialogue_finished(_on_dialogue_finished)
		is_dialogue_open = true

func _on_dialogue_finished() -> void:
	GameUIManager.show_choices(["Yes, I am happy to help!", "No, but maybe next time!"])
	GameUIManager.connect_choice_selected(_on_choice_selected)

func _on_choice_selected(choice_text: String) -> void:
	var portrait = get_tree().get_first_node_in_group("avatar_icon")
	if choice_text.begins_with("Yes"):
		QuestManager.start_quest(quest_items)
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
		GameUIManager.end_level()
		await get_tree().create_timer(0.6).timeout
		GameUIManager.show_mission_complete()
