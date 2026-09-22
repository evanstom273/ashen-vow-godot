@tool
class_name EnemyDefinition
extends Resource
@export var id: StringName = &"enemy"
@export var display_name: String = "Enemy"
@export_multiline var description: String = ""
@export var attributes: AttributeStats
@export var vitals: VitalStats
@export var weapon: WeaponDefinition
@export_group("AI")
@export_range(0, 2000, 1) var approach_speed: float = 100.0
@export_range(1, 5000, 1) var detection_radius: float = 260.0
@export_range(1, 5000, 1) var disengage_radius: float = 400.0
@export_range(1, 2000, 1) var attack_distance: float = 65.0
@export_range(0, 2000, 1) var stagger_recoil_speed: float = 100.0
@export_group("Feedback and reset")
@export var hit_sound: StringName = &"metal"
@export var windup_sound: StringName = &"tell"
@export_range(0, 120, 0.1) var auto_restore_delay: float = 0.0
@export_group("Currency")
@export var currency_drop: CurrencyDropDefinition
@export var drop_currency_on_death: bool = true
