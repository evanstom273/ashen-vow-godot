@tool
class_name BuildingRoofDefinition
extends Resource
## Procedural roof panels and ridge in local metres; art never creates collision.
@export var outline_metres := PackedVector2Array()
@export var panels_metres: Array[PackedVector2Array] = []
@export var panel_colors: Array[Color] = []
@export var ridge_metres := PackedVector2Array()
@export var slate_color: Color = Color("283235")
@export var trim_color: Color = Color("757967")
@export_range(0.2, 2, 0.05) var course_spacing_metres: float = 0.55
@export var variation: int = 17
