@tool
class_name SpellDeliveryDefinition
extends Resource
## All lengths/radii are world units (128 = 1 metre); speeds are units/second.
## Already migrated to region scale. Never multiply these by caster/node scale.
@export var attack: AttackDefinition
@export var effects: Array[SpellEffectDefinition] = []
@export var vfx: VFXDefinition
## Explicit exception for spells deliberately affecting more than one storey.
@export var cross_elevations: bool = false
@export_range(0.01, 60, 0.01) var duration: float = 6.0
@export_range(0.01, 10, 0.01) var tick_interval: float = 0.3
@export_range(1, 8000, 1) var cast_range: float = 1600.0
@export_range(1, 8000, 1) var placement_distance: float = 720.0
@export_range(1, 16, 1) var max_instances: int = 1
@export_enum("Hostile", "Friendly", "Caster") var target_filter: String = "Hostile"

func kind() -> StringName:
	return &"abstract"

func is_channel() -> bool:
	return kind() in [&"beam", &"tether"] or (kind() == &"cone" and bool(get("held")))
