@tool
class_name BarrageDelivery
extends SpellDeliveryDefinition
@export var count: int = 6
@export var scatter_radius: float = 400.0
@export var impact_radius: float = 120.0
@export var impact_interval: float = 0.25
@export var telegraph_duration: float = 0.6

func kind() -> StringName:
	return &"barrage"
