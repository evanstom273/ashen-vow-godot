@tool
class_name ClassDefinition
extends Resource
@export var id: StringName = &"wanderer"
@export var display_name: String = "Ashen Wanderer"
@export_multiline var description: String = ""
@export_range(1, 999, 1) var starting_level: int = 1
@export var attributes: AttributeStats
@export var vitals: VitalStats
@export var movement: MovementDefinition
@export var starting_weapon: WeaponDefinition
@export_group("Future spell loadout (data only)")
@export var starting_spells: Array[SpellDefinition] = []
