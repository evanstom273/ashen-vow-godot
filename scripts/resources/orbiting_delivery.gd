@tool
class_name OrbitingDelivery
extends SpellDeliveryDefinition
@export var count: int = 4
@export var orbit_radius: float = 160.0
@export var orbit_speed: float = 2.0
@export var automatic: bool = false
@export var fire_interval: float = 0.15
@export var child: SpellDeliveryDefinition

func kind() -> StringName:
	return &"orbiting"
