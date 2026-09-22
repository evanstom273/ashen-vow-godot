@tool
class_name WeaponDefinition
extends Resource
@export var id: StringName = &"weapon"
@export var display_name: String = "Weapon"
@export_multiline var description: String = ""
@export_enum("Straight sword", "Greatsword", "Dagger", "Spear", "Axe", "Hammer", "Staff", "Seal", "Wand", "Shield") var category: String = "Straight sword"
@export var icon: Texture2D
@export_range(0, 1000, 0.1) var weight: float = 3.0
@export var requirements: AttributeStats
@export var usable_in_left_hand: bool = true
@export var usable_in_right_hand: bool = true
@export var two_handed: bool = false
@export_group("Spell catalyst")
@export var is_spell_catalyst: bool = false
@export var catalyst_schools: Array[String] = []
@export var light_attack: AttackDefinition
@export var charged_attack: AttackDefinition
@export_group("Presentation")
@export var blade_color: Color = Color("d9e6df")
## Node2D scene: grip at origin, blade points along local +X.
@export var equipped_scene: PackedScene
@export_group("Future moves (data only)")
@export var heavy_attack: AttackDefinition
@export var skill: AttackDefinition
