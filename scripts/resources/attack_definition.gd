@tool
class_name AttackDefinition
extends Resource
@export var display_name: String = "Light attack"
@export_group("Power")
@export var damage: DamageProfile
@export var scaling: AttributeScaling
## Optional on-hit percentage burn. May be shared by spells and weapon attacks.
@export var max_health_drain: MaxHealthDrainDefinition
## Deliberate cross-floor payloads only; ordinary attacks remain on their origin floor.
@export var cross_elevations: bool = false
@export_range(0, 10000, 0.1) var poise_damage: float = 30.0
@export_range(0, 10000, 0.1) var stamina_cost: float = 22.0
## Authored recoil speed; receivers convert once using their actor/world scale.
@export_range(0, 2000, 1) var knockback: float = 180.0
@export_group("Timing (seconds)")
@export_range(0.01, 10, 0.01) var windup: float = 0.10
@export_range(0.01, 10, 0.01) var active: float = 0.10
@export_range(0.01, 10, 0.01) var recovery: float = 0.18
@export_range(0, 1, 0.01) var movement_multiplier: float = 0.15
@export var uninterruptible_while_active: bool = false
@export_range(0, 5, 0.01) var charge_threshold: float = 0.45
@export var charged_action_name: StringName = &"charged"
@export_group("Hit geometry (authored units)")
## Melee reach at unit actor scale. The player converts reach and radius to world
## units together; do not pre-scale weapon resources for a particular scene.
## Spell delivery geometry is configured separately in world units.
@export_range(1, 2000, 1) var reach: float = 42.0
## Melee query radius at unit actor scale, capped to reach before conversion.
@export_range(1, 500, 1) var hit_radius: float = 22.0
@export_range(1, 360, 1) var arc_degrees: float = 112.0
@export_range(0, 2000, 1) var lunge_speed: float = 0.0
@export_group("Feedback")
@export_range(0, 0.3, 0.005) var hit_stop: float = 0.04
@export_range(0, 20, 0.1) var camera_shake: float = 2.5
@export var slash_color: Color = Color(0.85, 0.92, 0.8, 0.65)
@export var swing_sound: StringName = &"swing"
@export var vfx: PackedScene
@export var melee_vfx: VFXDefinition
@export var feedback: CombatFeedbackDefinition
## Per-hit runtime bonus: deliberately excluded from attribute scaling.
var unscaled_bonus_damage: DamageProfile
## Runtime-only exact damage for percentage drains; receivers still gate invulnerability.
var resolved_health_damage: int = -1
## A burn tick must not grant a fresh hit-protection window against later ticks.
var periodic_damage: bool = false
var recurring_feedback: bool = false
var has_hit_elevation: bool = false
var hit_elevation: int = 0

func duration() -> float: return windup + active + recovery
func active_end() -> float: return windup + active
func health_damage(stats: AttributeStats, defence: DefenceProfile = null) -> int:
    if resolved_health_damage >= 0: return resolved_health_damage
    var power: float = damage.mitigated(defence) if damage != null else 0.0
    if scaling != null: power *= scaling.multiplier(stats)
    if unscaled_bonus_damage != null: power += unscaled_bonus_damage.mitigated(defence)
    return maxi(0, roundi(power))
