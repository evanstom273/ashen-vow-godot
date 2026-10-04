@tool
class_name RegionBiomeDefinition
extends Resource
@export var id: StringName
@export var center_metres := Vector2.ZERO
@export var extent_metres := Vector2(80, 80)
@export var soil := Color("25392c")
@export var vegetation := Color("526448")
@export_range(0, 1, 0.01) var tree_density: float = 0.5
@export_enum("Broadleaf", "Conifer", "Dead") var tree_family: int = 0
@export var ground_cover: GroundCoverProfile

func influence(at: Vector2) -> float:
	var distance: float = ((at-center_metres)/extent_metres.max(Vector2.ONE)).length()
	return exp(-distance*distance*2.0)
