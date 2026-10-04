@tool
class_name WaveDelivery
extends SpellDeliveryDefinition
@export var speed: float = 920.0
@export var distance: float = 1400.0
@export var width: float = 360.0
@export var thickness: float = 48.0
@export var curvature: float = 0.0

func kind() -> StringName:
	return &"wave"
