@tool
class_name CombatFeedbackDefinition
extends Resource
## Cosmetic event profile; does not own damage, geometry or attack timing.
@export_range(0, 16, 0.1) var shake_strength: float = 2.0
@export_range(0.01, 1, 0.01) var duration: float = 0.16
@export_range(1, 60, 1) var frequency: float = 24.0
@export_range(0.2, 5, 0.1) var falloff: float = 2.0
@export_range(0, 12, 0.1) var directional_kick: float = 0.0
@export_range(0, 0.04, 0.001) var zoom_punch: float = 0.0
@export_range(0, 0.08, 0.005) var hit_stop: float = 0.0
@export var flash_color: Color = Color(0.8, 0.85, 1.0, 0.0)
@export_range(-0.12, 0.12, 0.01) var brightness_pulse: float = 0.0
@export_range(0, 0.15, 0.01) var contrast_pulse: float = 0.0
@export_range(0, 0.003, 0.0001) var distortion: float = 0.0
@export_range(0, 0.002, 0.0001) var chromatic: float = 0.0
@export_range(0, 1, 0.05) var vibration_low: float = 0.0
@export_range(0, 1, 0.05) var vibration_high: float = 0.0
@export_range(0, 0.4, 0.01) var vibration_duration: float = 0.08
@export var sound_key: StringName
@export var rumble_key: StringName
@export_range(-30, 6, 1) var sound_volume_db: float = -6.0
@export_range(0.05, 2, 0.01) var minimum_interval: float = 0.15
@export_range(0, 1, 0.05) var recurring_scale: float = 0.08
@export_range(0.1, 2, 0.05) var recurring_interval: float = 0.5
@export_range(0, 1, 0.05) var hud_response: float = 0.0
