@tool
class_name ProgressionDefinition
extends Resource
@export_range(1, 99, 1) var attribute_cap: int = 99
@export var level_base_cost: int = 180
@export var level_linear_cost: float = 45.0
@export var level_quadratic_cost: float = 8.0
@export_range(1, 25, 1) var maximum_upgrade: int = 10
@export var upgrade_base_cost: int = 120
@export var upgrade_cost_growth: float = 1.55
@export_range(0, 1, 0.01) var damage_per_upgrade: float = 0.08
@export var material_id: StringName = &"ember_shard"
@export var material_name: String = "Ember Shard"
@export var materials_per_tier: int = 1

func level_cost(level: int) -> int:
	var earned: int = maxi(0, level - 1)
	return maxi(1, roundi(level_base_cost + level_linear_cost * earned + level_quadratic_cost * earned * earned))

func upgrade_cost(next_level: int) -> int:
	return maxi(1, roundi(upgrade_base_cost * pow(upgrade_cost_growth, maxi(0, next_level - 1))))

func material_cost(next_level: int) -> int:
	return maxi(1, materials_per_tier * (1 + floori(float(maxi(0, next_level - 1)) / 3.0)))
