@tool
class_name ChainDelivery
extends SpellDeliveryDefinition
@export var target_count: int = 4
@export var jump_radius: float = 720.0
@export var jump_delay: float = 0.15
@export var damage_falloff: float = 0.8
@export var require_line_of_sight: bool = true

func kind() -> StringName:
	return &"chain"
