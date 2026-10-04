@tool
class_name StatusDefinition
extends Resource
## Buildup is separate from direct timed effects and Blackflame's fixed totals.
@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var color: Color = Color("b4c0a0")
@export_range(1, 10000, 1) var threshold: float = 100.0
@export_range(0, 1000, 1) var decay_per_second: float = 12.0
@export_range(0, 30, 0.1) var decay_delay: float = 2.0
@export_range(0, 60, 0.1) var retrigger_delay: float = 3.0
@export var tags: Array[StringName] = []
@export var triggered_effect: SpellEffectDefinition
@export var triggered_attack: AttackDefinition
@export var vfx: VFXDefinition
