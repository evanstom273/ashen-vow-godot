@tool
class_name LandmarkApproachDefinition
extends Resource
## Presentation-only local metre coordinates. Follow real, already walkable openings.
@export var points_metres := PackedVector2Array([Vector2(0, 10), Vector2(0, 0)])
@export_range(0.5, 12.0, 0.1) var width_metres: float = 2.6
@export var surface := Color("62614e")
@export var edging := Color("777b66")
@export var worn_centre := Color("77735a")
@export_enum("Broken stone", "Timber remnants", "Gravel", "Roots") var edge_style: int = 0
@export_range(0.5, 5.0, 0.1) var edge_spacing_metres: float = 1.8
@export var frame_positions_metres := PackedVector2Array()
@export_enum("Low stones", "Memorial posts", "Pennants", "Bridge posts") var frame_style: int = 0
@export var cloth_color := Color("69504a")
@export var accent_color := Color("aaa180")
@export var threshold: bool = true
@export var seed_value: int = 937
