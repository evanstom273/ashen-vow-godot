@tool
class_name BuildingFloorDefinition
extends Resource
@export var elevation: ElevationDefinition
## Local floor coordinates, in metres (128 world units/metre).
## Multiple polygons support irregular rooms; overlapping regions form a union.
@export var regions_metres: Array[PackedVector2Array] = []
## Open platforms/bridges have no exterior shell to hide their contents.
@export var enclosed: bool = true
## Bounds support movement and landing on nonzero elevations.
@export var supplies_support: bool = true
