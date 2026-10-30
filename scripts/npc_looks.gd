class_name NpcLooks
extends RefCounted

## The real NPC designs (idle animations in resources/npcs/).
## Drawn in the player's style and size. FEET: sprite offset so the feet stand on the node position.

const FRAMES := {
	"merchant": preload("res://resources/npcs/merchant_frames.tres"),
	"farmer": preload("res://resources/npcs/farmer_frames.tres"),
	"teacher": preload("res://resources/npcs/teacher_frames.tres"),
	"grandma": preload("res://resources/npcs/grandma_frames.tres"),
	"builder": preload("res://resources/npcs/builder_frames.tres"),
	"painter": preload("res://resources/npcs/painter_frames.tres"),
}
const FEET := {
	"merchant": -15.0,
	"farmer": -15.0,
	"teacher": -15.0,
	"grandma": -15.0,
	"builder": -15.0,
	"painter": -15.0,
}
const SCALE := {
	"merchant": 1.0,
	"farmer": 1.0,
	"teacher": 1.0,
	"grandma": 1.0,
	"builder": 1.0,
	"painter": 1.0,
}

## Puts this NPC's look on an AnimatedSprite2D whose node stands where the feet are.
static func apply(sprite: AnimatedSprite2D, npc: String) -> void:
	if not FRAMES.has(npc):
		return
	sprite.sprite_frames = FRAMES[npc]
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE * SCALE[npc]
	sprite.position = Vector2(0, 1)
	sprite.offset = Vector2(0, FEET[npc])
	sprite.play("idle_front")
	sprite.frame = randi() % sprite.sprite_frames.get_frame_count("idle_front")
