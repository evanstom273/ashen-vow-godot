@tool
class_name SpellEffectDefinition
extends Resource
@export var id: StringName = &"effect"
@export var display_name: String = ""
@export var icon: Texture2D
@export var tags: Array[StringName] = []
@export var negative: bool = false
@export var cleanse_tags: Array[StringName] = []
@export var health_restore: int = 0
@export var stamina_restore: float = 0.0
@export_range(0, 60, 0.1) var duration: float = 0.0
@export_range(0.01, 10, 0.01) var interval: float = 0.3
@export var periodic_attack: AttackDefinition
@export var periodic_heal: int = 0
@export_range(0.1, 2, 0.05) var movement_multiplier: float = 1.0
@export var defence_bonus: DefenceProfile

func validation_error() -> String:
	if id.is_empty(): return "Effect requires an ID"
	if not is_finite(duration) or duration < 0: return "Invalid effect duration"
	if not is_finite(interval) or interval < 0.01: return "Effect interval must be at least 0.01 seconds"
	if health_restore < 0 or periodic_heal < 0 or not is_finite(stamina_restore) or stamina_restore < 0: return "Restoration cannot be negative"
	if not is_finite(movement_multiplier) or movement_multiplier < 0.1 or movement_multiplier > 2.0: return "Effect movement multiplier must be 0.1–2.0"
	return ""
