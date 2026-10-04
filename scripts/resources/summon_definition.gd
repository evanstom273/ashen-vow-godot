@tool
class_name SummonDefinition
extends Resource
## Movement and targeting values use world units, not visual/node scale.
@export var scene: PackedScene
@export var mobile: bool = true
@export var health: int = 200
@export var defence: DefenceProfile
@export var speed: float = 400.0
@export var follow_distance: float = 280.0
@export var acquisition_range: float = 1200.0
@export var attack_range: float = 800.0
@export var attack_interval: float = 1.0
## Bounded target selection; path queries never run once per candidate per frame.
@export_range(0.1, 2.0, 0.05) var acquisition_interval: float = 0.4
@export var delivery: SpellDeliveryDefinition
