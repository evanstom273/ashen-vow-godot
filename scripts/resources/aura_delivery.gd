@tool
class_name AuraDelivery
extends SpellDeliveryDefinition
@export var radius: float = 340.0

func kind() -> StringName:
	return &"aura"
