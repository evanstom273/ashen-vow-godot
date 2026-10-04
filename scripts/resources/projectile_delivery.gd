@tool
class_name ProjectileDelivery
extends SpellDeliveryDefinition
@export var speed: float = 1400.0
@export var radius: float = 28.0
@export var homing: bool = false
@export var turn_rate: float = 3.0
@export var pierce_count: int = 0

func kind() -> StringName:
	return &"projectile"
