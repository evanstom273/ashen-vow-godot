@tool
class_name TrapDelivery
extends SpellDeliveryDefinition
@export var arming_delay: float = 0.5
@export var trigger_radius: float = 160.0
@export var trigger_count: int = 1
@export var rearm_interval: float = 1.0
@export var child: SpellDeliveryDefinition

func kind() -> StringName:
	return &"trap"
