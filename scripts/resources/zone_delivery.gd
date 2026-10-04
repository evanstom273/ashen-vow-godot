@tool
class_name ZoneDelivery
extends SpellDeliveryDefinition
@export var radius: float = 360.0
@export var initial_delay: float = 0.0

func kind() -> StringName:
	return &"zone"
