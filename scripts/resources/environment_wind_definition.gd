@tool
class_name EnvironmentWindDefinition
extends Resource
## Shared weather motion. Distances elsewhere remain in metres (128 units/m).
@export var direction := Vector2(1.0, 0.22)
@export_range(0.0, 2.0, 0.05) var strength: float = 0.65
@export_range(0.1, 2.0, 0.05) var time_scale: float = 0.7
@export_range(0.0, 1.0, 0.05) var reduced_effects_multiplier: float = 0.35
