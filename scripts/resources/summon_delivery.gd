@tool
class_name SummonDelivery
extends SpellDeliveryDefinition
@export var count: int = 1
@export var summon: SummonDefinition

func kind() -> StringName:
	return &"summon"
