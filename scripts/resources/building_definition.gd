@tool
class_name BuildingDefinition
extends Resource
@export var id: StringName
@export var display_name: String = "Building"
@export_range(0.01, 1.0, 0.01) var fade_seconds: float = 0.22
@export_range(0, 1, 0.01) var outside_interior_opacity: float = 0.0
@export_range(0, 1, 0.01) var lower_floor_opacity: float = 0.12
@export_range(0, 1, 0.01) var upper_floor_opacity: float = 0.0
@export var reveal_while_airborne: bool = false
