@tool
class_name StatusApplication
extends Resource
@export var status: StatusDefinition
@export_range(0, 10000, 1) var buildup: float = 25.0
