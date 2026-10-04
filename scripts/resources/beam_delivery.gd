@tool
class_name BeamDelivery
extends SpellDeliveryDefinition
@export var length: float = 1400.0
@export var width: float = 64.0
@export var turn_rate: float = 3.0
@export var movement_multiplier: float = 0.25
@export var piercing: bool = false

func _init() -> void:
	duration = 2.0

func kind() -> StringName:
	return &"beam"
