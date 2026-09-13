class_name CollectableComponent
extends Area2D

@export var collectable_name: String = ""
@export var item_type: String = ""

signal collected(collectable_name: String, item_type: String)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player01:
		InteractionManager.register(self)

func _on_body_exited(body: Node2D) -> void:
	if body is Player01:
		InteractionManager.unregister(self)

func interact() -> void:
	QuestManager.collect_item(collectable_name)
	collected.emit(collectable_name, item_type)
	InteractionManager.unregister(self)
	queue_free()
