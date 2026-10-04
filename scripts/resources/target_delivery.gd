@tool
class_name TargetDelivery
extends SpellDeliveryDefinition
@export var require_line_of_sight: bool = true

func kind() -> StringName:
	return &"target"
