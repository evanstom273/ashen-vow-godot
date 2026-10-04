@tool
class_name EnemyMove
extends Resource
@export var id: StringName
@export var attack: AttackDefinition
@export var delivery: SpellDeliveryDefinition
@export var minimum_metres: float = 0.0
@export var maximum_metres: float = 3.0
@export var cooldown: float = 1.0
@export_range(0, 1, 0.05) var track_windup_fraction: float = 0.6
@export var priority: int = 0
