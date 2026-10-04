@tool
class_name ConeDelivery
extends SpellDeliveryDefinition
@export var radius: float = 560.0
@export var angle_degrees: float = 70.0
@export var held: bool = false
@export var turn_rate: float = 3.0
@export var movement_multiplier: float = 0.25

func kind() -> StringName:
	return &"cone"
