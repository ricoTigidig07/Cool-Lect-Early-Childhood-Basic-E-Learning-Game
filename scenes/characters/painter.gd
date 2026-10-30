extends StaticBody2D

## Pablo the Painter. Builds his dialogue from the Easel, so the same script
## works for every Colors level.

@export var easel: NodePath
## Optional: a short lesson about colors, said after the greeting.
@export_multiline var tip: String = ""

## Which voice reads this NPC's lines (folder in assets/audio/voice/).
var voice_id := "painter"
## Name shown on the dialogue box.
var display_name := "Pablo"

@onready var interaction_area: Area2D = $InteractionArea

var is_dialogue_open = false
var lesson_started = false

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _easel() -> Node:
	var e = get_node_or_null(easel)
	if e == null:
		e = get_parent().get_node_or_null("Easel")
	return e

# ---------- dialogue, built from the easel ----------

func _join(words: Array[String]) -> String:
	if words.is_empty():
		return ""
	if words.size() == 1:
		return words[0]
	return ", ".join(words.slice(0, words.size() - 1)) + " and " + words[-1]

func _picture() -> String:
	var e = _easel()
	return e.picture_name if e else "picture"

func _a_picture() -> String:
	var p := _picture()
	if p != "" and p[0] == p[0].to_upper():
		return p
	if p.ends_with("s") and not p.ends_with("ss") and not p.contains(" "):
		return p                      # "grapes", "cherries"
	return ("an " if "aeiou".contains(p.substr(0, 1)) else "a ") + p

## "The apple should be red and the leaf should be green."
func _colors_line() -> String:
	var e = _easel()
	if e == null:
		return ""
	var colors: Array[String] = e.needed_colors()
	var bits: Array[String] = []
	for c in colors:
		if e.part_names.has(c):
			bits.append("the %s should be %s" % [e.part_names[c], c])
	if bits.size() == colors.size() and bits.size() > 0 and bits.size() <= 2:
		var line := _join(bits)
		return line.substr(0, 1).to_upper() + line.substr(1) + "."
	return "I need %s paint." % _join(colors)

## Colors the picture needs but no bucket on the map has (they must be mixed).
func _colors_to_mix() -> Array[String]:
	var e = _easel()
	var out: Array[String] = []
	var paints = get_parent().get_node_or_null("Paints")
	if e == null or paints == null:
		return out
	var on_map: Array[String] = []
	for b in paints.get_children():
		if "paint_color" in b:
			on_map.append(b.paint_color)
	for c in e.needed_colors():
		if not on_map.has(c):
			out.append(c)
	return out

func _intro_lines() -> Array[String]:
	var lines: Array[String] = []
	if GameManager.current_level <= 1:
		lines.append("Hi! I'm Pablo the Painter.")
	else:
		lines.append("Hello again! It's me, Pablo!")
	if tip != "":
		lines.append(tip)
	lines.append("I want to paint %s on my easel!" % _a_picture())
	lines.append(_colors_line())
	if get_parent().has_node("MixingPot"):
		for c in _colors_to_mix():
			var r: Array = PaintColors.RECIPES.get(c, [])
			if r.size() == 2:
				lines.append("No %s paint? Mix %s and %s in the pot!" % [c, r[0], r[1]])
	lines.append("Find the paint and bring it to my easel!")
	if get_parent().has_node("WrongPaints"):
		lines.append("Only use the colors I need!")
	lines.append("Will you help me paint it?")
	return lines

func _incomplete_lines(next := "") -> Array[String]:
	if next == "":
		var e = _easel()
		next = e.next_needed_color() if e else ""
	var lines: Array[String] = []
	if next != "":
		lines.append("I still need %s paint!" % next)
	else:
		lines.append("My %s isn't finished yet!" % _picture())
	lines.append("Will you keep painting?")
	return lines

func _delivery_lines() -> Array[String]:
	var e = _easel()
	var colors: Array[String] = e.needed_colors() if e else []
	return [
		"Wow, what a beautiful %s!" % _picture(),
		"You used %s!" % _join(colors),
		"Thank you, little artist!"
	]

## Every line Pablo can say in this level (used to make the voice clips).
func voice_lines() -> Array[String]:
	var out: Array[String] = _intro_lines() + _delivery_lines()
	var e = _easel()
	if e:
		for c in e.needed_colors():
			out.append_array(_incomplete_lines(c))
	out.append("My %s isn't finished yet!" % _picture())
	return out

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
	var e = _easel()

	if is_dialogue_open:
		GameUIManager.hide_dialogue()
		if portrait:
			portrait.play("merchant_defaults")
		is_dialogue_open = false
	elif lesson_started and e and e.is_complete():
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
	GameUIManager.show_choices(["Yes, let's paint!", "No, maybe later."])
	GameUIManager.connect_choice_selected(_on_choice_selected)

func _on_choice_selected(choice_text: String) -> void:
	var portrait = get_tree().get_first_node_in_group("avatar_icon")
	if choice_text.begins_with("Yes"):
		lesson_started = true
		GameUIManager.complete_mission_1()
		var e = _easel()
		if e:
			e.start()
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
	GameUIManager.show_choices(["Yes, I'll keep painting!", "No, I'll stop here."])
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
