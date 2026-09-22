@tool
class_name BossPhase
extends Resource
## Foundation only: a future boss controller selects the lowest crossed threshold.
@export var display_name: String = "Second phase"
@export_range(0, 1, 0.01) var health_threshold: float = 0.5
@export_range(0.1, 5, 0.05) var movement_multiplier: float = 1.0
@export var attacks: Array[AttackDefinition] = []
@export var transition_animation: StringName
@export var transition_effect: PackedScene
