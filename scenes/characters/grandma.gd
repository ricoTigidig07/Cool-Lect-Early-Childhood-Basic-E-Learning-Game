extends StaticBody2D

## Grandma (Numbers). Her hens laid eggs all over the yard!
## She reads the numbers on her baskets (every CountBasket in the level) and
## builds the whole conversation from them, so one script works for every level.
## Yes -> baskets unlock (Mission 1). All baskets full -> come back (Mission 3).

## Optional: a short lesson about numbers, said after the greeting.
@export_multiline var tip: String = ""

@onready var interaction_area: Area2D = $InteractionArea

var is_dialogue_open := false
var quest_ready_to_deliver := false
var lesson_started := false

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

# ---------- the baskets in this level ----------

func _baskets() -> Array:
	var out := get_tree().get_nodes_in_group("count_baskets")
	out.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	return out

func _numbers() -> Array[int]:
	var out: Array[int] = []
	for b in _baskets():
		out.append(int(b.target_count))
	return out

func _total() -> int:
	var t := 0
	for n in _numbers():
		t += n
	return t

func _join(words: Array[String]) -> String:
	if words.is_empty():
		return ""
	if words.size() == 1:
		return words[0]
	return ", ".join(words.slice(0, words.size() - 1)) + " and " + words[-1]

func _numbers_text() -> String:
	var words: Array[String] = []
	for n in _numbers():
		words.append(str(n))
	return _join(words)

## "1 + 2 + 3 = 6"
func _sum_text() -> String:
	var words: Array[String] = []
	for n in _numbers():
		words.append(str(n))
	return " + ".join(words) + " = " + str(_total())

func _all_baskets_full() -> bool:
	var baskets := _baskets()
	if baskets.is_empty():
		return false
	for basket in baskets:
		if not basket.is_full:
			return false
	return true

# ---------- what Grandma says ----------

func _intro_lines() -> Array[String]:
	var lines: Array[String] = []
	if GameManager.current_level <= 1:
		lines.append("Oh hello, dear! I'm Grandma. My hens laid eggs all over the yard!")
	else:
		lines.append("Hello again, dear! My hens laid more eggs all over the yard!")
	if tip != "":
		lines.append(tip)
	var count := _baskets().size()
	lines.append("I have %d baskets. The numbers on them are %s." % [count, _numbers_text()])
	lines.append("Pick up the eggs, then hold the button at a basket to put one egg in. Count with me: one, two, three...")
	lines.append("Put just the right number of eggs in each basket. Will you help me?")
	return lines

func _incomplete_lines() -> Array[String]:
	return [
		"Some baskets still need eggs! Look at the number on each basket.",
		"Do you want to keep going?",
	]

func _delivery_lines() -> Array[String]:
	return [
		"You filled every basket with just the right number of eggs!",
		"Let's count them all: %s eggs!" % _sum_text(),
		"You're such a good counter. Thank you, dear!",
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
	if lesson_started and _all_baskets_full():
		quest_ready_to_deliver = true
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
		GameUIManager.end_level()
		await get_tree().create_timer(0.6).timeout
		GameUIManager.show_mission_complete()
