@tool
class_name AttackDefinition
extends Resource
@export var display_name: String = "Light attack"
@export_group("Power")
@export var damage: DamageProfile
@export var scaling: AttributeScaling
@export_range(0, 10000, 0.1) var poise_damage: float = 30.0
@export_range(0, 10000, 0.1) var stamina_cost: float = 22.0
@export_range(0, 2000, 1) var knockback: float = 180.0
@export_group("Timing (seconds)")
@export_range(0.01, 10, 0.01) var windup: float = 0.10
@export_range(0.01, 10, 0.01) var active: float = 0.10
@export_range(0.01, 10, 0.01) var recovery: float = 0.18
@export_range(0, 1, 0.01) var movement_multiplier: float = 0.15
@export var uninterruptible_while_active: bool = false
@export_range(0, 5, 0.01) var charge_threshold: float = 0.45
@export var charged_action_name: StringName = &"charged"
@export_group("Hit geometry (world pixels)")
@export_range(1, 2000, 1) var reach: float = 42.0
@export_range(1, 500, 1) var hit_radius: float = 22.0
@export_range(1, 360, 1) var arc_degrees: float = 112.0
@export_range(0, 2000, 1) var lunge_speed: float = 0.0
@export_group("Feedback")
@export_range(0, 0.3, 0.005) var hit_stop: float = 0.04
@export_range(0, 20, 0.1) var camera_shake: float = 2.5
@export var slash_color: Color = Color(0.85, 0.92, 0.8, 0.65)
@export var swing_sound: StringName = &"swing"
@export var vfx: PackedScene

func duration() -> float: return windup + active + recovery
func active_end() -> float: return windup + active
func health_damage(stats: AttributeStats, defence: DefenceProfile = null) -> int:
    if damage == null: return 0
    var power: float = damage.mitigated(defence)
    if scaling != null: power *= scaling.multiplier(stats)
    return maxi(0, roundi(power))
