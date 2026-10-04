@tool
class_name TetherDelivery
extends SpellDeliveryDefinition
@export var break_range: float = 1200.0
@export var line_of_sight_grace: float = 0.15
@export var movement_multiplier: float = 0.4
@export var completion_attack: AttackDefinition
@export var completion_effects: Array[SpellEffectDefinition] = []
## Percentage burns apply once on contact and run on the receiver independently.
func drain_definition() -> MaxHealthDrainDefinition:
	return attack.max_health_drain if attack != null else null

func _init() -> void:
	duration = 2.0

func kind() -> StringName:
	return &"tether"
