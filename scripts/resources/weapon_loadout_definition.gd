@tool
class_name WeaponLoadoutDefinition
extends Resource

@export var display_name: String = "Weapon loadout"
@export_range(1, 8, 1) var max_slots: int = 2
@export var weapons: Array[WeaponDefinition] = []
