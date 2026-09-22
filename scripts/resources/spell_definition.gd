@tool
class_name SpellDefinition
extends Resource
## Spell authoring foundation. No casting input/controller is added by this resource.
@export var id: StringName = &"spell"
@export var display_name: String = "Spell"
@export_multiline var description: String = ""
@export_enum("Sorcery", "Incantation", "Arcane") var school: String = "Sorcery"
@export var icon: Texture2D
@export var requirements: AttributeStats
@export var cast: AttackDefinition
@export_range(1, 10, 1) var memory_slots: int = 1
@export_group("Delivery (data only)")
@export_enum("Projectile", "Area", "Self", "Target") var delivery: String = "Projectile"
@export var projectile_scene: PackedScene
@export var cast_effect: PackedScene
@export_range(0, 3000, 1) var projectile_speed: float = 350.0
@export_range(0.01, 60, 0.01) var lifetime: float = 3.0
@export_range(0, 1000, 1) var area_radius: float = 0.0
