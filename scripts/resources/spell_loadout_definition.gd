@tool
class_name SpellLoadoutDefinition
extends Resource

@export var display_name: String = "Spell loadout"
@export_range(1, 12, 1) var base_slots: int = 3
@export_range(1, 12, 1) var maximum_slots: int = 10
@export var spells: Array[SpellDefinition] = []
