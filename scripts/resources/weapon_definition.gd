@tool
class_name WeaponDefinition
extends Resource
@export var id: StringName = &"weapon"
@export var display_name: String = "Weapon"
@export_multiline var description: String = ""
@export_enum("Straight sword", "Greatsword", "Dagger", "Spear", "Axe", "Hammer", "Staff", "Seal", "Shield") var category: String = "Straight sword"
@export var icon: Texture2D
@export_range(0, 1000, 0.1) var weight: float = 3.0
@export var requirements: AttributeStats
@export var light_attack: AttackDefinition
@export_group("Presentation")
@export var blade_color: Color = Color("d9e6df")
@export_group("Future visual replacement (data only)")
@export var equipped_scene: PackedScene
@export_group("Future moves (data only)")
@export var heavy_attack: AttackDefinition
@export var skill: AttackDefinition
@export_range(0, 100, 0.1) var guard_boost: float = 0.0
@export_range(1, 5, 0.05) var critical_multiplier: float = 1.0
