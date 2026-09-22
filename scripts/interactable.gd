class_name InteractableEntity
extends Node2D


func _ready() -> void:
	add_to_group("interactable")


func can_interact(_player: Node) -> bool:
	return is_inside_tree() and visible


func get_interaction_prompt() -> String:
	return "Interact"


func interact(_player: Node) -> void:
	pass


func get_target_point() -> Vector2:
	return global_position


func set_lock_on(locked: bool) -> void:
	if has_node("LockRing"):
		$LockRing.visible = locked
