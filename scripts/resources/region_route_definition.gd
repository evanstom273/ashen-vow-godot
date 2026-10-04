@tool
class_name RegionRouteDefinition
extends Resource
@export var id: StringName
@export var points_metres := PackedVector2Array()
@export_range(0.5, 12, 0.1) var width_metres: float = 3.0
@export var principal: bool = false

func length_metres() -> float:
	var total: float = 0
	for i in range(1, points_metres.size()): total += points_metres[i-1].distance_to(points_metres[i])
	return total
