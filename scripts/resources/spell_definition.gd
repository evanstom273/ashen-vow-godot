@tool
class_name SpellDefinition
extends Resource
## Spell definition consumed by the player's minimal casting path.
@export var id: StringName = &"spell"
@export var display_name: String = "Spell"
@export_multiline var description: String = ""
@export_enum("Sorcery", "Incantation", "Arcane") var school: String = "Sorcery"
@export var icon: Texture2D
@export var requirements: AttributeStats
@export var cast: AttackDefinition
@export_range(0, 99, 1) var charges: int = 3
@export_range(1, 99, 1) var maximum_charges: int = 3
@export_range(0, 100000, 1) var health_restore: int = 0
@export_range(0, 100000, 0.1) var stamina_restore: float = 0.0
@export_range(1, 10, 1) var memory_slots: int = 1
@export_group("Delivery")
@export_enum("Projectile", "Area", "Self", "Target") var delivery: String = "Projectile"
@export var projectile_scene: PackedScene
@export var cast_effect: PackedScene
@export_range(0, 3000, 1) var projectile_speed: float = 350.0
@export_range(1, 64, 0.5) var projectile_radius: float = 7.0
@export_range(0.01, 60, 0.01) var lifetime: float = 3.0
@export_range(0, 1000, 1) var area_radius: float = 0.0

func starting_charges() -> int:
    return clampi(charges, 0, maximum_charges)
