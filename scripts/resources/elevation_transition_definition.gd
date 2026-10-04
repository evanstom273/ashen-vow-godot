@tool
class_name ElevationTransitionDefinition
extends Resource
@export var from_level: int = 0
@export var to_level: int = 1
## Local metres. Endpoints must overlap supported floor/landing space.
@export var from_metres := Vector2(0, 2)
@export var to_metres := Vector2(0, -2)
@export_range(0.5, 20, 0.1) var width_metres: float = 2.0
@export var allow_airborne: bool = false
@export var draw_steps: bool = true
@export var step_color: Color = Color("626459")
