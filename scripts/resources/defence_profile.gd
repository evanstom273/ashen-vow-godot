@tool
class_name DefenceProfile
extends Resource
## Percentage damage negation. Negative values represent vulnerability.
@export_range(-100, 100, 1) var physical: float = 0.0
@export_range(-100, 100, 1) var magic: float = 0.0
@export_range(-100, 100, 1) var fire: float = 0.0
@export_range(-100, 100, 1) var lightning: float = 0.0
@export_range(-100, 100, 1) var holy: float = 0.0
@export_group("Future status-system thresholds (data only)")
@export_range(0, 10000, 1) var bleed_resistance: float = 100.0
@export_range(0, 10000, 1) var poison_resistance: float = 100.0
@export_range(0, 10000, 1) var frost_resistance: float = 100.0
@export_range(0, 10000, 1) var madness_resistance: float = 100.0
