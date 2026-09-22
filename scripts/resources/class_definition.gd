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
@export var left_hand_loadout: WeaponLoadoutDefinition
@export var right_hand_loadout: WeaponLoadoutDefinition
@export var spell_loadout: SpellLoadoutDefinition
@export var utility_loadout: UtilityLoadoutDefinition
@export var currency_definition: CurrencyDefinition
@export_range(0, 1000000, 1) var starting_currency: int = 0
@export var lose_currency_on_death: bool = true
@export var death_drop: CurrencyDropDefinition
@export_group("Compatibility")
@export var starting_spells: Array[SpellDefinition] = []
