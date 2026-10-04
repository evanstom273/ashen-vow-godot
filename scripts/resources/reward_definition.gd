@tool
class_name RewardDefinition
extends Resource
@export var display_name: String = "Weathered remains"
@export var weapons: Array[WeaponDefinition] = []
@export var spells: Array[SpellDefinition] = []
@export var utilities: Array[UtilityDefinition] = []
@export var materials: Dictionary[String, int] = {}
@export_range(0, 1000000, 1) var embers: int = 0
@export_range(0, 12, 1) var memory_bonus: int = 0
