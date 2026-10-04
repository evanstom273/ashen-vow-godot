@tool
class_name SpellEffectDefinition
extends Resource
@export var id: StringName = &"effect"
@export var tags: Array[StringName] = []
@export var negative: bool = false
@export var cleanse_tags: Array[StringName] = []
@export var health_restore: int = 0
@export var stamina_restore: float = 0.0
@export_range(0, 60, 0.1) var duration: float = 0.0
@export_range(0.01, 10, 0.01) var interval: float = 0.3
@export var periodic_attack: AttackDefinition
@export var periodic_heal: int = 0
@export_range(0.1, 2, 0.05) var movement_multiplier: float = 1.0
@export var defence_bonus: DefenceProfile
