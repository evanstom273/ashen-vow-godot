@tool
class_name SpellDefinition
extends Resource
enum UsePolicy { FINITE, CATALYST_BASIC }
## Basic entries are supplied by selected catalysts; never occupy prepared memory.
@export var use_policy: UsePolicy = UsePolicy.FINITE
## Spell definition consumed by the player's minimal casting path.
@export var id: StringName = &"spell"
@export var display_name: String = "Spell"
@export_multiline var description: String = ""
@export_enum("Sorcery", "Incantation", "Arcane") var school: String = "Sorcery"
@export var icon: Texture2D
@export var requirements: AttributeStats
@export var cast: AttackDefinition
## Selected delivery owns gameplay settings and its VFX profile.
@export var delivery_definition: SpellDeliveryDefinition
@export_range(0, 99, 1) var charges: int = 3
@export_range(1, 99, 1) var maximum_charges: int = 3
@export_range(0, 100000, 1) var health_restore: int = 0
@export_range(0, 100000, 0.1) var stamina_restore: float = 0.0
@export_range(1, 10, 1) var memory_slots: int = 1
@export_enum("Projectile", "Area", "Self", "Target", "Beam", "Weapon Imbue", "Cone", "Wave / Arc", "Ground Zone", "Chain", "Orbiting", "Trap / Mine", "Barrage / Rain", "Summon", "Aura", "Dash / Movement", "Tether")
var delivery: String = "Projectile":
	set(value):
		var kinds: Dictionary = {
			"Projectile": "projectile",
			"Area": "area",
			"Self": "self",
			"Target": "target",
			"Beam": "beam",
			"Weapon Imbue": "imbue",
			"Cone": "cone",
			"Wave / Arc": "wave",
			"Ground Zone": "zone",
			"Chain": "chain",
			"Orbiting": "orbiting",
			"Trap / Mine": "trap",
			"Barrage / Rain": "barrage",
			"Summon": "summon",
			"Aura": "aura",
			"Dash / Movement": "dash",
			"Tether": "tether"
		}

		if not kinds.has(value):
			return

		var selected_kind: StringName = StringName(kinds[value])

		if delivery_definition == null or delivery_definition.kind() != selected_kind:
			var script_path: String = (
				"res://scripts/resources/"
				+ String(selected_kind)
				+ "_delivery.gd"
			)
			var definition_script: Script = load(script_path) as Script
			if definition_script == null or not definition_script.can_instantiate():
				push_error("Cannot create delivery definition: " + script_path)
				return

			var new_definition: SpellDeliveryDefinition = (
				definition_script.new() as SpellDeliveryDefinition
			)
			if new_definition == null:
				push_error("Invalid delivery definition: " + script_path)
				return

			delivery_definition = new_definition

		delivery = value
		emit_changed()
func starting_charges() -> int:
	if is_basic(): return -1
	return clampi(charges, 0, maximum_charges)

func is_basic() -> bool: return use_policy == UsePolicy.CATALYST_BASIC
