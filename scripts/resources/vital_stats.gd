@tool
class_name VitalStats
extends Resource
@export_group("Base pools at reference attributes")
@export_range(1, 100000, 1) var health: int = 650
@export_range(1, 10000, 1) var stamina: float = 120.0
@export_range(0, 1000, 0.5) var equip_load: float = 50.0
@export_group("Attribute growth")
@export_range(0, 99, 1) var reference_level: int = 10
@export_range(0, 1000, 0.1) var health_per_vigour: float = 30.0
@export_range(0, 1000, 0.1) var stamina_per_endurance: float = 3.0
@export_range(0, 100, 0.1) var load_per_endurance: float = 1.5
@export_group("Recovery")
@export_range(0, 1000, 0.1) var stamina_regeneration: float = 45.0
@export_range(0, 10, 0.01) var stamina_regeneration_delay: float = 0.65
@export_group("Poise and stagger")
@export_range(0.1, 10000, 0.1) var poise: float = 30.0
@export_range(0, 1000, 0.1) var poise_regeneration: float = 15.0
@export_range(0, 20, 0.01) var poise_regeneration_delay: float = 1.5
@export_range(0.01, 10, 0.01) var stagger_duration: float = 0.22
@export_range(0, 5000, 1) var knockback_deceleration: float = 700.0
@export_range(0, 5, 0.01) var damage_invulnerability: float = 0.65
@export var defence: DefenceProfile

func max_health(stats: AttributeStats) -> int:
    return maxi(1, roundi(health + (stats.vigour-reference_level)*health_per_vigour))
func max_stamina(stats: AttributeStats) -> float:
    return maxf(1, stamina + (stats.endurance-reference_level)*stamina_per_endurance)
func max_load(stats: AttributeStats) -> float:
    return maxf(0, equip_load + (stats.endurance-reference_level)*load_per_endurance)
