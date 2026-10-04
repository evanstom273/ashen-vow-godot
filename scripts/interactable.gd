class_name InteractableEntity
extends Node2D


func _ready() -> void:
	add_to_group("interactable")
	Elevation.register_tree(self)
	Elevation.register_visual(self)


func can_interact(player: Node) -> bool:
	return is_inside_tree() and visible and is_instance_valid(player) and player.has_method("can_world_interact") and player.call("can_world_interact") and Elevation.compatible(self, player)


func get_interaction_prompt() -> String:
	return "Interact"


func interact(_player: Node) -> void:
	pass


func get_target_point() -> Vector2:
	return global_position


func set_lock_on(locked: bool) -> void:
	if has_node("LockRing"):
		$LockRing.visible = locked
