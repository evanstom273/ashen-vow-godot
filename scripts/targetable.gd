class_name TargetableEntity
extends Node2D

var max_health: int = 1

var health: int = 1


func _ready() -> void:
	health = max_health
	add_to_group("targetable")


func is_targetable() -> bool:
	return health > 0 and visible


func get_target_point() -> Vector2:
	return global_position


func take_damage(amount: int, _source: Node) -> void:
	health = maxi(0, health - amount)
	if health == 0:
		visible = false


func set_lock_on(locked: bool) -> void:
	if has_node("LockRing"):
		$LockRing.visible = locked and is_targetable()
