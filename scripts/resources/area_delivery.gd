@tool
class_name AreaDelivery
extends SpellDeliveryDefinition
@export var radius: float = 320.0
@export var at_caster: bool = true
@export var wall_occlusion: bool = true

func kind() -> StringName:
	return &"area"
