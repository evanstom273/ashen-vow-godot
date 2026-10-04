@tool
class_name ElevationDefinition
extends Resource
## Logical storey; negative values are valid. This is not a physics layer number.
@export var level: int = 0
## Explicitly shared structures (e.g. a pillar) can occupy several storeys.
@export var additional_levels: Array[int] = []

func occupies(value: int) -> bool:
	return value == level or additional_levels.has(value)
