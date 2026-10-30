extends Node2D

## The NPC's symbol on a little wooden sign above their head (store for Momo, barn for
## Farmer Kiko, school for Teacher Abby, nest for Lola Nena, hammer for Bob, palette for Pablo).
## Only the mission NPCs have it (it is in their scenes, not in the helper villagers').
## The same picture is shown next to "Talk to ..." and "Go back to ..." in the missions.

@export var icon: Texture2D:
	set(value):
		icon = value
		if is_node_ready():
			$Bob/Icon.texture = value

func _ready() -> void:
	$Bob/Icon.texture = icon
	$AnimationPlayer.play("bob")
	# the missions panel is made by the level's UI, wait until it is there
	await get_tree().process_frame
	if GameUIManager.mission_panel and GameUIManager.mission_panel.has_method("set_npc_symbol"):
		GameUIManager.mission_panel.set_npc_symbol(icon)
